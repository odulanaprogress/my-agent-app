import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agent_app/core/services/onesignal_api_service.dart';
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

  static Future<void> _notifyLandlord(String propertyId, String title, String actionBody) async {
    try {
      final doc = await _fs.collection('properties').doc(propertyId).get();
      if (!doc.exists) return;
      final landlordId = doc.data()?['landlordId'];
      if (landlordId == null || landlordId.isEmpty) return;
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid == landlordId) return;

      await OneSignalApiService.sendNotification(
        receiverUids: [landlordId],
        heading: title,
        content: actionBody,
      );
    } catch (_) {}
  }

  // Convenience helpers
  static Future<void> logLogin({String method = 'email'}) =>
      log(action: 'login', description: 'User logged in', metadata: {'method': method});

  static Future<void> logLogout() =>
      log(action: 'logout', description: 'User logged out');

  static Future<void> logPropertyView(String propertyId, String title) async {
    await log(action: 'property_view', description: 'Viewed property: $title',
        metadata: {'propertyId': propertyId, 'title': title});
    try {
      await _fs.collection('properties').doc(propertyId).update({'viewsCount': FieldValue.increment(1)});
    } catch (_) {}
    await _notifyLandlord(propertyId, title, 'Someone is viewing your property');
  }

  static Future<void> logPropertyFavorite(String propertyId) async {
    await log(action: 'property_favorite', description: 'Favorited property', metadata: {'propertyId': propertyId});
    try {
      await _fs.collection('properties').doc(propertyId).update({'favoritesCount': FieldValue.increment(1)});
    } catch (_) {}
  }

  static Future<void> logPropertyInquiry(String propertyId, String title) async {
    await log(action: 'property_inquiry', description: 'Inquired about: $title', metadata: {'propertyId': propertyId, 'title': title});
    try {
      await _fs.collection('properties').doc(propertyId).update({'inquiriesCount': FieldValue.increment(1)});
    } catch (_) {}
    await _notifyLandlord(propertyId, title, 'Someone inquired about your property');
  }

  static Future<void> logPropertySave(String propertyId, String title, bool isSaved) async {
    await log(
      action: isSaved ? 'save_property' : 'unsave_property',
      description: '${isSaved ? "Saved" : "Unsaved"} property: $title',
      metadata: {'propertyId': propertyId, 'title': title},
    );
    try {
      await _fs.collection('properties').doc(propertyId).update({
        'favoritesCount': FieldValue.increment(isSaved ? 1 : -1),
      });
    } catch (_) {}
    if (isSaved) {
      await _notifyLandlord(propertyId, title, 'Someone saved your property');
    }
  }

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
