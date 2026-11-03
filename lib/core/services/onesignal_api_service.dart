import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../network/api_client.dart';

/// Sends push notifications to recipients via backend with direct OneSignal fallback.
class OneSignalApiService {
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '6b319216-e8b1-4cc4-826a-ec7c482ff9c4',
  );
  static const String restApiKey = String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
    defaultValue: '',
  );

  /// Saves a notification to Firestore and delivers push notification via OneSignal.
  static Future<void> sendNotification({
    required List<String> receiverUids,
    required String heading,
    required String content,
    Map<String, dynamic>? data,
  }) async {
    if (receiverUids.isEmpty) return;

    // 1) Save to Firestore directly for in-app Notifications Screen
    try {
      final repo = NotificationRepository();
      final type = data != null ? (data['type'] ?? 'system') : 'system';
      final targetId = data != null
          ? (data['targetId'] ?? data['conversationId'] ?? data['callId'] ?? '')
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
      debugPrint('[OneSignalApiService] Firestore save notification error: $e');
    }

    // 2) Send Push via secure backend, with guaranteed fallback to direct OneSignal REST API
    bool deliveredViaBackend = false;
    try {
      await ApiClient.post('/notify/push', {
        'receiverUids': receiverUids,
        'heading': heading,
        'content': content,
        'data': data ?? {},
      });
      deliveredViaBackend = true;
    } catch (e) {
      debugPrint('[OneSignalApiService] Backend push notification failed: $e. Falling back to direct OneSignal REST API.');
    }

    if (!deliveredViaBackend && restApiKey.isNotEmpty) {
      try {
        final uri = Uri.parse('https://onesignal.com/api/v1/notifications');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Key $restApiKey',
          },
          body: jsonEncode({
            'app_id': appId,
            'target_channel': 'push',
            'include_aliases': {
              'external_id': receiverUids,
            },
            'headings': {'en': heading},
            'contents': {'en': content},
            'ios_sound': 'default',
            'android_sound': 'notification',
            'data': data ?? {},
          }),
        );
        debugPrint('[OneSignalApiService] OneSignal Direct Push Result: ${response.statusCode}');
      } catch (e) {
        debugPrint('[OneSignalApiService] OneSignal direct push error: $e');
      }
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
