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

      // 2. Financial Breakdown (5% Platform Fee, 95% Landlord Payout)
      const commissionPercent = 5;
      const commissionAmount = Math.round(amountPaid * (commissionPercent / 100));
      const netPayoutAmount = amountPaid - commissionAmount;

      // 3. Cryptographically Random 6-Digit Handshake PINs
      const tenantPin = generateSixDigitPin();
      const landlordPin = generateSixDigitPin();

      const txDocRef = db.collection('transactions').doc(txRef);
      const snap = await txDocRef.get();

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
      const txData = snap.exists ? snap.data() : {};
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


      // Push notifications — NO PINs in the message body
      if (tenantId) {
        await sendPushNotification({
          userId: tenantId,
          title: '🛡️ Rent Payment Placed in Escrow',
          message: `Your rent payment of ₦${amountPaid} is secured. Open the app to view your PIN.`,
          data: { type: 'escrow', transactionId: txRef },
        });
      }

      if (landlordId) {
        await sendPushNotification({
          userId: landlordId,
          title: '🎉 Rent Received in Escrow Vault',
          message: `Rent of ₦${amountPaid} is in Escrow. Open the app to view your PIN.`,
          data: { type: 'escrow', transactionId: txRef },
        });
      }    }

    return res.status(200).json({ success: true, message: 'Webhook Event Processed' });
  } catch (error) {
    next(error);
  }
};

module.exports = { handleWebhook };
