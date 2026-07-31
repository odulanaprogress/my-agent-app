require("dotenv").config();
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// Load environment variables
const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

/**
 * Triggered when a new document is added to the "messages" subcollection.
 * Path: conversations/{conversationId}/messages/{messageId}
 */
exports.onNewChatMessage = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const senderId = data.senderId;
    const receiverId = data.receiverId;
    const message = data.message;
    const messageType = data.messageType || "text";

    // Don't send push if missing receiver
    if (!receiverId || !senderId) return null;

    try {
      // 1. Fetch sender details to display their name in the notification
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      let senderName = "Someone";
      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        senderName = senderData.name || senderData.fullName || "Someone";
      }

      // 2. Format the notification text
      let notificationText = message;
      if (messageType === "image") {
        notificationText = "📷 Sent an image";
      } else if (messageType === "video") {
        notificationText = "🎥 Sent a video";
      } else if (messageType === "pdf") {
        notificationText = "📄 Sent a document";
      }

      // 3. Prepare OneSignal Payload
      // Using include_external_user_ids to target the user's specific Firebase UID
      const payload = {
        app_id: ONESIGNAL_APP_ID,
        target_channel: "push",
        include_aliases: {
          external_id: [receiverId]
        },
        headings: { en: `New message from ${senderName}` },
        contents: { en: notificationText },
        // Optional: Send data to deep link into the chat
        data: {
          type: "chat",
          conversationId: context.params.conversationId,
        },
      };

      // 4. Send the POST request to OneSignal
      const response = await axios.post("https://onesignal.com/api/v1/notifications", payload, {
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
      });

      console.log("Successfully sent push notification:", response.data);
      return response.data;
    } catch (error) {
      console.error("Error sending push notification via OneSignal:", error.response ? error.response.data : error.message);
      return null;
    }
  });

/**
 * Triggered when a property is updated (e.g., approved or rejected)
 * Path: properties/{propertyId}
 */
exports.onPropertyUpdate = functions.firestore
  .document("properties/{propertyId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if approvalStatus changed
    if (beforeData.approvalStatus === afterData.approvalStatus) {
      return null;
    }

    const ownerId = afterData.ownerId;
    if (!ownerId) return null;

    const newStatus = afterData.approvalStatus; // "approved", "rejected", "pending"
    const title = afterData.title || "Your property";

    let notificationText = "";
    if (newStatus === "approved") {
      notificationText = `✅ Good news! "${title}" has been approved and is now live.`;
    } else if (newStatus === "rejected") {
      notificationText = `❌ "${title}" was rejected. Please review our guidelines.`;
    } else {
      return null;
    }

    try {
      const payload = {
        app_id: ONESIGNAL_APP_ID,
        target_channel: "push",
        include_aliases: {
          external_id: [ownerId]
        },
        headings: { en: "Property Update" },
        contents: { en: notificationText },
      };

      const response = await axios.post("https://onesignal.com/api/v1/notifications", payload, {
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
      });

      console.log(`Successfully sent property ${newStatus} notification:`, response.data);
      return response.data;
    } catch (error) {
      console.error("Error sending property update notification:", error.response ? error.response.data : error.message);
      return null;
    }
  });

/**
 * Triggered when a new notification is added to the user's notifications collection
 * Path: notifications/{userId}/userNotifications/{notificationId}
 */
exports.onNotificationCreated = functions.firestore
  .document("notifications/{userId}/userNotifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const userId = context.params.userId;
    const title = data.title || "Notification";
    const message = data.message || "";
    const type = data.type || "system";
    const targetId = data.targetId || "";

    // Skip chat and property updates to prevent duplicate push notifications,
    // as they are already handled by onNewChatMessage and onPropertyUpdate.
    if (type === "chat" || type === "property_status") {
      return null;
    }

    try {
      const payload = {
        app_id: ONESIGNAL_APP_ID,
        target_channel: "push",
        include_aliases: {
          external_id: [userId]
        },
        headings: { en: title },
        contents: { en: message },
        data: {
          type: type,
          targetId: targetId
        }
      };

      const response = await axios.post("https://onesignal.com/api/v1/notifications", payload, {
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
      });

      console.log(`Successfully sent push notification to ${userId}:`, response.data);
      return response.data;
    } catch (error) {
      console.error("Error sending push notification via OneSignal:", error.response ? error.response.data : error.message);
      return null;
    }
  });
