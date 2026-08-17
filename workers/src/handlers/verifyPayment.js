/**
 * POST /payments/verify
 * Verify a Flutterwave payment by tx_ref.
 *
 * Auth: Required (Firebase ID token)
 * Body: { transactionId: string, txRef: string }
 */
import { requireAuth, AuthError } from '../auth.js';
import { verifyPaymentByRef } from '../flutterwave.js';

export async function handleVerifyPayment(request, env) {
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

  const { txRef } = body;
  if (!txRef) {
    return jsonError('Missing txRef', 400);
  }

  try {
    const verified = await verifyPaymentByRef(txRef, env.FLUTTERWAVE_SECRET_KEY);

    if (verified) {
      return jsonOk({ verified: true, status: 'successful' });
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          verified: false,
          error: 'Payment has not been confirmed yet. Please ensure you have transferred the funds.',
        }),
        { status: 402, headers: { 'Content-Type': 'application/json' } }
      );
    }
  } catch (err) {
    return jsonError(err.message || 'Payment verification failed', 400);
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
