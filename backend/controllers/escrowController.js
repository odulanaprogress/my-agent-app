const { db, admin } = require('../config/firebase');
const flutterwaveService = require('../services/flutterwaveService');
const { sendPushNotification } = require('../services/onesignalService');

/**
 * Verify 6-digit Escrow Handshake PIN & release payout upon completion
 */
const verifyEscrowPin = async (req, res, next) => {
  try {
    const { transactionId, pin, role } = req.body;
    const uid = req.user ? req.user.uid : req.headers['x-user-uid'];

    if (!transactionId || !pin || !role) {
      return res.status(400).json({ success: false, error: 'Missing transactionId, pin, or role' });
    }

    const txDocRef = db.collection('transactions').doc(transactionId);

    const result = await db.runTransaction(async (t) => {
      const snap = await t.get(txDocRef);
      if (!snap.exists) {
        throw new Error(`Transaction ${transactionId} not found.`);
      }

      const tx = snap.data();
      const cleanPin = pin.toString().trim();

      let tenantPinVerified = tx.tenantPinVerified || false;
      let landlordPinVerified = tx.landlordPinVerified || false;

      if (role === 'tenant') {
        if (tx.landlordPin !== cleanPin) {
          throw new Error('Invalid Landlord Handover PIN. Please verify with the Landlord.');
        }
        tenantPinVerified = true;
      } else if (role === 'landlord') {
        if (tx.tenantPin !== cleanPin) {
          throw new Error('Invalid Tenant Key Receipt PIN. Please verify with the Tenant.');
        }
        landlordPinVerified = true;
      } else {
        throw new Error('Invalid user role specified.');
      }

      const bothVerified = tenantPinVerified && landlordPinVerified;
      const updates = {
        tenantPinVerified: tenantPinVerified,
        landlordPinVerified: landlordPinVerified,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (bothVerified) {
        updates.possessionConfirmed = true;
        updates.possessionConfirmedAt = admin.firestore.FieldValue.serverTimestamp();
        updates.status = 'releasing';
      }

      t.update(txDocRef, updates);

      return {
        txData: tx,
        tenantPinVerified,
        landlordPinVerified,
        bothVerified,
      };
    });

    // Execute automated payout if both PINs are verified
    if (result.bothVerified && !result.txData.landlordPaidOut) {
      try {
        const txData = result.txData;
        const landlordDoc = await db.collection('users').doc(txData.landlordId).get();
        const landlordData = landlordDoc.exists ? landlordDoc.data() : {};

        const bankCode = landlordData.bankCode || txData.landlordBankCode || '044';
        const accountNumber = landlordData.accountNumber || txData.landlordAccountNumber;
        const netPayoutAmount = txData.netPayoutAmount || Math.round((txData.amount || 0) * 0.95);

        if (accountNumber && bankCode) {
          const payoutRes = await flutterwaveService.executePayout({
            bankCode: bankCode,
            accountNumber: accountNumber,
            amount: netPayoutAmount,
            narration: `Agent Rent Escrow Payout - Property ${txData.propertyId || ''}`,
            reference: `PAYOUT-${transactionId}-${Date.now()}`,
          });

          await txDocRef.update({
            status: 'released',
            landlordPaidOut: true,
            payoutRef: payoutRes.id,
            payoutAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          await txDocRef.update({ status: 'released' });
        }

        // Notify Landlord & Tenant
        await sendPushNotification({
          userId: txData.landlordId,
          title: '💰 Escrow Payout Disbursed!',
          message: `₦${netPayoutAmount} has been sent directly to your bank account. Handshake complete!`,
          data: { type: 'payout', transactionId: transactionId },
        });
      } catch (payoutErr) {
        console.error('❌ Automated payout execution failed:', payoutErr.message);
        await txDocRef.update({ status: 'released', payoutError: payoutErr.message });
      }
    }

    return res.status(200).json({
      success: true,
      tenantPinVerified: result.tenantPinVerified,
      landlordPinVerified: result.landlordPinVerified,
      bothVerified: result.bothVerified,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get Escrow details
 */
const getEscrowStatus = async (req, res, next) => {
  try {
    const { transactionId } = req.params;
    const docSnap = await db.collection('transactions').doc(transactionId).get();
    if (!docSnap.exists) {
      return res.status(404).json({ success: false, error: 'Transaction not found' });
    }

    return res.status(200).json({ success: true, data: docSnap.data() });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  verifyEscrowPin,
  getEscrowStatus,
};
