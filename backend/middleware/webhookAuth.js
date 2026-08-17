const crypto = require('crypto');

/**
 * Webhook Signature Middleware
 *
 * Verifies Flutterwave 'verif-hash' header matches FLUTTERWAVE_SECRET_HASH
 * using constant-time comparison (crypto.timingSafeEqual) to prevent
 * timing-based side-channel attacks.
 */
const verifyWebhookSignature = (req, res, next) => {
  const secretHash = process.env.FLUTTERWAVE_SECRET_HASH || '';
  const signature = req.headers['verif-hash'] || '';

  if (!secretHash) {
    console.error('FLUTTERWAVE_SECRET_HASH environment variable is not set.');
    return res.status(500).json({ success: false, error: 'Server misconfiguration' });
  }

  try {
    const a = Buffer.from(signature);
    const b = Buffer.from(secretHash);

    // Buffers must be same length for timingSafeEqual — if lengths differ, reject immediately
    const valid = a.length === b.length && crypto.timingSafeEqual(a, b);

    if (!valid) {
      console.warn('⚠️ Webhook signature mismatch — unauthorized request.');
      return res.status(401).json({ success: false, error: 'Unauthorized: Invalid webhook signature' });
    }

    next();
  } catch (err) {
    console.error('Webhook signature verification error:', err);
    return res.status(401).json({ success: false, error: 'Unauthorized: Signature verification failed' });
  }
};

module.exports = { verifyWebhookSignature };
