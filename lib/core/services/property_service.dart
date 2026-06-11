import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/properties/models/property_model.dart';

class PropertyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// COLLECTION
  final String collection = 'properties';

  /// ADD PROPERTY
  Future<void> addProperty(PropertyModel property) async {
    await _firestore.collection(collection).add(property.toMap());
  }

  /// GET ALL PROPERTIES (REALTIME)
  /// Used by internal/admin flows.
  Stream<List<PropertyModel>> getProperties() {
    return _firestore
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// GET APPROVED PROPERTIES ONLY (REALTIME)
  /// Public marketplace feed.
  Stream<List<PropertyModel>> getApprovedProperties() {
    return _firestore
        .collection(collection)
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
              .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// GET SINGLE PROPERTY (REAL-TIME)
  Stream<PropertyModel?> getPropertyStream(String id) {
    return _firestore.collection(collection).doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return PropertyModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// UPDATE PROPERTY
  Future<void> updateProperty(String id, Map<String, dynamic> data) async {
    await _firestore.collection(collection).doc(id).update(data);
  }

  /// DELETE PROPERTY
  Future<void> deleteProperty(String id) async {
    await _firestore.collection(collection).doc(id).delete();
  }

  /// FAVORITE PROPERTY
  Future<void> toggleFavorite({
    required String propertyId,
    required String userId,
    required bool isFavorite,
  }) async {
    final docRef = _firestore.collection(collection).doc(propertyId);

    if (isFavorite) {
      await docRef.update({
        'favorites': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'favorites': FieldValue.arrayUnion([userId]),
      });
    }
  }

  /// GET USER FAVORITES
  Stream<List<PropertyModel>> getFavoriteProperties(String userId) {
    return _firestore
        .collection(collection)
        .where('favorites', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// GET LANDLORD PROPERTIES (REALTIME)
  Stream<List<PropertyModel>> getLandlordProperties(String ownerId) {
    return _firestore
        .collection(collection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
              .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }
}
