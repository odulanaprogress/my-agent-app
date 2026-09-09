import 'package:cloud_firestore/cloud_firestore.dart';

class SuperAdminRepository {
  SuperAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _settingsDoc() {
    return _firestore.collection('platform_settings').doc('global');
  }

  /// Real-time stream of global platform configuration
  Stream<Map<String, dynamic>> watchPlatformSettings() {
    return _settingsDoc().snapshots().map((snap) => snap.data() ?? <String, dynamic>{});
  }

  /// One-time fetch of global platform settings
  Future<Map<String, dynamic>> getPlatformSettings() async {
    final snap = await _settingsDoc().get();
    return snap.data() ?? <String, dynamic>{};
  }

  /// Update platform settings and record an immutable audit log
  Future<void> updatePlatformSettings(
    Map<String, dynamic> data, {
    String? actorEmail,
  }) async {
    final payload = <String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (actorEmail != null) {
      payload['updatedBy'] = actorEmail;
    }
    await _settingsDoc().set(payload, SetOptions(merge: true));

    await writeAuditLog(
      action: 'UPDATE_PLATFORM_SETTINGS',
      details: 'Updated global platform parameters: ${data.keys.join(', ')}',
      actorEmail: actorEmail,
    );
  }

  /// Stream of recent system audit logs
  Stream<List<Map<String, dynamic>>> watchAuditLogs({int limit = 50}) {
    return _firestore
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Append an immutable audit entry
  Future<void> writeAuditLog({
    required String action,
    required String details,
    String? actorEmail,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    final docData = <String, dynamic>{
      'action': action,
      'details': details,
      'actorEmail': actorEmail ?? 'system',
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (targetId != null) {
      docData['targetId'] = targetId;
    }
    if (metadata != null) {
      docData['metadata'] = metadata;
    }
    await _firestore.collection('audit_logs').add(docData);
  }

  /// Stream of all users with administrative roles
  Stream<List<Map<String, dynamic>>> watchAdminUsers() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['admin', 'super_admin'])
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList());
  }

  /// Modify a user's role (promote/demote) with audit tracking
  Future<void> setUserRole({
    required String targetUid,
    required String newRole,
    required String actorEmail,
    String? targetEmail,
  }) async {
    await _firestore.collection('users').doc(targetUid).update({
      'role': newRole,
      'roleUpdatedAt': FieldValue.serverTimestamp(),
      'roleUpdatedBy': actorEmail,
    });

    await writeAuditLog(
      action: 'CHANGE_USER_ROLE',
      details: 'Changed role for user ${targetEmail ?? targetUid} to $newRole',
      actorEmail: actorEmail,
      targetId: targetUid,
      metadata: {'newRole': newRole},
    );
  }
}
