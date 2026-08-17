const { db, admin } = require('../config/firebase');
const flutterwaveService = require('../services/flutterwaveService');

/**
 * Initialize payment reference
 */
const initializePayment = async (req, res, next) => {
  try {
    const { tenantId, landlordId, propertyId, amount } = req.body;
    if (!tenantId || !landlordId || !propertyId || !amount) {
      return res.status(400).json({ success: false, error: 'Missing tenantId, landlordId, propertyId, or amount' });
    }

    const txRef = `AGENT-ESCROW-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    await db.collection('transactions').doc(txRef).set({
      id: txRef,
      tenantId: tenantId,
      landlordId: landlordId,
      propertyId: propertyId,
      amount: parseInt(amount, 10),
      status: 'pending',
      type: 'escrow',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      possessionConfirmed: false,
      landlordPaidOut: false,
    });

    return res.status(200).json({
      success: true,
      txRef: txRef,
      publicKey: process.env.FLUTTERWAVE_PUBLIC_KEY,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Direct Client Verification fallback
 */
const verifyPayment = async (req, res, next) => {
  try {
    const { flwTxId, txRef } = req.params;
    const verifiedData = await flutterwaveService.verifyTransaction(flwTxId);

    if (verifiedData && verifiedData.status === 'successful') {
      return res.status(200).json({
        success: true,
        data: verifiedData,
      });
    }

    return res.status(400).json({ success: false, error: 'Payment not successful.' });
  } catch (error) {
    next(error);
  }
};

/**
 * Generate Dedicated Flutterwave Merchant Virtual Account
 */
const generateVirtualAccount = async (req, res, next) => {
  try {
    const { transactionId, amount, email, fullName, bvn } = req.body;
    const txRef = `FLW-ESC-${transactionId ? transactionId.substring(0, 8).toUpperCase() : Date.now()}`;

    if (process.env.FLUTTERWAVE_SECRET_KEY && process.env.FLUTTERWAVE_SECRET_KEY.startsWith('FLWSECK')) {
      const nameParts = (fullName || 'Tenant User').trim().split(' ');
      const firstname = nameParts[0] || 'Tenant';
      const lastname = nameParts.slice(1).join(' ') || 'User';

      const vaData = await flutterwaveService.createVirtualAccount({
        email: email || 'tenant@agentapp.com',
        isPermanent: false,
        amount: amount,
        txRef: txRef,
        bvn: bvn,
        firstname: firstname,
        lastname: lastname,
      });

      return res.status(200).json({
        success: true,
        accountNumber: vaData.account_number,
        bankName: vaData.bank_name || 'Wema Bank (Flutterwave)',
        accountName: vaData.account_name || 'FLUTTERWAVE / AGENT ESCROW',
        txRef: txRef,
        flwRef: vaData.flw_ref,
      });
    }

    // If FLUTTERWAVE_SECRET_KEY is not configured or in test mode without live keys
    return res.status(400).json({
      success: false,
      error: 'Flutterwave Secret Key not configured in backend environment variables.',
    });
  } catch (error) {
    next(error);
  }
};


/**
 * Server-validated withdrawal.
 * Reads the real wallet balance via Admin SDK (cannot be forged by client),
 * validates amount, reserves funds, then executes the Flutterwave transfer.
 */
const requestWithdrawal = async (req, res, next) => {
  try {
    const uid = req.user.uid; // from verified Firebase token only
    const { amount, bankCode, accountNumber } = req.body;

    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ success: false, error: 'Invalid withdrawal amount.' });
    }
    if (!bankCode || !accountNumber) {
      return res.status(400).json({ success: false, error: 'Missing bankCode or accountNumber.' });
    }

    const walletRef = db.collection('wallets').doc(uid);

    // Atomically check balance and reserve funds
    let reserved = false;
    let availableBalance = 0;

    await db.runTransaction(async (t) => {
      const snap = await t.get(walletRef);
      const data = snap.exists ? snap.data() : {};
      availableBalance = data.availableBalance ?? data.balance ?? 0;

      if (amount > availableBalance) {
        throw new Error(`Insufficient balance. Available: ₦${availableBalance}, Requested: ₦${amount}`);
      }

      const newBalance = availableBalance - amount;
      t.set(walletRef, {
        availableBalance: newBalance,
        balance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      reserved = true;
    });

    // Balance reserved — now execute the Flutterwave transfer
    let payoutRes;
    try {
      payoutRes = await flutterwaveService.executePayout({
        bankCode: bankCode.trim(),
        accountNumber: accountNumber.trim(),
        amount,
        narration: 'Agent Wallet Withdrawal',
        reference: `WITHDRAW-${uid.slice(0, 8)}-${Date.now()}`,
      });
    } catch (payoutErr) {
      // Payout failed — refund the reserved balance
      if (reserved) {
        try {
          await walletRef.set({
            availableBalance: availableBalance,
            balance: availableBalance,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        } catch (refundErr) {
          console.error(`CRITICAL: Balance reserved but payout AND refund both failed for uid=${uid}`, refundErr);
        }
      }
      return res.status(400).json({
        success: false,
        error: payoutErr.message || 'Withdrawal failed. Your balance has been restored.',
      });
    }

    return res.status(200).json({
      success: true,
      message: `₦${amount} withdrawal initiated successfully.`,
      newBalance: availableBalance - amount,
      reference: payoutRes?.id || payoutRes?.reference,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  initializePayment,
  verifyPayment,
  generateVirtualAccount,
  requestWithdrawal,
};
