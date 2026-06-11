import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/escrow_status.dart';
import '../domain/transaction_type.dart';
import 'transaction_model.dart';

import 'package:firebase_auth/firebase_auth.dart';

class PaymentRepository {
  PaymentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _txCollection =>
      _firestore.collection('transactions');

  DocumentReference<Map<String, dynamic>> walletDoc(String uid) =>
      _firestore.collection('wallets').doc(uid);

  /// Creates a transaction for an escrow payment (status: held/pending based on your flow).
  Future<String> createEscrowTransaction({
    required String transactionId,
    required String tenantId,
    required String landlordId,
    required String propertyId,
    required int amount,
    required EscrowStatus status,
    required DateTime createdAt,
  }) async {
    await _txCollection.doc(transactionId).set({
      'tenantId': tenantId,
      'landlordId': landlordId,
      'propertyId': propertyId,
      'amount': amount,
      'status': status.asFirestoreValue,
      'type': TransactionType.escrow.asFirestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),

      // STEP 20 ESCROW FOUNDATION fields
      'possessionConfirmed': false,
      'possessionConfirmedAt': null,
      'landlordPaidOut': false,
      'payoutAt': null,
    });

    return transactionId;
  }

  /// Returns escrow transaction docs filtered for the currently logged-in landlord.
  ///
  /// If there is no authenticated user, returns an empty stream.
  Stream<List<TransactionModel>> getLandlordTransactions() {
    // Uses FirebaseAuth singleton like other repositories/services in this codebase.
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return _txCollection
        .where('landlordId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  /// Returns escrow transaction docs filtered for the currently logged-in tenant.
  Stream<List<TransactionModel>> getTenantTransactions() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return _txCollection
        .where('tenantId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  /// Returns all escrow transactions (for Admin).
  Stream<List<TransactionModel>> getAllTransactions() {
    return _txCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  /// Returns escrow transaction docs filtered for the provided landlord.
  Stream<List<TransactionModel>> getLandlordTransactionsByLandlordId({
    required String landlordId,
  }) {
    return _txCollection
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  Future<EscrowStatus> getTransactionStatus(String transactionId) async {
    final doc = await _txCollection.doc(transactionId).get();
    if (!doc.exists) return EscrowStatus.pending;
    final data = doc.data()!;
    final statusValue = (data['status'] ?? 'pending').toString();
    return EscrowStatusX.fromFirestore(statusValue);
  }

  Future<void> confirmPossession(String transactionId) async {
    await _txCollection.doc(transactionId).update({
      'possessionConfirmed': true,
      'possessionConfirmedAt': Timestamp.now(),
      'status': EscrowStatus.released.asFirestoreValue,
    });
  }

  Future<void> releaseLandlordPayout(String transactionId) async {
    await _txCollection.doc(transactionId).update({
      'landlordPaidOut': true,
      'payoutAt': Timestamp.now(),
      'status': EscrowStatus.released.asFirestoreValue,
    });
  }

  Future<void> transitionEscrowStatus({
    required String transactionId,
    required EscrowStatus from,
    required EscrowStatus to,
  }) async {
    await _firestore.runTransaction((tx) async {
      final ref = _txCollection.doc(transactionId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Transaction not found: $transactionId');
      }

      final data = snap.data()!;
      final current = EscrowStatusX.fromFirestore(
        (data['status'] ?? 'pending').toString(),
      );
      if (current != from) {
        throw StateError(
          'Invalid status transition: $current -> $to (expected from: $from)',
        );
      }

      tx.update(ref, {'status': to.asFirestoreValue});
    });
  }
}
