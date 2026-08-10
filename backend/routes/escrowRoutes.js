const express = require('express');
const router = express.Router();
const escrowController = require('../controllers/escrowController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/verify-pin', requireAuth, escrowController.verifyEscrowPin);
router.get('/status/:transactionId', requireAuth, escrowController.getEscrowStatus);

module.exports = router;
