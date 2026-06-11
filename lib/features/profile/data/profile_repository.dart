import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:typed_data';

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  late final CloudinaryPublic _cloudinary = CloudinaryPublic(
    dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'your_cloud_name',
    dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'your_upload_preset',
  );

  String? get _uid => _auth.currentUser?.uid;

  Future<Map<String, dynamic>?> fetchProfileMap(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>?> watchProfileMap(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((d) {
      if (!d.exists) return null;
      return d.data();
    });
  }

  Future<String?> uploadProfileImage(Uint8List imageBytes) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          imageBytes,
          identifier: 'profile_$uid',
          folder: 'agent_app/profiles',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String fullName,
    String? phoneNumber,
    String? bio,
    String? profileImageUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final data = <String, dynamic>{'fullName': fullName};

    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (bio != null) data['bio'] = bio;
    if (profileImageUrl != null) data['profileImage'] = profileImageUrl;

    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
