const axios = require('axios');
const dotenv = require('dotenv');
dotenv.config();

async function testFlutterwave() {
  try {
    const res = await axios.post('https://api.flutterwave.com/v3/accounts/resolve', {
      account_number: '9038134862',
      account_bank: '100033'
    }, {
      headers: {
        Authorization: `Bearer ${process.env.FLUTTERWAVE_SECRET_KEY}`
      }
    });
    console.log('Flutterwave Response:', res.data);
  } catch (err) {
    console.error('Flutterwave Error:', err.response ? err.response.data : err.message);
  }
}

async function testOneSignal() {
  try {
    const payload = {
      app_id: process.env.ONESIGNAL_APP_ID,
      target_channel: 'push',
      include_aliases: {
        external_id: ['test_user', 'izuobagoodness@gmail.com', 'david@gmail.com']
      },
      headings: { en: 'Test Push Notification' },
      contents: { en: 'This is a test notification from the backend script.' }
    };
    const res = await axios.post('https://onesignal.com/api/v1/notifications', payload, {
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Basic ${process.env.ONESIGNAL_REST_API_KEY}`
      }
    });
    console.log('OneSignal Response:', res.data);
  } catch (err) {
    console.error('OneSignal Error:', err.response ? err.response.data : err.message);
  }
}

testFlutterwave();
testOneSignal();
