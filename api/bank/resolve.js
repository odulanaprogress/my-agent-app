/**
 * POST /api/bank/resolve — Vercel Serverless Function
 *
 * Resolves a NUBAN bank account number to account holder name via Flutterwave.
 * Requires a valid Firebase ID token in the Authorization header.
 *
 * This endpoint exists for the Flutter web client (CORS proxy).
 * Mobile clients now also route through Cloudflare Workers (/bank/resolve).
 * This Vercel function is kept as a fallback/redundancy for the web build.
 */
import admin from 'firebase-admin';

// Initialize Firebase Admin once (Vercel keeps instances warm between calls)
if (!admin.apps.length) {
  const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
    ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
    : null;

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else {
    // Fallback: use application default credentials (works on Firebase hosting)
    admin.initializeApp();
  }
}

export default async function handler(req, res) {
  // Restrict CORS to your actual app origins — not wildcard
  const allowedOrigin = process.env.ALLOWED_ORIGIN || 'https://my-agent-app-teal.vercel.app';
  const origin = req.headers.origin || '';

  res.setHeader('Access-Control-Allow-Origin', origin === allowedOrigin || !origin ? allowedOrigin : 'null');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed' });
  }

  // ── Firebase Token Verification ─────────────────────────────────────────
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Missing token.' });
  }

  try {
    await admin.auth().verifyIdToken(authHeader.slice(7));
  } catch {
    return res.status(401).json({ success: false, error: 'Unauthorized: Invalid or expired token.' });
  }

  // ── Request Validation ──────────────────────────────────────────────────
  const { accountNumber, bankCode } = req.body;
  if (!accountNumber || !bankCode) {
    return res.status(400).json({ success: false, error: 'Missing accountNumber or bankCode' });
  }

  if (accountNumber.trim().length !== 10) {
    return res.status(400).json({ success: false, error: 'accountNumber must be 10 digits' });
  }

  const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
  if (!secretKey) {
    return res.status(500).json({ success: false, error: 'Server misconfiguration: missing key.' });
  }

  // ── Flutterwave API Call ─────────────────────────────────────────────────
  try {
    const response = await fetch('https://api.flutterwave.com/v3/accounts/resolve', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${secretKey.trim()}`,
      },
      body: JSON.stringify({
        account_number: accountNumber.trim(),
        account_bank: bankCode.trim(),
      }),
    });

    const body = await response.json();

    if (response.ok && body.status === 'success') {
      return res.status(200).json({
        success: true,
        data: {
          accountName: body.data.account_name,
          accountNumber: body.data.account_number,
        },
      });
    }

    return res.status(response.status).json({
      success: false,
      error: body.message || 'Unable to resolve bank account.',
    });
  } catch (error) {
    console.error('Flutterwave resolve error:', error);
    return res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
}
