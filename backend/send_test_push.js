const { admin } = require('./config/firebase.js');
const axios = require('axios');
const dotenv = require('dotenv');
dotenv.config();

const emails = ['izuobagoodness@gmail.com', 'david@gmail.com'];

async function run() {
  const uids = [];
  for (const email of emails) {
    try {
      const userRecord = await admin.auth().getUserByEmail(email);
      uids.push(userRecord.uid);
      console.log(`Found UID for ${email}: ${userRecord.uid}`);
    } catch (err) {
      console.error(`Error fetching user for ${email}:`, err.message);
    }
  }

  if (uids.length > 0) {
    console.log(`Sending OneSignal push to UIDs: ${uids.join(', ')}`);
    const payload = {
      app_id: process.env.ONESIGNAL_APP_ID,
      target_channel: 'push',
      include_aliases: {
        external_id: uids
      },
      headings: { en: 'Test Push Notification' },
      contents: { en: 'Hello from the testing script.' }
    };
    try {
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
  } else {
    console.log('No UIDs found to send push.');
  }
}

run();
