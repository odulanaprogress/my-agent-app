const express = require('express');
const router = express.Router();
const webhookController = require('../controllers/webhookController');
const { verifyWebhookSignature } = require('../middleware/webhookAuth');

router.post('/flutterwave', verifyWebhookSignature, webhookController.handleWebhook);

module.exports = router;
