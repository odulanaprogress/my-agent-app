import 'package:cloud_firestore/cloud_firestore.dart';

class SuperAdminRepository {
  SuperAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _settingsDoc() {
    return _firestore.collection('platform_settings').doc('global');
  }

  Future<Map<String, dynamic>> getPlatformSettings() async {
    final snap = await _settingsDoc().get();
    return (snap.data() ?? <String, dynamic>{});
  }

  Future<void> updatePlatformSettings(Map<String, dynamic> data) async {
    await _settingsDoc().set(data, SetOptions(merge: true));
  }

  Future<void> writeAuditLog({required Map<String, dynamic> data}) async {
    await _firestore.collection('audit_logs').add({
      ...data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
