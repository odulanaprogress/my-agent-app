import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser!.uid;

  // ❤️ ADD FAVORITE
  Future<void> addFavorite(Map<String, dynamic> property) async {
    final docId = property["id"];

    await _firestore
        .collection("users")
        .doc(userId)
        .collection("favorites")
        .doc(docId)
        .set(property);
  }

  // ❌ REMOVE FAVORITE
  Future<void> removeFavorite(String propertyId) async {
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("favorites")
        .doc(propertyId)
        .delete();
  }

  // 🔁 CHECK IF FAVORITE
  Future<bool> isFavorite(String propertyId) async {
    final doc = await _firestore
        .collection("users")
        .doc(userId)
        .collection("favorites")
        .doc(propertyId)
        .get();

    return doc.exists;
  }
}
