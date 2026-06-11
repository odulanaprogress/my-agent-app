import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/verification_status.dart';

class VerificationRepository {
  VerificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('verifications');

  DocumentReference<Map<String, dynamic>> docFor(String uid) =>
      _collection.doc(uid);

  Future<void> upsertVerification({
    required String uid,
    required String verificationType,
    required String fullName,
    String? documentNumber,
    String? documentFront,
    String? documentBack,
    String? selfieImage,
    String? propertyOwnershipDoc,
    String? utilityBill,
    String? role,
    String? email,
    required VerificationStatus status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? rejectionReason,
  }) async {
    await docFor(uid).set({
      'uid': uid,
      'fullName': fullName,
      'verificationType': verificationType,
      'documentNumber': documentNumber ?? '',
      'documentFront': documentFront ?? '',
      'documentBack': documentBack ?? '',
      'selfieImage': selfieImage ?? '',
      'propertyOwnershipDoc': propertyOwnershipDoc ?? '',
      'utilityBill': utilityBill ?? '',
      'role': role ?? 'tenant',
      'email': email ?? '',
      'status': status.asFirestoreValue,
      'submittedAt': Timestamp.fromDate(submittedAt ?? DateTime.now()),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt) : null,
      'rejectionReason': rejectionReason,
    }, SetOptions(merge: true));


    // Synchronize user verification status
    await _firestore.collection('users').doc(uid).set({
      'verificationStatus': status.asFirestoreValue,
      'isVerified': status == VerificationStatus.approved,
    }, SetOptions(merge: true));
  }


  Future<Map<String, dynamic>?> getVerificationDoc(String uid) async {
    final snap = await docFor(uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<VerificationStatus> getStatus(String uid) async {
    final snap = await docFor(uid).get();
    if (!snap.exists) return VerificationStatus.pending;
    final data = snap.data()!;
    final statusValue = (data['status'] ?? 'pending').toString();
    return VerificationStatusX.fromFirestore(statusValue);
  }

  Future<void> reviewVerification({
    required String uid,
    required VerificationStatus newStatus,
    required String reviewedReason,
  }) async {
    if (newStatus != VerificationStatus.approved &&
        newStatus != VerificationStatus.rejected) {
      throw ArgumentError('reviewVerification only supports approved/rejected');
    }

    await docFor(uid).set({
      'status': newStatus.asFirestoreValue,
      'reviewedAt': Timestamp.fromDate(DateTime.now()),
      'rejectionReason': newStatus == VerificationStatus.rejected
          ? reviewedReason
          : null,
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set({
      'verificationStatus': newStatus.asFirestoreValue,
      'isVerified': newStatus == VerificationStatus.approved,
    }, SetOptions(merge: true));
  }

}
