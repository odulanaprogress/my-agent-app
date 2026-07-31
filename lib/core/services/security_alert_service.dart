import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agent_app/core/services/onesignal_api_service.dart';

class SecurityAlertService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Logs a security event and notifies all admins immediately
  static Future<void> reportAttack(String type, String description, {Map<String, dynamic>? metadata}) async {
    try {
      // 1. Log the attack in Firestore
      await _fs.collection('security_alerts').add({
        'type': type,
        'description': description,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unresolved',
      });

      // 2. Fetch all admin users
      final querySnapshot = await _fs
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final adminUids = querySnapshot.docs.map((doc) => doc.id).toList();

      if (adminUids.isNotEmpty) {
        // 3. Send real-time push notification to admins
        await OneSignalApiService.sendNotification(
          receiverUids: adminUids,
          heading: '⚠️ SECURITY ALERT: $type',
          content: description,
        );
      }
    } catch (e) {
      // Fail silently to prevent crashing the app during a security event
      print('Failed to report attack: $e');
    }
  }
}
