import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/escrow_status.dart';
import '../domain/transaction_type.dart';
import 'transaction_model.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'dart:math';

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

  String _generatePin() {
    final rnd = Random.secure();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  /// Creates a transaction for an escrow payment (status: held/pending based on your flow).
  Future<String> createEscrowTransaction({
    required String transactionId,
    required String tenantId,
    required String landlordId,
    required String propertyId,
    required int amount,
    required EscrowStatus status,
    required DateTime createdAt,
    String? tenantPin,
    String? landlordPin,
    String? virtualAccountNumber,
    String? virtualBankName,
    String? virtualAccountName,
    String? txRef,
  }) async {
    final tPin = tenantPin ?? _generatePin();
    final lPin = landlordPin ?? _generatePin();

    final commissionPercent = 20.0;
    final commissionAmount = (amount * (commissionPercent / 100)).round();
    final netPayoutAmount = amount - commissionAmount;

    await _txCollection.doc(transactionId).set({
      'tenantId': tenantId,
      'landlordId': landlordId,
      'propertyId': propertyId,
      'amount': amount,
      'status': status.asFirestoreValue,
      'type': TransactionType.escrow.asFirestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),

      'tenantPin': tPin,
      'landlordPin': lPin,
      'tenantPinVerified': false,
      'landlordPinVerified': false,
      'commissionPercent': commissionPercent,
      'commissionAmount': commissionAmount,
      'netPayoutAmount': netPayoutAmount,

      'possessionConfirmed': false,
      'possessionConfirmedAt': null,
      'landlordPaidOut': false,
      'payoutAt': null,

      'virtualAccountNumber': virtualAccountNumber,
      'virtualBankName': virtualBankName ?? 'Wema Bank (Flutterwave)',
      'virtualAccountName': virtualAccountName ?? 'FLUTTERWAVE / AGENT ESCROW',
      'txRef': txRef ?? 'FLW-ESC-${transactionId.substring(0, 8).toUpperCase()}',
      'paidAt': status == EscrowStatus.held ? Timestamp.now() : null,
    });

    return transactionId;
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


  /// Verifies a 6-digit Escrow Handshake PIN via Backend REST API (with Firestore fallback).
  Future<Map<String, dynamic>> verifyEscrowPin({
    required String transactionId,
    required String pin,
    required String role, // 'tenant' or 'landlord'
  }) async {
    try {
      // Try Backend REST API first
      final apiResponse = await _apiService.verifyEscrowPin(
        transactionId: transactionId,
        pin: pin,
        role: role,
      );
      if (apiResponse['success'] == true) {
        return apiResponse;
      }
    } catch (_) {
      // Fallback to direct Firestore atomic transaction
    }

    return await _firestore.runTransaction((tx) async {
      final ref = _txCollection.doc(transactionId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Transaction not found: $transactionId');
      }

      final data = snap.data()!;
      final tenantPin = data['tenantPin'] as String?;
      final landlordPin = data['landlordPin'] as String?;
      bool tenantPinVerified = data['tenantPinVerified'] ?? false;
      bool landlordPinVerified = data['landlordPinVerified'] ?? false;

      final cleanPin = pin.trim();

      if (role == 'tenant') {
        // Tenant enters Landlord's PIN
        if (landlordPin == null || cleanPin != landlordPin) {
          throw AppException('Invalid Handover PIN entered. Please verify with the Landlord.');
        }
        tenantPinVerified = true;
      } else if (role == 'landlord') {
        // Landlord enters Tenant's PIN
        if (tenantPin == null || cleanPin != tenantPin) {
          throw AppException('Invalid Key Receipt PIN entered. Please verify with the Tenant.');
        }
        landlordPinVerified = true;
      } else {
        throw AppException('Invalid user role');
      }

      final bool bothVerified = tenantPinVerified && landlordPinVerified;

      final Map<String, dynamic> updates = {
        'tenantPinVerified': tenantPinVerified,
        'landlordPinVerified': landlordPinVerified,
        'updatedAt': Timestamp.now(),
      };

      if (bothVerified) {
        updates['possessionConfirmed'] = true;
        updates['possessionConfirmedAt'] = Timestamp.now();
        updates['status'] = EscrowStatus.released.asFirestoreValue;
        updates['landlordPaidOut'] = true;
        updates['payoutAt'] = Timestamp.now();

        // Trigger Flutterwave Escrow Settlement API (/transactions/escrow/settle)
        final netPayout = data['netPayoutAmount'] ?? data['amount'] ?? 0;
        final netPayoutInt = netPayout is int ? netPayout : (netPayout as num).toInt();
        _apiService.settleFlutterwaveEscrow(
          transactionId: transactionId,
          amount: netPayoutInt,
        );

        // Credit Landlord available balance in Firestore wallet
        final landlordId = data['landlordId'] as String?;
        if (landlordId != null && landlordId.isNotEmpty && netPayoutInt > 0) {
          _firestore.collection('wallets').doc(landlordId).set({
            'availableBalance': FieldValue.increment(netPayoutInt),
            'balance': FieldValue.increment(netPayoutInt),
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));
        }

        // Generate official Tenancy Agreement record & notify Tenant
        try {
          final now = Timestamp.now();
          _firestore.collection('tenancy_agreements').doc(transactionId).set({
            'transactionId': transactionId,
            'propertyId': data['propertyId'] ?? '',
            'tenantId': data['tenantId'] ?? '',
            'landlordId': data['landlordId'] ?? '',
            'amount': data['amount'] ?? 0,
            'status': 'active',
            'createdAt': now,
          });

          final tenantId = data['tenantId'] as String?;
          if (tenantId != null && tenantId.isNotEmpty) {
            _firestore.collection('notifications').add({
              'userId': tenantId,
              'title': '📜 Tenancy Agreement Issued!',
              'body': 'Congratulations! Your key handover is confirmed and your official signed Tenancy Agreement document is now available.',
              'isRead': false,
              'createdAt': now,
              'targetId': transactionId,
            });
          }
        } catch (_) {}
        // Auto-remove property from available listings
        final propertyId = data['propertyId'] as String?;
        if (propertyId != null && propertyId.isNotEmpty) {
           tx.update(_firestore.collection('properties').doc(propertyId), {
             'isRented': true,
             'isAvailable': false,
           });
        }
      }

      tx.update(ref, updates);

      return {
        'success': true,
        'tenantPinVerified': tenantPinVerified,
        'landlordPinVerified': landlordPinVerified,
        'bothVerified': bothVerified,
      };
    });
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

