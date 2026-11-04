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
const { requireAuth } = require('../middleware/authMiddleware');

// All notification routes require a valid Firebase ID token
router.post('/message',     requireAuth, notifyNewMessage);
router.post('/property',    requireAuth, notifyPropertyUpdate);
router.post('/generic',     requireAuth, notifyGeneric);
router.post('/push',        requireAuth, notifyGeneric); // alias used by Flutter client
router.post('/login-alert', requireAuth, notifyLoginAlert);
router.post('/welcome',     requireAuth, notifyWelcome);
router.post('/enquiry',     requireAuth, notifyPropertyEnquiry);

module.exports = router;
