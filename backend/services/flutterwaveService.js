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
 * Execute automated bank transfer payout to Landlord
 */
const executePayout = async ({ bankCode, accountNumber, amount, narration, reference }) => {
  try {
    const response = await flwClient.post('/transfers', {
      account_bank: bankCode,
      account_number: accountNumber,
      amount: amount,
      narration: narration || 'Agent Escrow Landlord Payout',
      currency: 'NGN',
      reference: reference || `PAYOUT-${Date.now()}`,
    });

    if (response.data && response.data.status === 'success') {
      return response.data.data;
    }
    throw new Error(response.data.message || 'Payout transfer failed.');
  } catch (error) {
    console.error('❌ Flutterwave Payout error:', error.response ? error.response.data : error.message);
    throw new Error(error.response?.data?.message || 'Flutterwave Payout Execution Failed.');
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
const createVirtualAccount = async ({ email, isPermanent = false, amount, txRef, bvn, firstname, lastname }) => {
  try {
    const payload = {
      email: email || 'tenant@agentapp.com',
      is_permanent: isPermanent,
      amount: amount,
      tx_ref: txRef,
      firstname: firstname || 'Tenant',
      lastname: lastname || 'User',
      narration: `Escrow Rent ${txRef}`,
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
  executePayout,
  resolveBankAccount,
  createVirtualAccount,
  initializeStandardPayment,
};

