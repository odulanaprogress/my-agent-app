const { db, admin } = require('../config/firebase');
const flutterwaveService = require('../services/flutterwaveService');

/**
 * Initialize payment reference
 */
const initializePayment = async (req, res, next) => {
  try {
    const { 
      transactionId, 
      tenantId, 
      landlordId, 
      propertyId, 
      amount,
      virtualAccountNumber,
      virtualBankName,
      virtualAccountName,
      txRef: clientTxRef
    } = req.body;

    if (!tenantId || !landlordId || !propertyId || !amount) {
      return res.status(400).json({ success: false, error: 'Missing tenantId, landlordId, propertyId, or amount' });
    }

    const txRef = clientTxRef || transactionId || `AGENT-ESCROW-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    const tenantPin = Math.floor(100000 + Math.random() * 900000).toString();
    const landlordPin = Math.floor(100000 + Math.random() * 900000).toString();

    const commissionPercent = 20.0;
    const commissionAmount = Math.round(amount * (commissionPercent / 100));
    const netPayoutAmount = amount - commissionAmount;

    const batch = db.batch();
    const txDoc = db.collection('transactions').doc(txRef);

    batch.set(txDoc, {
      id: txRef,
      tenantId: tenantId,
      landlordId: landlordId,
      propertyId: propertyId,
      amount: parseInt(amount, 10),
      commissionPercent,
      commissionAmount,
      netPayoutAmount,
      status: 'pending',
      type: 'escrow',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      possessionConfirmed: false,
      landlordPaidOut: false,
      tenantPinVerified: false,
      landlordPinVerified: false,
      ...(virtualAccountNumber && { virtualAccountNumber }),
      ...(virtualBankName && { virtualBankName }),
      ...(virtualAccountName && { virtualAccountName }),
    });

    const tenantPinDoc = txDoc.collection('pins').doc(tenantId);
    batch.set(tenantPinDoc, { pin: tenantPin, role: 'tenant' });

    const landlordPinDoc = txDoc.collection('pins').doc(landlordId);
    batch.set(landlordPinDoc, { pin: landlordPin, role: 'landlord' });

    await batch.commit();

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
 * Verify payment status by transactionId or txRef (for client polling)
 */
const verifyPaymentByRef = async (req, res, next) => {
  try {
    const { transactionId, txRef } = req.body;
    
    if (!transactionId) {
      return res.status(400).json({ success: false, error: 'transactionId is required' });
    }

    const txDoc = await db.collection('transactions').doc(transactionId).get();
    if (!txDoc.exists) {
      return res.status(404).json({ success: false, error: 'Transaction not found' });
    }

    const txData = txDoc.data();
    if (txData.status === 'held' || txData.status === 'successful' || txData.status === 'released') {
      return res.status(200).json({
        verified: true,
        status: 'successful'
      });
    }

    // Direct Flutterwave API query fallback
    const refToQuery = txRef || txData.txRef || transactionId;
    if (refToQuery) {
      const flwTx = await flutterwaveService.verifyTransactionByRef(refToQuery);
      if (flwTx && flwTx.status === 'successful') {
        const amountPaid = flwTx.amount || txData.amount;

        if (refToQuery.includes('DEP') || txData.type === 'deposit') {
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

              t.set(txDoc.ref, {
                status: 'completed',
                flutterwaveTxId: flwTx.id,
                amount: amountPaid,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
            });
          }
          return res.status(200).json({
            verified: true,
            status: 'successful',
            data: flwTx,
          });
        }

        await txDoc.ref.update({
          status: 'held',
          flutterwaveTxId: flwTx.id,
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return res.status(200).json({
          verified: true,
          status: 'successful',
          data: flwTx,
        });
      }
    }

    return res.status(200).json({
      verified: false,
      status: txData.status
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Generate Dedicated Flutterwave Merchant Virtual Account
 */
const generateVirtualAccount = async (req, res, next) => {
  try {
    const { transactionId, amount, email, fullName, bvn, phoneNumber, phone } = req.body;
    const cleanTxId = (transactionId || `TX-${Date.now()}`).toString().replace(/[^a-zA-Z0-9-_]/g, '');
    const txRef = req.body.txRef || (cleanTxId.startsWith('FLW-') ? cleanTxId : `FLW-${cleanTxId}`);

    if (process.env.FLUTTERWAVE_SECRET_KEY && process.env.FLUTTERWAVE_SECRET_KEY.startsWith('FLWSECK')) {
      const nameParts = (fullName || 'Agent User').trim().split(' ');
      const firstname = nameParts[0] || 'Agent';
      const lastname = nameParts.slice(1).join(' ') || 'User';

      const vaData = await flutterwaveService.createVirtualAccount({
        email: email || 'user@agentapp.com',
        isPermanent: false,
        amount: amount,
        txRef: txRef,
        bvn: bvn,
        firstname: firstname,
        lastname: lastname,
        phonenumber: phoneNumber || phone || '08012345678',
      });

      return res.status(200).json({
        success: true,
        accountNumber: vaData.account_number,
        bankName: vaData.bank_name || 'Flutterwave MFB',
        accountName: vaData.account_name || 'FLUTTERWAVE / AGENT ESCROW',
        txRef: txRef,
        flwRef: vaData.flw_ref,
        amount: vaData.amount ? parseFloat(vaData.amount) : amount,
        note: vaData.note,
        expiryDate: vaData.expiry_date,
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
    const { amount: rawAmount, bankCode, accountNumber } = req.body;

    // Coerce to number — Dart/JSON may send integers as strings in some encodings
    const amount = Number(rawAmount);
    if (!rawAmount || isNaN(amount) || amount <= 0) {
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
        amount: Math.round(amount), // Flutterwave requires whole NGN amount
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

/**
 * Calculate dynamic Flutterwave fee
 */
const getFlutterwaveFee = async (req, res, next) => {
  try {
    const amount = Number(req.query.amount) || 0;
    if (amount <= 0) {
      return res.status(400).json({ success: false, error: 'Valid amount is required' });
    }

    const feeData = await flutterwaveService.calculateFee(amount);
    return res.status(200).json({
      success: true,
      data: feeData,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  initializePayment,
  verifyPayment,
  verifyPaymentByRef,
  generateVirtualAccount,
  requestWithdrawal,
  getFlutterwaveFee,
};
