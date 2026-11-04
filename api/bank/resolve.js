/**
 * POST /api/bank/resolve — Vercel Serverless Function
 *
 * Resolves a NUBAN bank account number to account holder name via Flutterwave.
 * Requires a valid Firebase ID token in the Authorization header.
 * Uses Google's public JWK keys to verify Firebase RS256 JWTs natively.
 */
import crypto from 'crypto';

let cachedJwks = null;
let cacheExpiry = 0;

async function getGoogleJwks() {
  const now = Date.now();
  if (cachedJwks && now < cacheExpiry) {
    return cachedJwks;
  }
  const response = await fetch(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'
  );
  if (!response.ok) {
    throw new Error('Failed to fetch Google public keys');
  }
  const data = await response.json();
  cachedJwks = data.keys || [];
  cacheExpiry = now + 3600000;
  return cachedJwks;
}

async function verifyFirebaseToken(token, projectId = 'agent-app-67bc4') {
  if (!token) throw new Error('No token provided');
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Malformed token');

  const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));

  if (header.alg !== 'RS256') throw new Error('Invalid token algorithm');
  const now = Math.floor(Date.now() / 1000);
  if (!payload.exp || payload.exp < now) throw new Error('Token has expired');
  if (payload.aud !== projectId) throw new Error('Invalid token audience');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('Invalid token issuer');

  const keys = await getGoogleJwks();
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('Signing key not found');

  const pubKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  const verify = crypto.createVerify('RSA-SHA256');
  verify.update(`${parts[0]}.${parts[1]}`);
  const valid = verify.verify(pubKey, parts[2], 'base64url');
  if (!valid) throw new Error('Invalid token signature');

  return payload;
}

export default async function handler(req, res) {
  const allowedOrigins = [
    process.env.ALLOWED_ORIGIN,
    'https://agentmobiletech.com',
    'https://www.agentmobiletech.com',
    'https://api.agentmobiletech.com',
    'https://my-agent-app-teal.vercel.app',
    'http://localhost:3000',
  ].filter(Boolean);

  const origin = req.headers.origin || '';
  const isAllowedOrigin = !origin || allowedOrigins.includes(origin);

  res.setHeader('Access-Control-Allow-Origin', isAllowedOrigin ? (origin || '*') : 'null');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

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

  const token = authHeader.slice(7).trim();
  try {
    await verifyFirebaseToken(token, 'agent-app-67bc4');
  } catch (err) {
    return res.status(401).json({ success: false, error: `Unauthorized: ${err.message}` });
  }

  // ── Request Validation ──────────────────────────────────────────────────
  const { accountNumber, bankCode } = req.body || {};
  if (!accountNumber || !bankCode) {
    return res.status(400).json({ success: false, error: 'Missing accountNumber or bankCode' });
  }

  if (accountNumber.trim().length !== 10) {
    return res.status(400).json({ success: false, error: 'accountNumber must be 10 digits' });
  }

  const secretKey =
    process.env.FLUTTERWAVE_SECRET_KEY ||
    'FLWSECK-cffcd8414166c11c09046a0b37605d8f-1a05591bf14vt-X';

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

    return res.status(response.status >= 400 && response.status < 500 ? response.status : 400).json({
      success: false,
      error: body.message || 'Unable to resolve bank account.',
    });
  } catch (error) {
    console.error('Flutterwave resolve error:', error);
    return res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
}
