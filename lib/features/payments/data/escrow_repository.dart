import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/escrow_status.dart';
import '../domain/transaction_type.dart';

class EscrowRepository {
  EscrowRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _txCollection =>
      _firestore.collection('transactions');

  /// Returns transaction docs for a given user.
  /// This is a simple query placeholder; refine once you wire landlord/tenant roles.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getUserEscrows({
    required String userId,
    required bool asTenant,
    required EscrowStatus status,
  }) async {
    final q = _txCollection
        .where('type', isEqualTo: TransactionType.escrow.asFirestoreValue)
        .where('status', isEqualTo: status.asFirestoreValue);

    final q2 = asTenant
        ? q.where('tenantId', isEqualTo: userId)
        : q.where('landlordId', isEqualTo: userId);

    final snap = await q2.orderBy('createdAt', descending: true).get();
    return snap.docs;
  }
}
