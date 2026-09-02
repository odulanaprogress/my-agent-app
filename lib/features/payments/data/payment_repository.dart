import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/escrow_status.dart';

import 'transaction_model.dart';

import 'package:firebase_auth/firebase_auth.dart';



import '../../../core/services/escrow_api_service.dart';
import '../../../core/utils/app_exception.dart';

class PaymentRepository {
  PaymentRepository(this._firestore, [EscrowApiService? apiService])
      : _apiService = apiService ?? EscrowApiService();

  final FirebaseFirestore _firestore;
  final EscrowApiService _apiService;

  CollectionReference<Map<String, dynamic>> get _txCollection =>
      _firestore.collection('transactions');

  DocumentReference<Map<String, dynamic>> walletDoc(String uid) =>
      _firestore.collection('wallets').doc(uid);



  Future<String> createEscrowTransaction({
    required String transactionId,
    required String tenantId,
    required String landlordId,
    required String propertyId,
    required int amount,
    required EscrowStatus status,
    required DateTime createdAt,
    String? virtualAccountNumber,
    String? virtualBankName,
    String? virtualAccountName,
    String? txRef,
  }) async {
    final response = await _apiService.initializePayment(
      transactionId: transactionId,
      tenantId: tenantId,
      landlordId: landlordId,
      propertyId: propertyId,
      amount: amount,
      virtualAccountNumber: virtualAccountNumber,
      virtualBankName: virtualBankName,
      virtualAccountName: virtualAccountName,
      txRef: txRef,
    );
    
    final txRefId = response['txRef'] as String? ?? transactionId;

    return txRefId;
  }

  /// Verifies transfer received by Flutterwave, updates status from pending to held, and notifies Landlord.
  Future<bool> verifyPaymentTransfer({required String transactionId}) async {
    final ref = _txCollection.doc(transactionId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw AppException('Transaction not found');
    }

    final data = snap.data()!;
    final landlordId = data['landlordId'] as String?;
    final amount = data['amount'] ?? 0;
    final txRef = data['txRef']?.toString() ?? 'FLW-ESC-$transactionId';

    // Verify with Flutterwave API service
    final verified = await _apiService.verifyPaymentStatus(
      transactionId: transactionId,
      txRef: txRef,
    );

    if (!verified) {
      throw AppException('Flutterwave could not confirm payment transfer yet. Please try again.');
    }

    final now = Timestamp.now();
    try {
      await ref.update({
        'status': EscrowStatus.held.asFirestoreValue,
        'paidAt': now,
        'updatedAt': now,
      });
    } catch (_) {
      try {
        await ref.set({
          'status': EscrowStatus.held.asFirestoreValue,
          'paidAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      } catch (e) {
        throw AppException('Permission denied when updating transaction status in Firestore. Please ensure rules allow transaction updates.');
      }
    }

    // Notify Landlord about confirmed rent payment
    if (landlordId != null && landlordId.isNotEmpty) {
      try {
        final formattedAmt = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        await _firestore.collection('notifications').add({
          'userId': landlordId,
          'title': '🎉 Escrow Payment Received!',
          'body': 'A tenant has paid ₦$formattedAmt into Flutterwave Escrow Vault for your property. Funds are securely locked until key delivery confirmation.',
          'isRead': false,
          'createdAt': now,
          'transactionId': transactionId,
        });
      } catch (_) {
        // Notification creation logging fallback
      }
    }

    return true;
  }


  /// Verifies a 6-digit Escrow Handshake PIN via Backend REST API.
  Future<Map<String, dynamic>> verifyEscrowPin({
    required String transactionId,
    required String pin,
    required String role, // 'tenant' or 'landlord'
  }) async {
    final apiResponse = await _apiService.verifyEscrowPin(
      transactionId: transactionId,
      pin: pin,
      role: role,
    );
    if (apiResponse['success'] == true) {
      return apiResponse;
    }
    throw AppException(apiResponse['error'] ?? 'Verification failed');
  }


  /// Returns escrow transaction docs filtered for the currently logged-in landlord.
  Stream<List<TransactionModel>> getLandlordTransactions() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return _txCollection
        .where('landlordId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
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
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Returns all escrow transactions (for Admin).
  Stream<List<TransactionModel>> getAllTransactions() {
    return _txCollection
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Returns escrow transaction docs filtered for the provided landlord.
  Stream<List<TransactionModel>> getLandlordTransactionsByLandlordId({
    required String landlordId,
  }) {
    return _txCollection
        .where('landlordId', isEqualTo: landlordId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
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
        throw AppException(
          'Invalid status transition: $current -> $to (expected from: $from)',
        );
      }

      tx.update(ref, {'status': to.asFirestoreValue});
    });
  }
}

