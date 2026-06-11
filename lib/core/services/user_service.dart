import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser!.uid;

  /// COLLECTION
  final String collection = 'users';

  /// CREATE USER PROFILE
  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection(collection).doc(user.id).set(user.toMap());
  }

  /// GET USER PROFILE (REAL-TIME)
  Stream<UserModel?> getUserProfile() {
    return _firestore.collection(collection).doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// UPDATE USER PROFILE
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    await _firestore.collection(collection).doc(userId).update(data);
  }
}
