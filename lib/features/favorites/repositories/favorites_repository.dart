import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> addFavorite(String propertyId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    await firestore
        .collection('favorites')
        .doc(currentUser.uid)
        .collection('items')
        .doc(propertyId)
        .set({'propertyId': propertyId, 'createdAt': Timestamp.now()});
  }

  Future<void> removeFavorite(String propertyId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    await firestore
        .collection('favorites')
        .doc(currentUser.uid)
        .collection('items')
        .doc(propertyId)
        .delete();
  }

  Stream<bool> isFavorite(String propertyId) {
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return Stream.value(false);
    }

    return firestore
        .collection('favorites')
        .doc(currentUser.uid)
        .collection('items')
        .doc(propertyId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<String>> getFavorites() {
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return firestore
        .collection('favorites')
        .doc(currentUser.uid)
        .collection('items')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => (doc['propertyId'] as String))
              .toList();
        });
  }
}
