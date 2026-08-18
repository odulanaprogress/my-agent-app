const axios = require('axios');

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

/**
 * Send push notification to target users via OneSignal API
 */
const sendPushNotification = async ({ userId, userIds, title, heading, message, content, data = {} }) => {
  const notifTitle = title || heading || 'Notification';
  const notifMessage = message || content || '';
  const targets = (userIds && Array.isArray(userIds) && userIds.length > 0)
    ? userIds
    : (userId ? [userId] : []);

  if (!targets.length || !ONESIGNAL_REST_API_KEY || !ONESIGNAL_APP_ID) {
    console.log('Push notification skipped: missing targets or OneSignal credentials');
    return null;
  }

  try {
    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: 'push',
      include_aliases: {
        external_id: targets,
      },
      headings: { en: notifTitle },
      contents: { en: notifMessage },
      ios_sound: 'default',
      android_sound: 'notification',
      data: data,
    };

    const response = await axios.post('https://onesignal.com/api/v1/notifications', payload, {
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
    });

    console.log(`📱 Push notification sent to ${targets.length} user(s):`, response.data);
    return response.data;
  } catch (error) {
    console.error('❌ Error sending OneSignal push:', error.response ? error.response.data : error.message);
    return null;
  }
};

module.exports = { sendPushNotification };

