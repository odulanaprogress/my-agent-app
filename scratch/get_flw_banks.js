const https = require('https');

const secretKey = 'FLWSECK-cf4c9e59021f2fcae57bd9398a17574d-19fdeda81acvt-X';

const options = {
  hostname: 'api.flutterwave.com',
  port: 443,
  path: '/v3/banks/NG',
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${secretKey}`,
    'Content-Type': 'application/json'
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log(`=== FLUTTERWAVE NIGERIAN BANKS (${parsed.data ? parsed.data.length : 0} banks) ===`);
      if (parsed.data && Array.isArray(parsed.data)) {
        // Log popular banks with code and name
        const popular = ['gtbank', 'access', 'zenith', 'uba', 'first bank', 'kuda', 'opay', 'palmpay', 'moniepoint', 'wema', 'fcmb'];
        parsed.data.forEach(b => {
          const lowerName = b.name.toLowerCase();
          if (popular.some(p => lowerName.includes(p))) {
            console.log(`Code: "${b.code}" | Name: "${b.name}"`);
          }
        });
      } else {
        console.log(parsed);
      }
    } catch (e) {
      console.error(e.message);
    }
  });
});

req.on('error', (e) => { console.error(e); });
req.end();
