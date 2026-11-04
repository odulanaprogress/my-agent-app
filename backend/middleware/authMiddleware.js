const { admin } = require('../config/firebase');
const crypto = require('crypto');

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

async function verifyFirebaseTokenJWK(token, projectId = 'agent-app-67bc4') {
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

  return {
    uid: payload.user_id || payload.sub,
    ...payload,
  };
}

/**
 * Authentication Middleware
 *
 * Verifies Firebase ID Token from Authorization: Bearer <token> header.
 * 1. Attempts verification with Firebase Admin SDK.
 * 2. If Admin SDK lacks credentials on serverless, falls back to native
 *    Google RS256 JWK public key verification.
 *
 * Sets req.user to the decoded Firebase token payload with trusted req.user.uid.
 */
const requireAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Missing or invalid Authorization header.',
      });
    }

    const token = authHeader.split('Bearer ')[1].trim();

    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      req.user = decodedToken;
      return next();
    } catch (adminErr) {
      try {
        const decodedToken = await verifyFirebaseTokenJWK(token, 'agent-app-67bc4');
        req.user = decodedToken;
        return next();
      } catch (jwkErr) {
        console.error('Auth verification failed:', adminErr.message, jwkErr.message);
        return res.status(401).json({
          success: false,
          error: 'Unauthorized: Invalid or expired Firebase token.',
        });
      }
    }
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Internal authentication error.',
    });
  }
};

module.exports = { requireAuth };
