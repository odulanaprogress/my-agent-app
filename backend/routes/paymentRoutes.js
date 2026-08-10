const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/initialize', requireAuth, paymentController.initializePayment);
router.get('/verify/:flwTxId', requireAuth, paymentController.verifyPayment);
router.post('/flutterwave/virtual-account', paymentController.generateVirtualAccount);

module.exports = router;

