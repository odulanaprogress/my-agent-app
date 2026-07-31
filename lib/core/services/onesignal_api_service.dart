import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../features/notifications/data/notification_repository.dart';

class OneSignalApiService {
  static const String _apiUrl = 'https://onesignal.com/api/v1/notifications';

  /// Saves a notification to Firestore and securely sends the push notification.
  static Future<void> sendNotification({
    required List<String> receiverUids,
    required String heading,
    required String content,
    Map<String, dynamic>? data,
  }) async {
    // 1) Save to Firestore FIRST so it shows up in the NotificationsScreen
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
      print('OneSignalApiService: Error saving notification to Firestore: $e');
    }

    // 2) Send Push via OneSignal
    final appId = dotenv.env['ONESIGNAL_APP_ID'];
    final apiKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

    if (appId == null || apiKey == null || appId.isEmpty || apiKey.isEmpty) {
      print(
        'OneSignalApiService: Missing API Keys. Push notification not sent.',
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $apiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'target_channel': 'push',
          'include_aliases': {'external_id': receiverUids},
          'headings': {'en': heading},
          'contents': {'en': content},
          'ios_sound': 'default',
          'android_sound': 'notification',
          if (data != null) 'data': data,
        }),
      );

      if (response.statusCode == 200) {
        print('OneSignalApiService: Notification sent successfully.');
      } else {
        print(
          'OneSignalApiService: Failed to send notification. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      print('OneSignalApiService: Error sending notification: $e');
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
      content =
          '✅ Good news! "$propertyTitle" has been approved and is now live.';
    } else if (status == 'rejected') {
      content =
          '❌ "$propertyTitle" was rejected. Please review our guidelines.';
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
      print('OneSignalApiService: Error notifying admins: $e');
    }
  }
}
