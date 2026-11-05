const express = require('express');
const router = express.Router();
const { 
  notifyNewMessage, 
  notifyPropertyUpdate, 
  notifyGeneric,
  notifyLoginAlert,
  notifyWelcome,
  notifyPropertyEnquiry,
} = require('../controllers/notificationController');
const { requireAuth, optionalAuth } = require('../middleware/authMiddleware');

// Notification routes
router.post('/message',     requireAuth, notifyNewMessage);
router.post('/property',    requireAuth, notifyPropertyUpdate);
router.post('/generic',     requireAuth, notifyGeneric);
router.post('/push',        requireAuth, notifyGeneric); // alias used by Flutter client
router.post('/login-alert', optionalAuth, notifyLoginAlert);
router.post('/welcome',     requireAuth, notifyWelcome);
router.post('/enquiry',     requireAuth, notifyPropertyEnquiry);

module.exports = router;
