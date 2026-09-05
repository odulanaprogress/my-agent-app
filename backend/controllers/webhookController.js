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
        const userId = txData.userId || txData.tenantId;
        if (userId) {
          const walletRef = db.collection('wallets').doc(userId);
          await db.runTransaction(async (t) => {
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

          await sendPushNotification({
            userId: userId,
            title: '💰 Wallet Deposit Confirmed',
            message: `₦${amountPaid.toLocaleString()} has been credited to your Agent wallet via Flutterwave.`,
            data: { type: 'wallet', transactionId: txRef },
          });
        }
        return res.status(200).json({ success: true, message: 'Wallet deposit processed' });
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

    // ── Handle successful withdrawal transfer ─────────────────────────────────
    if (payload.event === 'transfer.completed' && payload.data) {
      const transferRef = payload.data.reference;
      const transferStatus = payload.data.status;
      const transferAmount = payload.data.amount;

      console.log(`💸 Transfer webhook: ref=${transferRef} status=${transferStatus} amount=${transferAmount}`);

      // Extract uid from reference format: WITHDRAW-{uid8}-{timestamp}
      if (transferRef && transferRef.startsWith('WITHDRAW-')) {
        const parts = transferRef.split('-');
        // parts[1] is the uid prefix
        console.log(`✅ Withdrawal of ₦${transferAmount} completed for uid_prefix=${parts[1]}, status=${transferStatus}`);

        // If transfer FAILED, we need to refund the balance
        if (transferStatus === 'FAILED') {
          console.error(`❌ Transfer FAILED for ref=${transferRef}. Manual review needed.`);
          // TODO: Implement automatic refund by looking up the withdrawal record
          // For now, log for manual intervention
        }
      }
    }

    return res.status(200).json({ success: true, message: 'Webhook Event Processed' });
  } catch (error) {
    next(error);
  }
};

module.exports = { handleWebhook };
