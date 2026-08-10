const https = require('https');

const secretKey = 'FLWSECK-cf4c9e59021f2fcae57bd9398a17574d-19fdeda81acvt-X';

const options = {
  hostname: 'api.flutterwave.com',
  port: 443,
  path: '/v3/transactions',
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
      console.log("=== FLUTTERWAVE RECENT TRANSACTIONS ===");
      console.log("Status:", parsed.status);
      console.log("Message:", parsed.message);
      if (parsed.data && Array.isArray(parsed.data)) {
        console.log(`Found ${parsed.data.length} transactions:`);
        parsed.data.slice(0, 10).forEach((tx, idx) => {
          console.log(`\n[${idx + 1}] ID: ${tx.id} | Ref: ${tx.tx_ref}`);
          console.log(`    Amount: ${tx.currency} ${tx.amount} (Charged: ${tx.charged_amount})`);
          console.log(`    Customer: ${tx.customer ? tx.customer.name + ' (' + tx.customer.email + ')' : 'N/A'}`);
          console.log(`    Status: ${tx.status} | Created: ${tx.created_at}`);
          console.log(`    Payment Type: ${tx.payment_type}`);
        });
      } else {
        console.log("Data payload:", parsed);
      }
    } catch (e) {
      console.error("Parse Error:", e.message, data);
    }
  });
});

req.on('error', (e) => {
  console.error("HTTP Request Error:", e);
});

req.end();
