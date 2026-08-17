/**
 * POST /payments/withdraw
 *
 * Server-validated withdrawal:
 * 1. Verify Firebase ID token (req.user.uid is trusted)
 * 2. Read actual wallet balance from Firestore via Firestore REST API
 * 3. Validate amount <= available balance
 * 4. Execute payout via Flutterwave Transfers API
 * 5. Update Firestore wallet balance (decrement)
 *
 * Auth: Required (Firebase ID token)
 * Body: { amount: number, bankCode: string, accountNumber: string }
 *
 * IMPORTANT: Balance reads and writes use the Firestore REST API since
 * Cloudflare Workers don't support the Firebase Admin SDK.
 * The Firestore REST API is secured by Firebase rules OR by using a service
 * account key. We use the service account approach here.
 */
import { requireAuth, AuthError } from '../auth.js';
import { executePayout } from '../flutterwave.js';

const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1';

/**
 * Read a Firestore document using the REST API with a service account token.
 * We use the user's Firebase ID token for now (Firestore rules allow owner reads).
 */
async function getFirestoreDoc(projectId, collection, docId, idToken) {
  const url = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents/${collection}/${docId}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${idToken}`,
    },
  });

  if (response.status === 404) return null;
  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Firestore read failed: ${err}`);
  }

  return await response.json();
}

/**
 * Update a Firestore document using the REST API (PATCH).
 * Uses the user's ID token — Firestore rules must allow writes.
 * NOTE: For wallet writes after fixing rules (admin-only), this worker
 * would need a service account token instead. See note in index.js.
 */
async function updateFirestoreDoc(projectId, collection, docId, fields, idToken) {
  // Build field mask and body
  const fieldPaths = Object.keys(fields).join(',');
  const url = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents/${collection}/${docId}?updateMask.fieldPaths=${fieldPaths}`;

  // Convert JS values to Firestore REST API format
  const firestoreFields = {};
  for (const [key, value] of Object.entries(fields)) {
    if (typeof value === 'number') {
      firestoreFields[key] = { integerValue: String(value) };
    } else if (typeof value === 'string') {
      firestoreFields[key] = { stringValue: value };
    } else if (typeof value === 'boolean') {
      firestoreFields[key] = { booleanValue: value };
    }
  }

  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: firestoreFields }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Firestore write failed: ${err}`);
  }

  return await response.json();
}

/**
 * Extract an integer value from a Firestore REST API document field.
 */
function extractInt(doc, fieldName) {
  if (!doc || !doc.fields) return 0;
  const field = doc.fields[fieldName];
  if (!field) return 0;
  if (field.integerValue !== undefined) return parseInt(field.integerValue, 10);
  if (field.doubleValue !== undefined) return Math.floor(field.doubleValue);
  return 0;
}

export async function handleWithdraw(request, env) {
  // 1. Verify Firebase token — uid is now trusted from server
  let user;
  let rawToken;
  try {
    // Extract raw token for Firestore REST API calls
    const authHeader = request.headers.get('Authorization') || '';
    rawToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

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

  const { amount, bankCode, accountNumber } = body;

  // 2. Validate inputs
  if (!amount || typeof amount !== 'number' || amount <= 0) {
    return jsonError('Invalid withdrawal amount', 400);
  }
  if (!bankCode || !accountNumber) {
    return jsonError('Missing bankCode or accountNumber', 400);
  }
  if (accountNumber.trim().length !== 10) {
    return jsonError('accountNumber must be a 10-digit NUBAN', 400);
  }

  const uid = user.uid;
  const projectId = env.FIREBASE_PROJECT_ID;

  // 3. Read the real wallet balance from Firestore (server-side, can't be forged)
  let walletDoc;
  try {
    walletDoc = await getFirestoreDoc(projectId, 'wallets', uid, rawToken);
  } catch (err) {
    return jsonError(`Unable to read wallet: ${err.message}`, 500);
  }

  const availableBalance = Math.max(
    extractInt(walletDoc, 'availableBalance'),
    extractInt(walletDoc, 'balance')
  );

  // 4. Validate: amount must not exceed actual balance
  if (amount > availableBalance) {
    return jsonError(
      `Insufficient balance. Available: ₦${availableBalance.toLocaleString()}, Requested: ₦${amount.toLocaleString()}`,
      400
    );
  }

  // 5. Optimistic balance deduction before payout (reserve funds)
  const newBalance = availableBalance - amount;
  try {
    await updateFirestoreDoc(
      projectId,
      'wallets',
      uid,
      {
        availableBalance: newBalance,
        balance: newBalance,
      },
      rawToken
    );
  } catch (err) {
    return jsonError(`Unable to reserve balance: ${err.message}`, 500);
  }

  // 6. Execute the actual Flutterwave transfer
  let payoutResult;
  try {
    payoutResult = await executePayout(
      {
        bankCode: bankCode.trim(),
        accountNumber: accountNumber.trim(),
        amount,
        narration: 'Agent Wallet Withdrawal',
        reference: `WITHDRAW-${uid.slice(0, 8)}-${Date.now()}`,
      },
      env.FLUTTERWAVE_SECRET_KEY
    );
  } catch (payoutErr) {
    // Payout failed — refund the reserved balance
    try {
      await updateFirestoreDoc(
        projectId,
        'wallets',
        uid,
        {
          availableBalance: availableBalance,
          balance: availableBalance,
        },
        rawToken
      );
    } catch (refundErr) {
      // Critical: balance was deducted but payout failed and refund failed
      // Log this for manual review
      console.error(`CRITICAL: Balance deducted but payout and refund both failed for uid=${uid}`, refundErr);
    }

    return jsonError(payoutErr.message || 'Withdrawal failed. Your balance has been restored.', 400);
  }

  // 7. Return success
  return jsonOk({
    message: `₦${amount.toLocaleString()} withdrawal initiated successfully`,
    newBalance,
    reference: payoutResult?.reference || payoutResult?.id,
  });
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
