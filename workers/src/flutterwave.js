/**
 * Flutterwave API helper for Cloudflare Workers
 * All calls use the server-side secret key from environment variables.
 * The key NEVER leaves the Worker — it is never sent to or exposed on the client.
 */

const FLW_BASE = 'https://api.flutterwave.com/v3';

/**
 * Make an authenticated request to Flutterwave API.
 */
async function flwRequest(method, path, body, secretKey) {
  const options = {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${secretKey.trim()}`,
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(`${FLW_BASE}${path}`, options);
  const data = await response.json();
  return { response, data };
}

/**
 * Resolve a NUBAN bank account number to the account holder name.
 */
export async function resolveBankAccount({ accountNumber, bankCode }, secretKey) {
  const { response, data } = await flwRequest(
    'POST',
    '/accounts/resolve',
    { account_number: accountNumber.trim(), account_bank: bankCode.trim() },
    secretKey
  );

  if (response.ok && data.status === 'success') {
    return {
      accountName: data.data.account_name,
      accountNumber: data.data.account_number,
    };
  }

  throw new Error(data.message || 'Unable to resolve bank account.');
}

/**
 * Create a dynamic Flutterwave Virtual Account (NUBAN) for escrow payments.
 */
export async function createVirtualAccount(
  { email, amount, txRef, firstname, lastname },
  secretKey
) {
  const payload = {
    email: email || 'tenant@agentapp.com',
    is_permanent: false,
    tx_ref: txRef,
    firstname: firstname || 'Tenant',
    lastname: lastname || 'User',
    narration: `Escrow Rent ${txRef}`,
  };

  // Flutterwave caps fixed-amount virtual accounts at ₦7,390,000
  if (amount > 0 && amount <= 7390000) {
    payload.amount = amount;
  }

  const { response, data } = await flwRequest(
    'POST',
    '/virtual-account-numbers',
    payload,
    secretKey
  );

  if (response.ok && data.status === 'success' && data.data) {
    const acct = data.data;

    // Retry without amount if Flutterwave rejects due to amount cap
    if (!acct.account_number) {
      throw new Error(data.message || 'Virtual account creation failed.');
    }

    return {
      accountNumber: acct.account_number,
      bankName: acct.bank_name || 'Wema Bank (Flutterwave)',
      accountName: acct.note || acct.account_name || 'FLUTTERWAVE / AGENT ESCROW',
      txRef,
    };
  }

  // If amount was included and Flutterwave rejected it, retry without amount
  if (payload.amount && data.message && data.message.includes('amount should be between')) {
    delete payload.amount;
    const retry = await flwRequest('POST', '/virtual-account-numbers', payload, secretKey);
    if (retry.response.ok && retry.data.status === 'success' && retry.data.data?.account_number) {
      const acct = retry.data.data;
      return {
        accountNumber: acct.account_number,
        bankName: acct.bank_name || 'Wema Bank (Flutterwave)',
        accountName: acct.note || acct.account_name || 'FLUTTERWAVE / AGENT ESCROW',
        txRef,
      };
    }
    throw new Error(retry.data.message || 'Virtual account creation failed after retry.');
  }

  throw new Error(data.message || 'Virtual account creation failed.');
}

/**
 * Verify a Flutterwave transaction by tx_ref.
 * Returns true if the payment is successful.
 */
export async function verifyPaymentByRef(txRef, secretKey) {
  const { response, data } = await flwRequest(
    'GET',
    `/transactions/verify_by_reference?tx_ref=${encodeURIComponent(txRef)}`,
    null,
    secretKey
  );

  if (response.ok && data.status === 'success' && data.data) {
    const status = (data.data.status || '').toLowerCase();
    return status === 'successful' || status === 'success' || status === 'completed';
  }

  return false;
}

/**
 * Verify a Flutterwave transaction by Flutterwave transaction ID.
 */
export async function verifyPaymentById(flwTxId, secretKey) {
  const { response, data } = await flwRequest(
    'GET',
    `/transactions/${flwTxId}/verify`,
    null,
    secretKey
  );

  if (response.ok && data.status === 'success' && data.data) {
    return data.data;
  }

  return null;
}

/**
 * Execute a bank transfer (payout) to a landlord or user bank account.
 * This is the money-movement call — only called from server-side.
 */
export async function executePayout(
  { bankCode, accountNumber, amount, narration, reference },
  secretKey
) {
  const { response, data } = await flwRequest(
    'POST',
    '/transfers',
    {
      account_bank: bankCode.trim(),
      account_number: accountNumber.trim(),
      amount,
      currency: 'NGN',
      narration: narration || 'Agent App Payout',
      reference: reference || `PAYOUT-${Date.now()}`,
    },
    secretKey
  );

  if (response.ok && data.status === 'success') {
    return data.data;
  }

  const errorMsg = data.message || 'Payout transfer failed.';
  throw new Error(errorMsg);
}
