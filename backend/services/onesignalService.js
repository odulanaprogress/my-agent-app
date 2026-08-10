const axios = require('axios');

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

/**
 * Send push notification to target user via OneSignal API
 */
const sendPushNotification = async ({ userId, title, message, data = {} }) => {
  if (!userId || !ONESIGNAL_REST_API_KEY) return null;

  try {
    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: 'push',
      include_aliases: {
        external_id: [userId],
      },
      headings: { en: title },
      contents: { en: message },
      data: data,
    };

    const response = await axios.post('https://onesignal.com/api/v1/notifications', payload, {
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
    });

    console.log(`📱 Push notification sent to user ${userId}:`, response.data);
    return response.data;
  } catch (error) {
    console.error('❌ Error sending OneSignal push:', error.response ? error.response.data : error.message);
    return null;
  }
};

module.exports = { sendPushNotification };
