const express = require('express');
const router = express.Router();
const bankController = require('../controllers/bankController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/resolve', requireAuth, bankController.resolveBank);

module.exports = router;
