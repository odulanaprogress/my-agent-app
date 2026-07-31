import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/onesignal_api_service.dart';
import '../models/property_model.dart';

class PropertyRepository {


  Stream<List<PropertyModel>> searchProperties({
    String searchQuery = '',
    String category = '',
    String state = '',
  }) {
    Query query = firestore
        .collection('properties')
        .where('isApproved', isEqualTo: true);

    if (category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    if (state.isNotEmpty) {
      query = query.where('state', isEqualTo: state);
    }

    return query.snapshots().map((
      snapshot,
    ) {
      final properties = snapshot.docs
          .map(
            (doc) => PropertyModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (searchQuery.isEmpty) {
        return properties;
      }

      final lower = searchQuery.toLowerCase();

      return properties
          .where(
            (property) =>
                property.title.toLowerCase().contains(lower) ||
                property.description.toLowerCase().contains(lower) ||
                property.community.toLowerCase().contains(lower),
          )
          .toList();
    });
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;



  Future<String?> uploadProperty({
    required String title,
    required String description,
    required double price,
    required String category,
    required String state,
    required String lga,
    required String community,
    required String address,
    required List<String> amenities,
    required List<File> images,
    File? videoFile,
    required String contactPhone,
    String listingType = 'rent',
    String? rentalDurationUnit,
    int? rentalDurationValue,
  }) async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        return 'User not logged in';
      }

      final List<String> uploadedImageUrls = [];
      final List<String> uploadedVideoUrls = [];

      // Upload images to Cloudinary
      for (final image in images) {
        final imageUrl = await CloudinaryService().uploadImage(image);
        if (imageUrl != null) {
          uploadedImageUrls.add(imageUrl);
        }
      }

      // Upload video to Cloudinary if present
      if (videoFile != null) {
        final videoUrl = await CloudinaryService().uploadVideo(videoFile);
        if (videoUrl != null) {
          uploadedVideoUrls.add(videoUrl);
        }
      }

      // Get landlord info
      final userDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();

      final propertyDoc = firestore.collection('properties').doc();

      final property = PropertyModel(
        id: propertyDoc.id,
        ownerId: currentUser.uid,
        ownerName: userData?['fullName'] ?? '',
        title: title,
        description: description,
        price: price,
        category: category,
        state: state,
        lga: lga,
        community: community,
        address: address,
        amenities: amenities,
        imageUrls: uploadedImageUrls,
        videoUrls: uploadedVideoUrls,
        contactPhone: contactPhone,
        isApproved: false,
        approvalStatus: 'pending',
        viewsCount: 0,
        favoritesCount: 0,
        inquiriesCount: 0,
        createdAt: DateTime.now(),
        listingType: listingType,
        rentalDurationUnit: rentalDurationUnit,
        rentalDurationValue: rentalDurationValue,
      );

      final propertyMap = property.toMap();
      propertyMap['viewsCount'] = 0;
      propertyMap['favoritesCount'] = 0;
      propertyMap['inquiriesCount'] = 0;
      await propertyDoc.set(propertyMap);

      // Notify Admins
      try {
        await OneSignalApiService.notifyAllAdmins(
          heading: 'New Property Uploaded',
          content: '${userData?['fullName'] ?? 'A landlord'} uploaded "${property.title}" for review.',
        );
      } catch (e) {
        print('Push notification error: $e');
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Stream<List<PropertyModel>> getApprovedProperties() {
    return firestore
        .collection('properties')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
              .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<PropertyModel>> getLandlordProperties() {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return firestore
        .collection('properties')
        .where('ownerId', isEqualTo: currentUser.uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
              .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<void> approveProperty(String propertyId) async {
    final propertyDoc = await firestore
        .collection('properties')
        .doc(propertyId)
        .get();

    final propertyData = propertyDoc.data();

    await firestore.collection('properties').doc(propertyId).update({
      'isApproved': true,
      'approvalStatus': 'approved',
    });


    try {
      if (propertyData?['ownerId'] != null) {
        await OneSignalApiService.sendPropertyStatusNotification(
          propertyTitle: propertyData?['title'] ?? 'Your property',
          status: 'approved',
          receiverUid: propertyData!['ownerId'],
        );
      }
    } catch (e) {
      print('Push notification error: $e');
    }
  }

  Future<void> rejectProperty(String propertyId) async {
    final propertyDoc = await firestore
        .collection('properties')
        .doc(propertyId)
        .get();

    final propertyData = propertyDoc.data();

    await firestore.collection('properties').doc(propertyId).update({
      'approvalStatus': 'rejected',
    });


    try {
      if (propertyData?['ownerId'] != null) {
        await OneSignalApiService.sendPropertyStatusNotification(
          propertyTitle: propertyData?['title'] ?? 'Your property',
          status: 'rejected',
          receiverUid: propertyData!['ownerId'],
        );
      }
    } catch (e) {
      print('Push notification error: $e');
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    await firestore.collection('properties').doc(propertyId).delete();
  }
}
