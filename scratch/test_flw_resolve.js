const https = require('https');

const secretKey = 'FLWSECK-cf4c9e59021f2fcae57bd9398a17574d-19fdeda81acvt-X';

function resolveAccount(accountNumber, bankCode, bankName) {
  const postData = JSON.stringify({
    account_number: accountNumber,
    account_bank: bankCode
  });

  const options = {
    hostname: 'api.flutterwave.com',
    port: 443,
    path: '/v3/accounts/resolve',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${secretKey}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      console.log(`\n=== ACCOUNT RESOLVE FOR ${bankName} (${bankCode}) ===`);
      console.log(data);
    });
  });

  req.on('error', (e) => {
    console.error('Request Error:', e);
  });

  req.write(postData);
  req.end();
}

// Test GTBank (058)
resolveAccount('0123456789', '058', 'GTBank');
// Test OPay (100004)
resolveAccount('8123456789', '100004', 'OPay');
// Test Kuda (090267)
resolveAccount('2000000001', '090267', 'Kuda');
