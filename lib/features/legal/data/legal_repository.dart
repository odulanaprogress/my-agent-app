import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase Storage is not currently configured in this repo.
// Keep repository compilation-safe by stubbing uploadPdf for now.

class LegalRepository {
  LegalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _legalCollection =>
      _firestore.collection('legal_documents');

  Future<String> createLegalDocument({
    required Map<String, dynamic> data,
  }) async {
    final docRef = _legalCollection.doc();
    await docRef.set(data);
    return docRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserLegalDocuments({
    required String userId,
  }) {
    // NOTE: Security rules should enforce access.
    // For UI, we keep it simple and order by createdAt.
    return _legalCollection
        .where('tenantId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> uploadPdf({
    required String uid,
    required String documentId,
    required String fileName,
    required List<int> bytes,
  }) async {
    // Firebase Storage integration is not wired in this repo right now.
    // Keep the method for future implementation.
    // For now return an empty URL to keep compilation safe.
    return '';
  }
}
