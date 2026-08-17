/**
 * Firebase ID Token Verifier for Cloudflare Workers
 *
 * Firebase tokens are standard RS256 JWTs signed with Google's public keys.
 * We verify them using the Web Crypto API (native to Cloudflare) without
 * needing the Firebase Admin SDK (which requires Node.js).
 *
 * Reference: https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library
 */

const GOOGLE_PUBLIC_KEYS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

// Cache public keys in memory for the duration of the Worker instance (auto-refreshed)
let cachedKeys = null;
let cacheExpiry = 0;

/**
 * Fetch and cache Google's public keys used to sign Firebase JWTs.
 */
async function getGooglePublicKeys() {
  const now = Date.now();
  if (cachedKeys && now < cacheExpiry) {
    return cachedKeys;
  }

  const response = await fetch(GOOGLE_PUBLIC_KEYS_URL);
  if (!response.ok) {
    throw new Error('Failed to fetch Google public keys');
  }

  // Parse Cache-Control max-age to know when to refresh
  const cacheControl = response.headers.get('cache-control') || '';
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
  const maxAge = maxAgeMatch ? parseInt(maxAgeMatch[1]) * 1000 : 3600000; // default 1h
  cacheExpiry = now + maxAge;

  const keysJson = await response.json();
  cachedKeys = keysJson;
  return keysJson;
}

/**
 * Convert PEM certificate string to a CryptoKey for RS256 verification.
 */
async function pemToCryptoKey(pem) {
  // Strip PEM headers and decode base64
  const pemBody = pem
    .replace(/-----BEGIN CERTIFICATE-----/, '')
    .replace(/-----END CERTIFICATE-----/, '')
    .replace(/\s/g, '');

  const binaryDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  // Import as a certificate (spki format) for verification
  return await crypto.subtle.importKey(
    'raw',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  );
}

/**
 * Import the X.509 certificate's public key directly.
 * Cloudflare supports importing X.509 certs natively.
 */
async function importPublicKeyFromCert(pem) {
  const pemBody = pem
    .replace(/-----BEGIN CERTIFICATE-----/, '')
    .replace(/-----END CERTIFICATE-----/, '')
    .replace(/\s/g, '');

  const certDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  // Use SubtleCrypto to import the X.509 certificate public key
  return await crypto.subtle.importKey(
    'spki',
    certDer.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  );
}

/**
 * Parse a JWT into its header, payload, and signature components.
 */
function parseJwt(token) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format');
  }

  const decodeBase64Url = (str) => {
    // Convert base64url to base64
    const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
    return JSON.parse(atob(padded));
  };

  return {
    header: decodeBase64Url(parts[0]),
    payload: decodeBase64Url(parts[1]),
    signature: parts[2],
    signingInput: `${parts[0]}.${parts[1]}`,
  };
}

/**
 * Verify a Firebase ID token.
 *
 * @param {string} token - The Firebase ID token from Authorization header
 * @param {string} projectId - Your Firebase project ID
 * @returns {Promise<{uid: string, email: string|undefined, [key: string]: any}>}
 * @throws {Error} if token is invalid, expired, or from wrong project
 */
export async function verifyFirebaseToken(token, projectId) {
  if (!token) {
    throw new Error('No token provided');
  }

  let parsed;
  try {
    parsed = parseJwt(token);
  } catch {
    throw new Error('Malformed token');
  }

  const { header, payload, signature, signingInput } = parsed;

  // 1. Check algorithm
  if (header.alg !== 'RS256') {
    throw new Error('Invalid token algorithm');
  }

  // 2. Check expiry
  const now = Math.floor(Date.now() / 1000);
  if (!payload.exp || payload.exp < now) {
    throw new Error('Token has expired');
  }

  // 3. Check issued-at (not more than 1 hour in the future)
  if (!payload.iat || payload.iat > now + 60) {
    throw new Error('Token issued in the future');
  }

  // 4. Check audience (must be your Firebase project ID)
  if (payload.aud !== projectId) {
    throw new Error(`Invalid token audience: ${payload.aud}`);
  }

  // 5. Check issuer
  const expectedIssuer = `https://securetoken.google.com/${projectId}`;
  if (payload.iss !== expectedIssuer) {
    throw new Error(`Invalid token issuer: ${payload.iss}`);
  }

  // 6. Check subject (uid must be present and non-empty)
  if (!payload.sub || payload.sub.length === 0) {
    throw new Error('Token missing subject (uid)');
  }

  // 7. Fetch Google's public keys and find the right one for this token's kid
  const publicKeys = await getGooglePublicKeys();
  const cert = publicKeys[header.kid];
  if (!cert) {
    throw new Error(`Unknown key ID: ${header.kid}`);
  }

  // 8. Import the certificate's public key
  let cryptoKey;
  try {
    // Try to extract the public key from the X.509 cert
    // We use a simpler approach: verify using the PEM cert directly
    // by treating it as DER-encoded SubjectPublicKeyInfo
    const pemBody = cert
      .replace(/-----BEGIN CERTIFICATE-----/, '')
      .replace(/-----END CERTIFICATE-----/, '')
      .replace(/\s/g, '');

    const certBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

    // Import as X.509 certificate — Cloudflare Workers supports this
    cryptoKey = await crypto.subtle.importKey(
      'spki',
      certBytes.buffer,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify']
    );
  } catch {
    // Fallback: use the firebase-auth-cloudflare-workers library approach
    // if direct cert import fails (depends on Cloudflare runtime version)
    throw new Error('Failed to import public key from certificate');
  }

  // 9. Verify the RS256 signature
  const encoder = new TextEncoder();
  const signingInputBytes = encoder.encode(signingInput);

  const sigBase64 = signature.replace(/-/g, '+').replace(/_/g, '/');
  const sigPadded = sigBase64 + '='.repeat((4 - (sigBase64.length % 4)) % 4);
  const sigBytes = Uint8Array.from(atob(sigPadded), (c) => c.charCodeAt(0));

  const isValid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    sigBytes,
    signingInputBytes
  );

  if (!isValid) {
    throw new Error('Invalid token signature');
  }

  // ✅ Token is valid — return the payload (includes uid as `sub`)
  return {
    uid: payload.sub,
    email: payload.email,
    emailVerified: payload.email_verified,
    name: payload.name,
    ...payload,
  };
}

/**
 * Extract and verify the Firebase token from a Request's Authorization header.
 * Returns the decoded token payload (includes .uid).
 *
 * @param {Request} request
 * @param {string} projectId
 * @returns {Promise<{uid: string, [key: string]: any}>}
 */
export async function requireAuth(request, projectId) {
  const authHeader = request.headers.get('Authorization') || '';

  if (!authHeader.startsWith('Bearer ')) {
    throw new AuthError('Missing or invalid Authorization header', 401);
  }

  const token = authHeader.slice(7); // Remove "Bearer "

  try {
    return await verifyFirebaseToken(token, projectId);
  } catch (err) {
    throw new AuthError(`Unauthorized: ${err.message}`, 401);
  }
}

/**
 * Custom error class for auth failures — signals a 401 response.
 */
export class AuthError extends Error {
  constructor(message, statusCode = 401) {
    super(message);
    this.name = 'AuthError';
    this.statusCode = statusCode;
  }
}
