const { admin } = require('../config/firebase');
const crypto = require('crypto');

/**
 * Authentication Middleware
 *
 * Verifies Firebase ID Token from Authorization: Bearer <token> header.
 * Rejects ALL requests without a valid token — no fallback, no trust of
 * client-supplied headers like x-user-uid.
 *
 * Sets req.user to the decoded Firebase token payload.
 * Use req.user.uid as the source of truth for the caller's identity.
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

    const token = authHeader.split('Bearer ')[1];

    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      req.user = decodedToken; // trusted: req.user.uid is verified
      return next();
    } catch (err) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Invalid or expired Firebase token.',
      });
    }
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Internal authentication error.',
    });
  }
};

module.exports = { requireAuth };
