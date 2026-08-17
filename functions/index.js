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
    // 1. Verify Secret Hash using constant-time comparison (prevents timing attacks)
    const crypto = require("crypto");
    const secretHash = process.env.FLUTTERWAVE_SECRET_HASH || "";
    const signature = req.headers["verif-hash"] || "";

    if (!secretHash) {
      console.error("FLUTTERWAVE_SECRET_HASH is not configured.");
      return res.status(500).send("Server misconfiguration");
    }

    const a = Buffer.from(signature);
    const b = Buffer.from(secretHash);
    const valid = a.length === b.length && crypto.timingSafeEqual(a, b);

    if (!valid) {
      console.warn("Unauthorized webhook request: signature mismatch");
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

      // Main transaction doc — NO PINs stored here
      const updateData = {
        flutterwaveTxId: flwTxId,
        amount: amountPaid,
        currency: currency,
        status: "held",
        commissionPercent: commissionPercent,
        commissionAmount: commissionAmount,
        netPayoutAmount: netPayoutAmount,
        tenantPinVerified: false,
        landlordPinVerified: false,
        possessionConfirmed: false,
        landlordPaidOut: false,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const batch = admin.firestore().batch();

      if (docSnap.exists) {
        batch.update(txRefDoc, updateData);
      } else {
        batch.set(txRefDoc, {
          id: txRef,
          ...updateData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Store PINs in private subcollections — only owner can read their own
      if (docSnap.exists && docSnap.data().tenantId) {
        batch.set(txRefDoc.collection("pins").doc(docSnap.data().tenantId), {
          pin: tenantPin, role: "tenant",
        });
      }
      if (docSnap.exists && docSnap.data().landlordId) {
        batch.set(txRefDoc.collection("pins").doc(docSnap.data().landlordId), {
          pin: landlordPin, role: "landlord",
        });
      }

      await batch.commit();

      // Safe log — correlation ID only, NO PIN values
      console.log(`Escrow established for txRef=${txRef} flwTxId=${flwTxId}`);
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

  // ── Phase 1: Verify PIN inside Firestore transaction (atomic, no side effects) ──
  let txData = null;
  let bothVerified = false;
  let tenantPinVerified = false;
  let landlordPinVerified = false;

  await admin.firestore().runTransaction(async (t) => {
    const docSnap = await t.get(txRef);
    if (!docSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Transaction not found.");
    }

    const tx = docSnap.data();

    // Guard: prevent re-processing an already-paid-out transaction
    if (tx.landlordPaidOut) {
      throw new functions.https.HttpsError("already-exists", "Payout already completed for this transaction.");
    }

    // Verify role authorization
    if (role === "tenant" && tx.tenantId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Unauthorized tenant.");
    }
    if (role === "landlord" && tx.landlordId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Unauthorized landlord.");
    }

    tenantPinVerified = tx.tenantPinVerified || false;
    landlordPinVerified = tx.landlordPinVerified || false;

    // Fetch PIN from secure subcollection — NOT from main doc
    const counterpartyId = role === "tenant" ? tx.landlordId : tx.tenantId;
    const pinDoc = await t.get(txRef.collection("pins").doc(counterpartyId));
    const expectedPin = pinDoc.exists ? pinDoc.data().pin : null;

    if (!expectedPin || pin.trim() !== expectedPin) {
      throw new functions.https.HttpsError("invalid-argument",
        role === "tenant" ? "Incorrect Landlord Handover PIN." : "Incorrect Tenant Key Receipt PIN."
      );
    }

    if (role === "tenant") tenantPinVerified = true;
    if (role === "landlord") landlordPinVerified = true;

    bothVerified = tenantPinVerified && landlordPinVerified;

    const updates = {
      tenantPinVerified,
      landlordPinVerified,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (bothVerified) {
      updates.possessionConfirmed = true;
      updates.possessionConfirmedAt = admin.firestore.FieldValue.serverTimestamp();
      // Mark as "payout_pending" — payout happens AFTER the transaction commits
      updates.status = "payout_pending";
    }

    t.update(txRef, updates);
    txData = tx; // capture for use outside transaction
  });

  // ── Phase 2: Execute payout OUTSIDE the transaction (prevents double-payout on retry) ──
  if (bothVerified && txData && !txData.landlordPaidOut) {
    try {
      const secretKey = process.env.FLUTTERWAVE_SECRET_KEY;
      const landlordDoc = await admin.firestore().collection("users").doc(txData.landlordId).get();
      const landlordData = landlordDoc.data() || {};

      const bankCode = landlordData.bankCode || txData.landlordBankCode;
      const accountNumber = landlordData.accountNumber || txData.landlordAccountNumber;
      const netPayoutAmount = txData.netPayoutAmount || Math.round((txData.amount || 0) * 0.95);

      // Idempotency key — prevents duplicate transfer if function retries
      const idempotencyRef = `PAYOUT-${transactionId}`;

      if (accountNumber && bankCode) {
        const payoutRes = await axios.post(
          "https://api.flutterwave.com/v3/transfers",
          {
            account_bank: bankCode,
            account_number: accountNumber,
            amount: netPayoutAmount,
            narration: `Agent Escrow Payout - ${transactionId}`,
            currency: txData.currency || "NGN",
            reference: idempotencyRef,
          },
          { headers: { Authorization: `Bearer ${secretKey}` } }
        );

        const payoutSucceeded = payoutRes.data && payoutRes.data.status === "success";
        await txRef.update({
          status: payoutSucceeded ? "released" : "payout_failed",
          landlordPaidOut: payoutSucceeded,
          payoutRef: payoutSucceeded && payoutRes.data.data ? payoutRes.data.data.id : null,
          payoutAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Safe log — no amounts, no account numbers
        console.log(`Payout ${payoutSucceeded ? "succeeded" : "failed"} for txId=${transactionId}`);
      } else {
        // Bank details missing — mark released, admin must disburse manually
        console.warn(`Landlord bank details missing for txId=${transactionId}. Marked as released, manual payout required.`);
        await txRef.update({ status: "released" });
      }
    } catch (payoutError) {
      // Log error reference only — no sensitive payload
      console.error(`Payout error for txId=${transactionId}:`, payoutError.code || payoutError.message);
      await txRef.update({ status: "payout_failed", payoutError: payoutError.code || "unknown" });
    }
  }

  return {
    success: true,
    tenantPinVerified,
    landlordPinVerified,
    bothVerified,
  };
});

