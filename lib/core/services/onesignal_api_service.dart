import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../features/notifications/data/notification_repository.dart';
import '../network/api_client.dart';

/// Sends push notifications exclusively through the secure Express backend.
/// The ONESIGNAL_REST_API_KEY NEVER lives in the client — it is a server-side
/// secret stored only in the backend's Vercel environment variables.
class OneSignalApiService {
  /// Saves a notification to Firestore and sends the push via the secure backend.
  static Future<void> sendNotification({
    required List<String> receiverUids,
    required String heading,
    required String content,
    Map<String, dynamic>? data,
  }) async {
    // 1) Save to Firestore directly (safe — protected by Firestore rules)
    try {
      final repo = NotificationRepository();
      final type = data != null ? (data['type'] ?? 'system') : 'system';
      final targetId = data != null
          ? (data['targetId'] ?? data['conversationId'] ?? '')
          : '';

      for (final uid in receiverUids) {
        await repo.addNotification(
          uid: uid,
          title: heading,
          message: content,
          type: type.toString(),
          targetId: targetId.toString(),
        );
      }
    } catch (e) {
      // Non-fatal: in-app notification list update failure
    }

    // 2) Send Push via our secure backend — REST key stays server-side only
    try {
      await ApiClient.post('/notify/push', {
        'receiverUids': receiverUids,
        'heading': heading,
        'content': content,
        if (data != null) 'data': data,
      });
    } catch (e) {
      // Non-fatal: push notification failure must not block the app flow
    }
  }

  /// Helper to send chat message notification
  static Future<void> sendChatMessageNotification({
    required String senderName,
    required String messageText,
    required String receiverUid,
    required String conversationId,
  }) async {
    await sendNotification(
      receiverUids: [receiverUid],
      heading: 'New message from $senderName',
      content: messageText,
      data: {'type': 'chat', 'conversationId': conversationId},
    );
  }

  /// Helper to send property approval/rejection notification
  static Future<void> sendPropertyStatusNotification({
    required String propertyTitle,
    required String status,
    required String receiverUid,
  }) async {
    String content = '';
    if (status == 'approved') {
      content = '✅ Good news! "$propertyTitle" has been approved and is now live.';
    } else if (status == 'rejected') {
      content = '❌ "$propertyTitle" was rejected. Please review our guidelines.';
    } else {
      return;
    }

    await sendNotification(
      receiverUids: [receiverUid],
      heading: 'Property Update',
      content: content,
      data: {'type': 'property_status'},
    );
  }

  /// Helper to send notification to all admins
  static Future<void> notifyAllAdmins({
    required String heading,
    required String content,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (snapshot.docs.isEmpty) return;

      final adminUids = snapshot.docs.map((doc) => doc.id).toList();

      await sendNotification(
        receiverUids: adminUids,
        heading: heading,
        content: content,
        data: {'type': 'admin_alert'},
      );
    } catch (e) {
      // Non-fatal
    }
  }
}


