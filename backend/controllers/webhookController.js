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
        tenantPin: tenantPin,
        landlordPin: landlordPin,
        tenantPinVerified: false,
        landlordPinVerified: false,
        possessionConfirmed: false,
        landlordPaidOut: false,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (snap.exists) {
        await txDocRef.update(updateData);
      } else {
        await txDocRef.set({
          id: txRef,
          ...updateData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const txData = snap.exists ? snap.data() : {};
      const tenantId = txData.tenantId;
      const landlordId = txData.landlordId;

      // 4. Send Instant Push Notifications to Tenant & Landlord
      if (tenantId) {
        await sendPushNotification({
          userId: tenantId,
          title: '🛡️ Rent Payment Placed in Escrow',
          message: `Your rent payment of ₦${amountPaid} is secure in Escrow. Your Key Receipt PIN is ${tenantPin}.`,
          data: { type: 'escrow', transactionId: txRef },
        });
      }

      if (landlordId) {
        await sendPushNotification({
          userId: landlordId,
          title: '🎉 Rent Received in Escrow Vault',
          message: `Rent of ₦${amountPaid} has been deposited into Escrow. Your Handover PIN is ${landlordPin}.`,
          data: { type: 'escrow', transactionId: txRef },
        });
      }

      console.log(`✅ Escrow Established for ${txRef}! Tenant PIN: ${tenantPin}, Landlord PIN: ${landlordPin}`);
    }

    return res.status(200).json({ success: true, message: 'Webhook Event Processed' });
  } catch (error) {
    next(error);
  }
};

module.exports = { handleWebhook };
