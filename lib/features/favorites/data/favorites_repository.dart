import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesRepository {
  final FirebaseFirestore firestore;

  FavoritesRepository(this.firestore);

  Future<void> addFavorite({
    required String uid,
    required String propertyId,
  }) async {
    final docRef = firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(propertyId);

    await docRef.set({
      'propertyId': propertyId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite({
    required String uid,
    required String propertyId,
  }) async {
    await firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(propertyId)
        .delete();
  }

  Future<bool> isFavorite({
    required String uid,
    required String propertyId,
  }) async {
    final doc = await firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(propertyId)
        .get();

    return doc.exists;
  }

  Stream<List<String>> getFavoritesPropertyIds(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.id).toList());
  }
}
