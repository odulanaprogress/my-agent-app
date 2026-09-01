const express = require('express');
const router = express.Router();
const { getUploadSignature, getSignedDeliveryUrl } = require('../controllers/uploadController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/cloudinary-signature', requireAuth, getUploadSignature);
router.get('/cloudinary-signed-url', requireAuth, getSignedDeliveryUrl);

module.exports = router;
