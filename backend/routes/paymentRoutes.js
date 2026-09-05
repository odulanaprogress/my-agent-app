const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/initialize', requireAuth, paymentController.initializePayment);
router.get('/verify/:flwTxId', requireAuth, paymentController.verifyPayment);
router.post('/verify-by-ref', requireAuth, paymentController.verifyPaymentByRef);
router.post('/flutterwave/virtual-account', requireAuth, paymentController.generateVirtualAccount);
router.get('/flutterwave/fee', paymentController.getFlutterwaveFee);
router.post('/withdraw', requireAuth, paymentController.requestWithdrawal);

module.exports = router;
