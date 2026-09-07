const crypto = require('crypto');
const { db, admin } = require('../config/firebase');
const flutterwaveService = require('../services/flutterwaveService');
const { sendPushNotification } = require('../services/onesignalService');

function generateSixDigitPin() {
  return Math.floor(100000 + crypto.randomInt(900000)).toString();
}

/**
 * Handle Flutterwave Webhook Events (`charge.completed`)
 */
const handleWebhook = async (req, res, next) => {
  try {
    const payload = req.body;
    console.log('🔔 Webhook Event Received:', payload.event, payload.data ? payload.data.id : '');

    if (payload.event === 'charge.completed' && payload.data && payload.data.status === 'successful') {
      const flwTxId = payload.data.id;
      const txRef = payload.data.tx_ref;
      const amountPaid = payload.data.amount;
      const currency = payload.data.currency || 'NGN';

      // 1. Direct Server API Verification
      const verifiedData = await flutterwaveService.verifyTransaction(flwTxId);
      if (!verifiedData || verifiedData.status !== 'successful' || verifiedData.amount < amountPaid) {
        console.error('❌ Webhook verification mismatch:', verifiedData);
        return res.status(400).json({ success: false, error: 'Payment verification failed.' });
      }

      const txDocRef = db.collection('transactions').doc(txRef);
      const snap = await txDocRef.get();
      const txData = snap.exists ? snap.data() : {};

      // 1.5 Handle Wallet Deposit
      if (txRef.includes('DEP') || txData.type === 'deposit') {
        if (txData.status === 'completed') {
          console.log(`ℹ️ Webhook: Deposit ${txRef} already marked completed. Skipping.`);
          return res.status(200).json({ success: true, message: 'Wallet deposit already processed' });
        }

        const userId = txData.userId || txData.tenantId;
        if (userId) {
          const walletRef = db.collection('wallets').doc(userId);
          let alreadyHandled = false;

          await db.runTransaction(async (t) => {
            const freshTx = await t.get(txDocRef);
            if (freshTx.exists && freshTx.data().status === 'completed') {
              console.log(`⚠️ Webhook: Deposit ${txRef} was completed concurrently. Skipping credit.`);
              alreadyHandled = true;
              return;
            }

            const wDoc = await t.get(walletRef);
            const currentBal = wDoc.exists ? (wDoc.data().availableBalance || wDoc.data().balance || 0) : 0;
            t.set(walletRef, {
              uid: userId,
              availableBalance: currentBal + amountPaid,
              balance: currentBal + amountPaid,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            t.set(txDocRef, {
              id: txRef,
              status: 'completed',
              type: 'deposit',
              userId: userId,
              flutterwaveTxId: flwTxId,
              amount: amountPaid,
              currency: currency,
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
          });

          if (alreadyHandled) {
            return res.status(200).json({ success: true, message: 'Wallet deposit already processed' });
          }

          await sendPushNotification({
            userId: userId,
            title: '💰 Wallet Deposit Confirmed',
            message: `₦${amountPaid.toLocaleString()} has been credited to your Agent wallet via Flutterwave.`,
            data: { type: 'wallet', transactionId: txRef },
          });
        }
        return res.status(200).json({ success: true, message: 'Wallet deposit processed' });
      }

      // 1.8 Guard against duplicate escrow processing
      if (txData.status === 'held' || txData.status === 'completed' || txData.status === 'released') {
        console.log(`ℹ️ Webhook: Transaction ${txRef} already ${txData.status}. Skipping duplicate escrow setup.`);
        return res.status(200).json({ success: true, message: `Transaction already ${txData.status}` });
      }

      // 2. Financial Breakdown (5% Platform Fee, 95% Landlord Payout)
      const commissionPercent = 5;
      const commissionAmount = Math.round(amountPaid * (commissionPercent / 100));
      const netPayoutAmount = amountPaid - commissionAmount;

      // 3. Cryptographically Random 6-Digit Handshake PINs
      const tenantPin = generateSixDigitPin();
      const landlordPin = generateSixDigitPin();

      const updateData = {
        flutterwaveTxId: flwTxId,
        amount: amountPaid,
        currency: currency,
        status: 'held',
        commissionPercent: commissionPercent,
        commissionAmount: commissionAmount,
        netPayoutAmount: netPayoutAmount,
        // NOTE: PINs are NOT stored on the main document.
        // They are written to private subcollections below.
        tenantPinVerified: false,
        landlordPinVerified: false,
        possessionConfirmed: false,
        landlordPaidOut: false,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const batch = db.batch();

      if (snap.exists) {
        batch.update(txDocRef, updateData);
      } else {
        batch.set(txDocRef, {
          id: txRef,
          ...updateData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Store PINs in private subcollections — Firestore rules allow only the
      // owner to read their own PIN. No PIN ever appears on the main document.
      const tenantId = txData.tenantId;
      const landlordId = txData.landlordId;

      if (tenantId) {
        batch.set(txDocRef.collection('pins').doc(tenantId), { pin: tenantPin, role: 'tenant' });
      }
      if (landlordId) {
        batch.set(txDocRef.collection('pins').doc(landlordId), { pin: landlordPin, role: 'landlord' });
      }

      await batch.commit();

      // Safe log — correlation IDs only, NO secret values
      console.log(`✅ Escrow established txRef=${txRef} flwTxId=${flwTxId}`);

      // Fetch tenant email from Firestore for receipt reference
      const tenantEmail = payload.data?.customer?.email || null;
      const tenantName = payload.data?.customer?.name || 'Tenant';

      // Push notifications — NO PINs in the message body
      if (tenantId) {
        await sendPushNotification({
          userId: tenantId,
          title: '✅ Payment Confirmed — Escrow Active',
          message: `Your rent payment of ₦${amountPaid.toLocaleString()} has been received and secured in Escrow. Check your email (${tenantEmail || 'inbox'}) for your Flutterwave receipt.`,
          data: { type: 'escrow', transactionId: txRef },
        });
      }

      if (landlordId) {
        await sendPushNotification({
          userId: landlordId,
          title: '🎉 Rent Received in Escrow Vault',
          message: `₦${amountPaid.toLocaleString()} has been secured in Escrow. You will be paid out after key handover is confirmed.`,
          data: { type: 'escrow', transactionId: txRef },
        });
      }
    }

    // ── Handle withdrawal transfer completion / failure webhook ───────────────
    if (payload.event === 'transfer.completed' && payload.data) {
      const transferRef = payload.data.reference;
      const transferStatus = (payload.data.status || '').toUpperCase();
      const transferAmount = Number(payload.data.amount) || 0;
      const failureReason = payload.data.complete_message || payload.data.narration || 'Transfer failed on payment gateway';

      console.log(`💸 Transfer webhook: ref=${transferRef} status=${transferStatus} amount=${transferAmount}`);

      if (transferRef && transferRef.startsWith('WITHDRAW-')) {
        const txDocRef = db.collection('transactions').doc(transferRef);
        const txSnap = await txDocRef.get();
        const txData = txSnap.exists ? txSnap.data() : null;

        // Determine userId: from Firestore transaction doc, or fallback to parsing reference WITHDRAW-{uid}-{timestamp}
        let userId = txData?.userId || txData?.tenantId;
        if (!userId) {
          const parts = transferRef.split('-');
          if (parts.length >= 3) {
            userId = parts.slice(1, -1).join('-');
          }
        }

        if (transferStatus === 'SUCCESSFUL') {
          console.log(`✅ Withdrawal of ₦${transferAmount} confirmed successful for ref=${transferRef}`);
          if (txSnap.exists) {
            await txDocRef.update({
              status: 'completed',
              payoutStatus: 'SUCCESSFUL',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          if (userId) {
            await sendPushNotification({
              userId: userId,
              title: '💸 Withdrawal Successful',
              message: `₦${transferAmount.toLocaleString()} has been deposited to your bank account.`,
              data: { type: 'wallet', transactionId: transferRef },
            });
          }
        } else if (transferStatus === 'FAILED') {
          console.error(`❌ Transfer FAILED for ref=${transferRef}, reason=${failureReason}. Executing automatic refund...`);

          // Idempotency: only refund if not already marked failed or refunded
          if (txData && (txData.status === 'failed' || txData.status === 'refunded')) {
            console.log(`ℹ️ Transfer ${transferRef} already refunded. Skipping duplicate refund.`);
            return res.status(200).json({ success: true, message: 'Transfer already refunded' });
          }

          if (userId && transferAmount > 0) {
            const walletRef = db.collection('wallets').doc(userId);
            await db.runTransaction(async (t) => {
              const freshTx = await t.get(txDocRef);
              if (freshTx.exists && (freshTx.data().status === 'failed' || freshTx.data().status === 'refunded')) {
                return; // already handled concurrently
              }

              const wDoc = await t.get(walletRef);
              const currentBal = wDoc.exists ? (wDoc.data().availableBalance ?? wDoc.data().balance ?? 0) : 0;
              const restoredBal = currentBal + transferAmount;

              t.set(walletRef, {
                uid: userId,
                availableBalance: restoredBal,
                balance: restoredBal,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });

              t.set(txDocRef, {
                status: 'failed',
                payoutStatus: 'FAILED',
                failureReason: failureReason,
                refundedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
            });

            await sendPushNotification({
              userId: userId,
              title: '⚠️ Withdrawal Unsuccessful — Funds Returned',
              message: `Your withdrawal of ₦${transferAmount.toLocaleString()} could not be completed and has been refunded to your wallet. Reason: ${failureReason}.`,
              data: { type: 'wallet', transactionId: transferRef },
            });

            console.log(`🔄 Automatically refunded ₦${transferAmount} back to user=${userId}`);
          }
        }
      }
    }

    return res.status(200).json({ success: true, message: 'Webhook Event Processed' });
  } catch (error) {
    next(error);
  }
};

module.exports = { handleWebhook };
