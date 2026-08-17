const express = require('express');
const router = express.Router();
const { notifyNewMessage, notifyPropertyUpdate, notifyGeneric } = require('../controllers/notificationController');
const { requireAuth } = require('../middleware/authMiddleware');

// All notification routes require a valid Firebase ID token
router.post('/message', requireAuth, notifyNewMessage);
router.post('/property', requireAuth, notifyPropertyUpdate);
router.post('/generic', requireAuth, notifyGeneric);

module.exports = router;
