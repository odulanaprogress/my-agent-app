const { db } = require('../config/firebase');
const { sendPushNotification } = require('../services/onesignalService');

/**
 * POST /api/notify/message
 * Called by Flutter after a chat message is saved to Firestore.
 * Sends a push notification to the receiver.
 *
 * Body: { conversationId, receiverId, senderName, messageType }
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

    // Trim preview for privacy (don't expose full message in push)
    if (notificationText.length > 80) {
      notificationText = notificationText.substring(0, 77) + '...';
    }

    await sendPushNotification({
      userId: receiverId,
      title: `New message from ${senderName || 'Someone'}`,
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
 * Called internally (or by admin flow) when a property approval status changes.
 * Sends a push notification to the property owner.
 *
 * Body: { propertyId, ownerId, propertyTitle, approvalStatus }
 * Auth: Required (Firebase ID token — admin only in practice)
 */
const notifyPropertyUpdate = async (req, res, next) => {
  try {
    const { propertyId, ownerId, propertyTitle, approvalStatus } = req.body;

    if (!propertyId || !ownerId || !approvalStatus) {
      return res.status(400).json({ success: false, error: 'Missing propertyId, ownerId, or approvalStatus' });
    }

    const title = propertyTitle || 'Your property';
    let message;

    if (approvalStatus === 'approved') {
      message = `✅ "${title}" has been approved and is now live.`;
    } else if (approvalStatus === 'rejected') {
      message = `❌ "${title}" was not approved. Please review our guidelines and resubmit.`;
    } else {
      return res.status(400).json({ success: false, error: `Unrecognised approvalStatus: ${approvalStatus}` });
    }

    await sendPushNotification({
      userId: ownerId,
      title: 'Property Update',
      message,
      data: { type: 'property_status', propertyId },
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/notify/generic
 * General-purpose server-triggered push notification.
 * Only callable by verified users — body must include target userId.
 *
 * Body: { userId, title, message, data }
 * Auth: Required
 */
const notifyGeneric = async (req, res, next) => {
  try {
    const { userId, title, message, data = {} } = req.body;

    if (!userId || !title || !message) {
      return res.status(400).json({ success: false, error: 'Missing userId, title, or message' });
    }

    await sendPushNotification({ userId, title, message, data });

    return res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
};

module.exports = { notifyNewMessage, notifyPropertyUpdate, notifyGeneric };
