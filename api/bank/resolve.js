export default async function handler(req, res) {
  // 1. Enable CORS for local testing (Vercel automatically handles this in production for same-origin)
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*'); // Or the specific origin
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  // 2. Handle OPTIONS request for CORS preflight
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // 3. Ensure it's a POST request
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed' });
  }

  // 4. Extract parameters
  const { accountNumber, bankCode } = req.body;
  if (!accountNumber || !bankCode) {
    return res.status(400).json({ success: false, error: 'Missing accountNumber or bankCode' });
  }

  const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
  if (!secretKey) {
    return res.status(500).json({ success: false, error: 'Flutterwave Secret Key is missing in Vercel Environment Variables.' });
  }

  try {
    // 5. Forward request to Flutterwave
    const response = await fetch('https://api.flutterwave.com/v3/accounts/resolve', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${secretKey.trim()}`
      },
      body: JSON.stringify({
        account_number: accountNumber.trim(),
        account_bank: bankCode.trim()
      })
    });

    const body = await response.json();

    if (response.ok && body.status === 'success') {
      return res.status(200).json({
        success: true,
        data: {
          accountName: body.data.account_name,
          accountNumber: body.data.account_number
        }
      });
    } else {
      return res.status(response.status).json({
        success: false,
        error: body.message || 'Unable to resolve bank account.'
      });
    }
  } catch (error) {
    console.error('Flutterwave resolve error:', error);
    return res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
}
