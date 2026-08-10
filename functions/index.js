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

/**
 * Generate cryptographically secure 6-digit numerical PIN
 */
function generateSixDigitPin() {
  const crypto = require("crypto");
  return Math.floor(100000 + crypto.randomInt(900000)).toString();
}

/**
 * FLUTTERWAVE WEBHOOK ENDPOINT
 * Route: /flutterwaveWebhook
 * Listens for payment notifications from Flutterwave.
 */
exports.flutterwaveWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // 1. Verify Secret Hash Header
    const secretHash = process.env.FLUTTERWAVE_SECRET_HASH;
    const signature = req.headers["verif-hash"];

    if (!signature || signature !== secretHash) {
      console.warn("Unauthorized webhook request: Hash signature mismatch");
      return res.status(401).send("Unauthorized");
    }

    const payload = req.body;
    console.log("Received Flutterwave Webhook Event:", payload.event, payload.data ? payload.data.id : "");

    // 2. Process Successful Charge
    if (payload.event === "charge.completed" && payload.data && payload.data.status === "successful") {
      const flwTxId = payload.data.id;
      const txRef = payload.data.tx_ref;
      const amountPaid = payload.data.amount;
      const currency = payload.data.currency;

      // Double-check transaction with Flutterwave API for absolute security
      const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
      const verifyRes = await axios.get(`https://api.flutterwave.com/v3/transactions/${flwTxId}/verify`, {
        headers: { Authorization: `Bearer ${secretKey}` },
      });

      const verifiedData = verifyRes.data ? verifyRes.data.data : null;
      if (!verifiedData || verifiedData.status !== "successful" || verifiedData.amount < amountPaid) {
        console.error("Payment verification failed at Flutterwave API check:", verifiedData);
        return res.status(400).send("Verification Failed");
      }

      // Calculate Platform Commission (5%) & Net Payout (95%)
      const commissionPercent = 5;
      const commissionAmount = Math.round(amountPaid * (commissionPercent / 100));
      const netPayoutAmount = amountPaid - commissionAmount;

      // Generate 2 Unique 6-Digit PINs
      const tenantPin = generateSixDigitPin();
      const landlordPin = generateSixDigitPin();

      const txRefDoc = admin.firestore().collection("transactions").doc(txRef);
      const docSnap = await txRefDoc.get();

      const updateData = {
        flutterwaveTxId: flwTxId,
        amount: amountPaid,
        currency: currency,
        status: "held", // Money is held in Escrow
        commissionPercent: commissionPercent,
        commissionAmount: commissionAmount,
        netPayoutAmount: netPayoutAmount,
        tenantPin: tenantPin,
        landlordPin: landlordPin,
        tenantPinVerified: false,
        landlordPinVerified: false,
        possessionConfirmed: false,
        landlordPaidOut: false,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (docSnap.exists) {
        await txRefDoc.update(updateData);
      } else {
        await txRefDoc.set({
          id: txRef,
          ...updateData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      console.log(`Escrow established for transaction ${txRef}: Tenant PIN: ${tenantPin}, Landlord PIN: ${landlordPin}`);
    }

    return res.status(200).send("Webhook Processed Successfully");
  } catch (err) {
    console.error("Error processing Flutterwave Webhook:", err);
    return res.status(500).send("Server Error");
  }
});

/**
 * RESOLVE LANDLORD BANK ACCOUNT NAME
 * Takes account_number and account_bank, calls Flutterwave API to resolve owner name.
 */
exports.resolveBankDetails = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
  }

  const { accountNumber, bankCode } = data;
  if (!accountNumber || !bankCode) {
    throw new functions.https.HttpsError("invalid-argument", "Missing accountNumber or bankCode.");
  }

  try {
    const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
    const response = await axios.post(
      "https://api.flutterwave.com/v3/accounts/resolve",
      { account_number: accountNumber, account_bank: bankCode },
      { headers: { Authorization: `Bearer ${secretKey}` } }
    );

    if (response.data && response.data.status === "success") {
      return {
        success: true,
        accountName: response.data.data.account_name,
        accountNumber: response.data.data.account_number,
      };
    } else {
      return { success: false, message: response.data.message || "Could not resolve bank account." };
    }
  } catch (err) {
    console.error("Bank Account Resolution Error:", err.response ? err.response.data : err.message);
    throw new functions.https.HttpsError("internal", err.response?.data?.message || "Failed to resolve account.");
  }
});

