const { db } = require('../config/firebase');
const { sendPushNotification } = require('../services/onesignalService');
const emailService = require('../services/emailService');

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

    // 3. Dispatch Email notification to receiver if email is found
    try {
      const receiverSnap = await db.collection('users').doc(receiverId).get();
      if (receiverSnap.exists) {
        const receiverData = receiverSnap.data();
        const receiverEmail = receiverData?.email;
        const receiverName = receiverData?.fullName || receiverData?.name || 'User';

        if (receiverEmail) {
          emailService.sendChatMessageEmail({
            to: receiverEmail,
            receiverName,
            senderName: senderName || 'Someone',
            messagePreview: notificationText,
            conversationId,
          }).catch(err => console.error('Chat message email dispatch failed:', err.message));
        }
      }
    } catch (emailErr) {
      console.warn('Could not fetch receiver email for chat notification:', emailErr.message);
    }

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

/**
 * POST /api/notify/login-alert
 * Dispatches a branded security alert email to the user when they sign in.
 *
 * Body: { device, location, email, name }
 * Auth: Required
 */
const notifyLoginAlert = async (req, res, next) => {
  try {
    const uid = req.user?.uid;
    const bodyEmail = req.body?.email;
    const userEmail = req.user?.email || bodyEmail;

    if (!userEmail) {
      return res.status(400).json({ success: false, error: 'User email not found' });
    }

    let userName = req.body?.name || req.user?.name;
    if (!userName && uid) {
      try {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          userName = userDoc.data()?.fullName || userDoc.data()?.name;
        }
      } catch (_) {}
    }

    const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || 'Protected';
    const device = req.body?.device || req.headers['user-agent'] || 'Web / Mobile Client';
    const location = req.body?.location;
    const loginTime = new Date().toUTCString();

    // 1. Send branded login security email asynchronously
    emailService.sendLoginAlert({
      to: userEmail,
      name: userName || 'Valued User',
      time: loginTime,
      ip,
      device,
      location,
    }).catch(err => console.error('Login alert email error:', err.message));

    // 2. Save in-app notification in Firestore
    if (uid) {
      await saveInAppNotification({
        userId: uid,
        title: '🔐 New Sign-in Detected',
        message: `New sign-in from ${device} at ${loginTime}`,
        type: 'security',
      });
    }

    return res.status(200).json({ success: true, message: 'Login security alert dispatched' });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/notify/welcome
 * Sends a welcome email to a newly registered user and alerts administrators.
 *
 * Body: { fullName, role }
 * Auth: Required
 */
const notifyWelcome = async (req, res, next) => {
  try {
    const uid = req.user?.uid;
    const userEmail = req.user?.email || req.body?.email;
    const fullName = req.body?.fullName || req.user?.name;
    const role = req.body?.role || 'tenant';

    if (!userEmail) {
      return res.status(400).json({ success: false, error: 'User email not found' });
    }

    // 1. Send welcome email and alert admin
    emailService.sendWelcomeEmail({
      to: userEmail,
      name: fullName || 'Friend',
      role,
    }).catch(err => console.error('Welcome email dispatch error:', err.message));

    // 2. Save in-app notification
    if (uid) {
      await saveInAppNotification({
        userId: uid,
        title: '🎉 Welcome to Agent!',
        message: 'Your account is now ready. Explore verified properties with secure escrow protection.',
        type: 'system',
      });
    }

    return res.status(200).json({ success: true, message: 'Welcome email sent' });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/notify/enquiry
 * Dispatches an enquiry / tour notification email to the property owner
 * and alerts Customer Care / Admins.
 *
 * Body: { propertyId, propertyTitle, message, tourDate, tourTime, landlordId }
 * Auth: Required
 */
const notifyPropertyEnquiry = async (req, res, next) => {
  try {
    const prospectUid = req.user?.uid;
    const { propertyId, propertyTitle, message, tourDate, tourTime, landlordId: inputLandlordId } = req.body;

    if (!propertyId) {
      return res.status(400).json({ success: false, error: 'Missing propertyId' });
    }

    // 1. Fetch prospect info from Firestore
    let prospectName = req.user?.name || 'Interested Client';
    let prospectEmail = req.user?.email || '';
    let prospectPhone = 'N/A';

    if (prospectUid) {
      try {
        const pSnap = await db.collection('users').doc(prospectUid).get();
        if (pSnap.exists) {
          const pData = pSnap.data();
          prospectName = pData?.fullName || pData?.name || prospectName;
          prospectEmail = pData?.email || prospectEmail;
          prospectPhone = pData?.phoneNumber || pData?.phone || 'N/A';
        }
      } catch (_) {}
    }

    // 2. Fetch property & owner info
    let targetLandlordId = inputLandlordId;
    let finalPropertyTitle = propertyTitle || 'Property Listing';
    try {
      const propSnap = await db.collection('properties').doc(propertyId).get();
      if (propSnap.exists) {
        const propData = propSnap.data();
        targetLandlordId = targetLandlordId || propData?.landlordId || propData?.ownerId;
        finalPropertyTitle = propData?.title || finalPropertyTitle;
      }
    } catch (_) {}

    // 3. Fetch landlord contact details
    let ownerEmail = null;
    let ownerName = 'Property Owner';
    if (targetLandlordId) {
      try {
        const ownerSnap = await db.collection('users').doc(targetLandlordId).get();
        if (ownerSnap.exists) {
          const oData = ownerSnap.data();
          ownerEmail = oData?.email;
          ownerName = oData?.fullName || oData?.name || 'Property Owner';
        }
      } catch (_) {}
    }

    // Fallback to customer care if landlord email is missing
    const destinationEmail = ownerEmail || 'customercare@agentmobiletech.com';

    // 4. Dispatch Email to Owner & Admins
    emailService.sendPropertyEnquiryEmail({
      to: destinationEmail,
      ownerName,
      prospectName,
      prospectEmail: prospectEmail || 'Via Agent In-App Chat',
      prospectPhone,
      propertyTitle: finalPropertyTitle,
      message: message || 'Hello, I am interested in this property and would like more details / to arrange an inspection.',
      tourDate,
      tourTime,
    }).catch(err => console.error('Enquiry email dispatch error:', err.message));

    // 5. In-app notification to landlord
    if (targetLandlordId && targetLandlordId !== prospectUid) {
      await saveInAppNotification({
        userId: targetLandlordId,
        title: `🔑 New Enquiry: "${finalPropertyTitle}"`,
        message: `${prospectName} is interested in your property. Check your messages to reply.`,
        type: 'property_inquiry',
        targetId: propertyId,
      });
    }

    return res.status(200).json({ success: true, message: 'Enquiry email dispatched' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  notifyNewMessage,
  notifyPropertyUpdate,
  notifyGeneric,
  notifyLoginAlert,
  notifyWelcome,
  notifyPropertyEnquiry,
};

