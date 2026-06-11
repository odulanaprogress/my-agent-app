import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBehaviorService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static const _collection = 'user_behavior_logs';

  static Future<void> log({
    required String action,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _fs.collection(_collection).add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'action': action,
        'description': description ?? '',
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'mobile',
      });
    } catch (_) {
      // Silent – never crash due to logging
    }
  }

  // Convenience helpers
  static Future<void> logLogin({String method = 'email'}) =>
      log(action: 'login', description: 'User logged in', metadata: {'method': method});

  static Future<void> logLogout() =>
      log(action: 'logout', description: 'User logged out');

  static Future<void> logPropertyView(String propertyId, String title) =>
      log(action: 'property_view', description: 'Viewed property: $title',
          metadata: {'propertyId': propertyId, 'title': title});

  static Future<void> logPaymentInitiated(String propertyId, double amount) =>
      log(action: 'payment_initiated', description: 'Payment started',
          metadata: {'propertyId': propertyId, 'amount': amount});

  static Future<void> logSearch(String query) =>
      log(action: 'search', description: 'Search: $query',
          metadata: {'query': query});

  static Future<void> logSupportTicket(String subject) =>
      log(action: 'support_ticket_opened', description: 'Opened ticket: $subject',
          metadata: {'subject': subject});

  static Future<void> logProfileUpdate() =>
      log(action: 'profile_update', description: 'User updated profile');

  static Future<void> logVerificationSubmit() =>
      log(action: 'verification_submitted', description: 'KYC documents submitted');
}