/**
 * VERIFY ESCROW PIN AND TRIGGER PAYOUT
 * Called when Tenant or Landlord submits the 6-digit PIN.
 */
exports.verifyEscrowPin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
  }

  const { transactionId, pin, role } = data;
  const uid = context.auth.uid;

  if (!transactionId || !pin || !role) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required arguments.");
  }

  const txRef = admin.firestore().collection("transactions").doc(transactionId);

  return await admin.firestore().runTransaction(async (t) => {
    const docSnap = await t.get(txRef);
    if (!docSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Transaction not found.");
    }

    const tx = docSnap.data();

    // Verify role authorization
    if (role === "tenant" && tx.tenantId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Unauthorized tenant.");
    }
    if (role === "landlord" && tx.landlordId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Unauthorized landlord.");
    }

    let tenantPinVerified = tx.tenantPinVerified || false;
    let landlordPinVerified = tx.landlordPinVerified || false;

    // Check PIN match
    // Tenant enters Landlord's PIN
    if (role === "tenant") {
      if (tx.landlordPin !== pin.trim()) {
        throw new functions.https.HttpsError("invalid-argument", "Incorrect Landlord Handover PIN.");
      }
      tenantPinVerified = true;
    }

    // Landlord enters Tenant's PIN
    if (role === "landlord") {
      if (tx.tenantPin !== pin.trim()) {
        throw new functions.https.HttpsError("invalid-argument", "Incorrect Tenant Key Receipt PIN.");
      }
      landlordPinVerified = true;
    }

    const bothVerified = tenantPinVerified && landlordPinVerified;
    const updates = {
      tenantPinVerified: tenantPinVerified,
      landlordPinVerified: landlordPinVerified,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (bothVerified) {
      updates.possessionConfirmed = true;
      updates.possessionConfirmedAt = admin.firestore.FieldValue.serverTimestamp();
      updates.status = "releasing"; // Transitioning state
    }

    t.update(txRef, updates);

    // If both PINs verified, execute automated payout to landlord bank account
    if (bothVerified && !tx.landlordPaidOut) {
      try {
        const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
        const landlordDoc = await admin.firestore().collection("users").doc(tx.landlordId).get();
        const landlordData = landlordDoc.data() || {};
        
        const bankCode = landlordData.bankCode || tx.landlordBankCode || "044"; // default access bank or saved code
        const accountNumber = landlordData.accountNumber || tx.landlordAccountNumber;
        const netPayoutAmount = tx.netPayoutAmount || Math.round((tx.amount || 0) * 0.95);

        if (accountNumber && bankCode) {
          const payoutRes = await axios.post(
            "https://api.flutterwave.com/v3/transfers",
            {
              account_bank: bankCode,
              account_number: accountNumber,
              amount: netPayoutAmount,
              narration: `Agent Escrow Payout - Property ${tx.propertyId || ""}`,
              currency: tx.currency || "NGN",
              reference: `PAYOUT-${tx.id}-${Date.now()}`,
            },
            { headers: { Authorization: `Bearer ${secretKey}` } }
          );

          if (payoutRes.data && payoutRes.data.status === "success") {
            t.update(txRef, {
              status: "released",
              landlordPaidOut: true,
              payoutRef: payoutRes.data.data ? payoutRes.data.data.id : null,
              payoutAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        } else {
          console.warn("Landlord bank details missing for automated payout. Marked as pending payout release.");
          t.update(txRef, { status: "released" });
        }
      } catch (payoutError) {
        console.error("Flutterwave Payout execution error:", payoutError.response ? payoutError.response.data : payoutError.message);
        t.update(txRef, { status: "released", payoutError: payoutError.message });
      }
    }

    return {
      success: true,
      tenantPinVerified,
      landlordPinVerified,
      bothVerified,
    };
  });
});

