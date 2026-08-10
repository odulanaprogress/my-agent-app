/**
 * Webhook Signature Middleware
 * Verifies Flutterwave 'verif-hash' header matches FLUTTERWAVE_SECRET_HASH
 */
const verifyWebhookSignature = (req, res, next) => {
  const secretHash = process.env.FLUTTERWAVE_SECRET_HASH;
  const signature = req.headers['verif-hash'];

  if (!signature || signature !== secretHash) {
    console.warn('⚠️ Webhook Signature mismatch. Unauthorized webhook request.');
    return res.status(401).json({ success: false, error: 'Unauthorized: Invalid secret signature hash' });
  }

  next();
};

module.exports = { verifyWebhookSignature };
