/**
 * POST /payments/virtual-account
 * Generate a Flutterwave virtual account for escrow payment collection.
 *
 * Auth: Required (Firebase ID token)
 * Body: { transactionId: string, amount: number, email?: string, fullName?: string }
 */
import { requireAuth, AuthError } from '../auth.js';
import { createVirtualAccount } from '../flutterwave.js';

export async function handleVirtualAccount(request, env) {
  let user;
  try {
    user = await requireAuth(request, env.FIREBASE_PROJECT_ID);
  } catch (err) {
    if (err instanceof AuthError) return jsonError(err.message, err.statusCode);
    return jsonError('Authentication failed', 401);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonError('Invalid JSON body', 400);
  }

  const { transactionId, amount, email, fullName } = body;
  if (!transactionId || !amount) {
    return jsonError('Missing transactionId or amount', 400);
  }

  const txRef = `FLW-ESC-${transactionId.substring(0, 8).toUpperCase()}`;
  const nameParts = (fullName || 'Tenant User').trim().split(' ');
  const firstname = nameParts[0] || 'Tenant';
  const lastname = nameParts.slice(1).join(' ') || 'User';

  try {
    const result = await createVirtualAccount(
      {
        email: email || 'tenant@agentapp.com',
        amount: parseInt(amount, 10),
        txRef,
        firstname,
        lastname,
      },
      env.FLUTTERWAVE_SECRET_KEY
    );

    return jsonOk(result);
  } catch (err) {
    return jsonError(err.message || 'Virtual account creation failed', 400);
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
