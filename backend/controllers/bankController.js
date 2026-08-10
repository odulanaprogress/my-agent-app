const flutterwaveService = require('../services/flutterwaveService');

const resolveBank = async (req, res, next) => {
  try {
    const { accountNumber, bankCode } = req.body;
    if (!accountNumber || !bankCode) {
      return res.status(400).json({ success: false, error: 'Missing accountNumber or bankCode' });
    }

    const resolved = await flutterwaveService.resolveBankAccount({ accountNumber, bankCode });
    return res.status(200).json({
      success: true,
      data: resolved,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { resolveBank };
