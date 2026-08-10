const https = require('https');

const secretKey = 'FLWSECK-cf4c9e59021f2fcae57bd9398a17574d-19fdeda81acvt-X';

// Try a larger amount - Flutterwave has a minimum transfer limit
function testTransfer(accountNumber, bankCode, amount) {
  const postData = JSON.stringify({
    account_bank: bankCode,
    account_number: accountNumber,
    amount: amount,
    currency: 'NGN',
    debit_currency: 'NGN',
    narrative: 'AGENT Escrow Rent Payout Test',
    reference: `FLW-PAYOUT-TEST-${Date.now()}`
  });

  const options = {
    hostname: 'api.flutterwave.com',
    port: 443,
    path: '/v3/transfers',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${secretKey}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  console.log(`Testing transfer: ₦${amount} to ${bankCode} account ${accountNumber}`);

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      console.log('HTTP Status:', res.statusCode);
      console.log('Response:', data);
    });
  });

  req.on('error', (e) => console.error('Error:', e.message));
  req.write(postData);
  req.end();
}

// Test 1: GTBank with ₦500 (minimum threshold)
testTransfer('0441674660', '058', 500);
