const axios = require('axios');
const dotenv = require('dotenv');
dotenv.config();

async function broadcastPush() {
  const payload = {
    app_id: process.env.ONESIGNAL_APP_ID,
    included_segments: ['Total Subscriptions'], // Target everyone
    headings: { en: 'Hello Agent App!' },
    contents: { en: 'This is a broadcast test push notification.' }
  };
  try {
    const res = await axios.post('https://onesignal.com/api/v1/notifications', payload, {
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Basic ${process.env.ONESIGNAL_REST_API_KEY}`
      }
    });
    console.log('OneSignal Broadcast Response:', res.data);
  } catch (err) {
    console.error('OneSignal Error:', err.response ? err.response.data : err.message);
  }
}

broadcastPush();
