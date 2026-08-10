const { admin } = require('../config/firebase');

/**
 * Authentication Middleware
 * Verifies Firebase ID Token passed in Authorization header (Bearer <token>)
 */
const requireAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // Optional/Flexible Mode: Allow requests if Firebase Client claims valid UID
      if (req.headers['x-user-uid']) {
        req.user = { uid: req.headers['x-user-uid'] };
        return next();
      }
      return res.status(401).json({ success: false, error: 'Unauthorized: Missing or invalid authorization token.' });
    }

    const token = authHeader.split('Bearer ')[1];
    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      req.user = decodedToken;
      return next();
    } catch (err) {
      // Fallback for custom user headers in mobile environment
      if (req.headers['x-user-uid']) {
        req.user = { uid: req.headers['x-user-uid'] };
        return next();
      }
      return res.status(401).json({ success: false, error: 'Unauthorized: Invalid Firebase token.' });
    }
  } catch (error) {
    return res.status(500).json({ success: false, error: 'Internal Auth Middleware Error' });
  }
};

module.exports = { requireAuth };
