const { db } = require('../config/firebase');
const { sendPushNotification } = require('../services/onesignalService');

/**
 * Helper to save in-app notification to Firestore for the user's notification screen.
 */
const saveInAppNotification = async ({ userId, title, message, type = 'system', targetId = '' }) => {
  try {
    if (!userId) return;
    await db.collection('notifications').add({
      userId,
      title,
      message,
      body: message,
      type,
      targetId,
      isRead: false,
      createdAt: new Date(),
    });
  } catch (err) {
    console.error('Failed to save in-app notification to Firestore:', err.message);
  }
};

/**
 * POST /api/notify/message
 * Called by Flutter after a chat message is saved to Firestore.
 * Sends a push notification to the receiver and records in-app notification.
 *
 * Body: { conversationId, receiverId, senderName, messageType, messagePreview }
 * Auth: Required (Firebase ID token via requireAuth middleware)
 */
const notifyNewMessage = async (req, res, next) => {
  try {
    const senderId = req.user.uid;
    const { conversationId, receiverId, senderName, messageType = 'text', messagePreview } = req.body;

    if (!receiverId || !conversationId) {
      return res.status(400).json({ success: false, error: 'Missing receiverId or conversationId' });
    }

    // Don't notify yourself
    if (receiverId === senderId) {
      return res.status(200).json({ success: true, skipped: true });
    }

    let notificationText;
    switch (messageType) {
      case 'image': notificationText = '📷 Sent an image'; break;
      case 'video': notificationText = '🎥 Sent a video'; break;
      case 'pdf':   notificationText = '📄 Sent a document'; break;
      default:      notificationText = messagePreview || 'Sent you a message';
    }

    if (notificationText.length > 80) {
      notificationText = notificationText.substring(0, 77) + '...';
    }

    const title = `New message from ${senderName || 'Someone'}`;

    // 1. Save in-app notification for notifications screen
    await saveInAppNotification({
      userId: receiverId,
      title,
      message: notificationText,
      type: 'chat',
      targetId: conversationId,
    });

    // 2. Dispatch OneSignal push
    await sendPushNotification({
      userId: receiverId,
      title,
      message: notificationText,
      data: { type: 'chat', conversationId },
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/notify/property
 * Sends a push notification to the property owner when approved/rejected.
 *
 * Body: { propertyId, ownerId, propertyTitle, approvalStatus }
 * Auth: Required
 */
const notifyPropertyUpdate = async (req, res, next) => {
  try {
    const { propertyId, ownerId, propertyTitle, approvalStatus } = req.body;

    if (!propertyId || !ownerId || !approvalStatus) {
      return res.status(400).json({ success: false, error: 'Missing propertyId, ownerId, or approvalStatus' });
    }

    const title = 'Property Update';
    let message;

    if (approvalStatus === 'approved') {
      message = `✅ "${propertyTitle || 'Your property'}" has been approved and is now live.`;
    } else if (approvalStatus === 'rejected') {
      message = `❌ "${propertyTitle || 'Your property'}" was not approved. Please review our guidelines and resubmit.`;
    } else {
      return res.status(400).json({ success: false, error: `Unrecognised approvalStatus: ${approvalStatus}` });
    }

    // 1. Save in-app notification
    await saveInAppNotification({
      userId: ownerId,
      title,
      message,
      type: 'property_status',
      targetId: propertyId,
    });

    // 2. Dispatch push
    await sendPushNotification({
      userId: ownerId,
      title,
      message,
      data: { type: 'property_status', propertyId },
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/notify/generic & /api/notify/push
 * General-purpose server-triggered push and in-app notification.
 * Accepts both single userId and array receiverUids, and both title/heading, message/content.
 *
 * Body: { userId, receiverUids, title, heading, message, content, data }
 * Auth: Required
 */
const notifyGeneric = async (req, res, next) => {
  try {
    const { userId, receiverUids, title, heading, message, content, data = {} } = req.body;

    const notifTitle = title || heading;
    const notifMessage = message || content;
    const targets = (receiverUids && Array.isArray(receiverUids) && receiverUids.length > 0)
      ? receiverUids
      : (userId ? [userId] : []);

    if (!targets.length || !notifTitle || !notifMessage) {
      return res.status(400).json({
        success: false,
        error: 'Missing recipient (userId or receiverUids), title/heading, or message/content',
      });
    }

    // 1. Save in-app notification for each target user in Firestore
    for (const targetUid of targets) {
      await saveInAppNotification({
        userId: targetUid,
        title: notifTitle,
        message: notifMessage,
        type: data.type || 'system',
        targetId: data.targetId || data.conversationId || '',
      });
    }

    // 2. Send push notifications via OneSignal
    await sendPushNotification({
      userIds: targets,
      title: notifTitle,
      message: notifMessage,
      data,
    });

    return res.status(200).json({ success: true, recipientsCount: targets.length });
  } catch (error) {
    next(error);
  }
};

module.exports = { notifyNewMessage, notifyPropertyUpdate, notifyGeneric };

