const flwClient = require('../config/flutterwave');

/**
 * Double-check payment status directly with Flutterwave API
 */
const verifyTransaction = async (flwTxId) => {
  try {
    const response = await flwClient.get(`/transactions/${flwTxId}/verify`);
    if (response.data && response.data.status === 'success') {
      return response.data.data;
    }
    return null;
  } catch (error) {
    console.error('❌ Flutterwave verification error:', error.response ? error.response.data : error.message);
    throw new Error('Flutterwave API transaction verification failed.');
  }
};

/**
 * Double-check payment status directly with Flutterwave API by transaction reference (tx_ref)
 */
const verifyTransactionByRef = async (txRef) => {
  try {
    const response = await flwClient.get(`/transactions?tx_ref=${encodeURIComponent(txRef)}`);
    if (response.data && response.data.status === 'success' && response.data.data) {
      const items = Array.isArray(response.data.data) ? response.data.data : [response.data.data];
      const successfulTx = items.find((tx) => tx.status === 'successful');
      if (successfulTx) {
        return successfulTx;
      }
    }
    return null;
  } catch (error) {
    console.error('❌ Flutterwave verify by txRef error:', error.response ? error.response.data : error.message);
    return null;
  }
};

/**
 * Execute automated bank transfer payout
 * NOTE: Flutterwave's /transfers API returns status:"success" when the transfer
 * is QUEUED, but the actual transfer data.status can be "NEW", "PENDING", or "FAILED".
 * We check both levels so failed transfers are caught immediately.
 */
const executePayout = async ({ bankCode, accountNumber, amount, narration, reference }) => {
  try {
    const response = await flwClient.post('/transfers', {
      account_bank: bankCode,
      account_number: accountNumber,
      amount: amount,
      narration: narration || 'Agent Wallet Withdrawal',
      currency: 'NGN',
      reference: reference || `PAYOUT-${Date.now()}`,
    });

    // Level 1: API call accepted
    if (response.data && response.data.status === 'success') {
      const transferData = response.data.data;

      // Level 2: Actual transfer status
      if (transferData && transferData.status === 'FAILED') {
        const reason = transferData.complete_message || transferData.narration || 'Transfer was rejected by Flutterwave.';
        console.error(`❌ Transfer FAILED immediately: ref=${transferData.reference}, reason=${reason}`);
        throw new Error(`Transfer failed: ${reason}`);
      }

      // NEW / PENDING = queued successfully, webhook will confirm completion
      console.log(`💸 Transfer queued: ref=${transferData?.reference}, status=${transferData?.status}, amount=₦${amount}`);
      return transferData;
    }

    throw new Error(response.data?.message || 'Payout transfer failed.');
  } catch (error) {
    // Re-throw cleanly if already our custom Error
    if (error.message && error.message.startsWith('Transfer failed:')) throw error;
    console.error('❌ Flutterwave Payout error:', error.response ? error.response.data : error.message);
    const msg = error.response?.data?.message || error.message || 'Flutterwave Payout Execution Failed.';
    throw new Error(msg);
  }
};


/**
 * Resolve NUBAN bank account number to account holder name
 */
const resolveBankAccount = async ({ accountNumber, bankCode }) => {
  try {
    const response = await flwClient.post('/accounts/resolve', {
      account_number: accountNumber,
      account_bank: bankCode,
    });

    if (response.data && response.data.status === 'success') {
      return {
        accountName: response.data.data.account_name,
        accountNumber: response.data.data.account_number,
      };
    }
    throw new Error(response.data.message || 'Unable to resolve bank account.');
  } catch (error) {
    console.error('❌ Bank account resolution error:', error.response ? error.response.data : error.message);
    throw new Error(error.response?.data?.message || 'Bank account resolution failed.');
  }
};

/**
 * Create dynamic Flutterwave Virtual Account NUBAN for direct bank transfer payments
 */
const createVirtualAccount = async ({ email, isPermanent = false, amount, txRef, bvn, firstname, lastname, phonenumber }) => {
  try {
    const payload = {
      email: email || 'tenant@agentapp.com',
      is_permanent: isPermanent,
      amount: amount,
      tx_ref: txRef,
      firstname: firstname || 'Tenant',
      lastname: lastname || 'User',
      phonenumber: phonenumber || '08012345678',
      currency: 'NGN',
      narration: `Payment ${txRef}`,
    };
    if (bvn) {
      payload.bvn = bvn;
    }

    const response = await flwClient.post('/virtual-account-numbers', payload);

    if (response.data && response.data.status === 'success') {
      return response.data.data;
    }
    throw new Error(response.data.message || 'Virtual Account generation failed.');
  } catch (error) {
    console.error('❌ Flutterwave Virtual Account creation error:', error.response ? error.response.data : error.message);
    throw new Error(error.response?.data?.message || 'Flutterwave Virtual Account generation failed.');
  }
};

/**
 * Calculate dynamic Flutterwave transaction fees directly from Flutterwave API
 */
const calculateFee = async (amount, currency = 'NGN') => {
  try {
    const response = await flwClient.get(`/transactions/fee?amount=${amount}&currency=${currency}`);
    if (response.data && response.data.status === 'success') {
      return response.data.data;
    }
    return {
      fee: Math.round(amount * 0.014),
      charge_amount: Math.round(amount * 1.014),
    };
  } catch (error) {
    console.error('Flutterwave fee calculation error:', error.response ? error.response.data : error.message);
    return {
      fee: Math.round(amount * 0.014),
      charge_amount: Math.round(amount * 1.014),
    };
  }
};

/**
 * Initialize Flutterwave Standard Payment (Returns hosted checkout link)
 */
const initializeStandardPayment = async ({ amount, currency = 'NGN', txRef, redirectUrl, customer, title, description }) => {
  try {
    const response = await flwClient.post('/payments', {
      tx_ref: txRef,
      amount: amount,
      currency: currency,
      redirect_url: redirectUrl || 'https://my-agent-app-teal.vercel.app',
      customer: customer || { email: 'tenant@agentapp.com', name: 'Tenant User' },
      customizations: {
        title: title || 'Flutterwave Escrow Vault Payment',
        description: description || 'Property Escrow Payment',
        logo: 'https://flutterwave.com/images/logo/logo-square.png',
      },
    });

    if (response.data && response.data.status === 'success') {
      return response.data.data;
    }
    throw new Error(response.data.message || 'Flutterwave Standard Payment initialization failed.');
  } catch (error) {
    console.error('❌ Flutterwave Standard Payment error:', error.response ? error.response.data : error.message);
    throw new Error(error.response?.data?.message || 'Flutterwave Payment initialization failed.');
  }
};

module.exports = {
  verifyTransaction,
  verifyTransactionByRef,
  executePayout,
  resolveBankAccount,
  createVirtualAccount,
  calculateFee,
  initializeStandardPayment,
};

