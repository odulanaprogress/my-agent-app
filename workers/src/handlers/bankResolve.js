/**
 * POST /bank/resolve
 * Resolve a NUBAN bank account number to the account holder name.
 *
 * Auth: Required (Firebase ID token)
 * Body: { accountNumber: string, bankCode: string }
 */
import { requireAuth, AuthError } from '../auth.js';
import { resolveBankAccount } from '../flutterwave.js';

export async function handleBankResolve(request, env) {
  // Require Firebase auth
  let user;
  try {
    user = await requireAuth(request, env.FIREBASE_PROJECT_ID);
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonError(err.message, err.statusCode);
    }
    return jsonError('Authentication failed', 401);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonError('Invalid JSON body', 400);
  }

  const { accountNumber, bankCode } = body;
  if (!accountNumber || !bankCode) {
    return jsonError('Missing accountNumber or bankCode', 400);
  }

  if (accountNumber.trim().length !== 10) {
    return jsonError('accountNumber must be a 10-digit NUBAN', 400);
  }

  try {
    const result = await resolveBankAccount({ accountNumber, bankCode }, env.FLUTTERWAVE_SECRET_KEY);
    return jsonOk({ data: result });
  } catch (err) {
    return jsonError(err.message || 'Unable to resolve bank account', 400);
  }
}

function jsonOk(data) {
  return new Response(JSON.stringify({ success: true, ...data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function jsonError(message, status = 400) {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
