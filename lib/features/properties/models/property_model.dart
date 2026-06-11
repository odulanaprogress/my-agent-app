import 'package:cloud_firestore/cloud_firestore.dart';

/// PropertyModel represents a marketplace listing.
/// Firestore collection: `properties/{propertyId}`
class PropertyModel {
  final String id;
  final String ownerId;
  final String ownerName;

  final String title;
  final String description;
  final num price;

  final String category;
  final String state;
  final String lga;
  final String community;
  final String address;

  final List<String> amenities;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final String contactPhone;
  final String whatsappNumber;

  final String approvalStatus; // pending | approved | rejected
  final bool isApproved;

  final int viewsCount;
  final int favoritesCount;
  final int inquiriesCount;

  final DateTime createdAt;

  final String listingType; // sell | rent | lease | shortlet
  final String? rentalDurationUnit; // hours | days | weeks | months | years
  final int? rentalDurationValue;

  // Backwards-compatible computed fields (to keep legacy UI compiling).
  // These will be removed once the UI is fully migrated to the new schema.
  String get location => address.isNotEmpty ? address : community;
  String get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';
  bool get isPremium => approvalStatus == 'approved' && isApproved;
  List<String> get favorites => const [];
  String get contact => contactPhone;
  String get whatsapp => whatsappNumber;

  const PropertyModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.state,
    required this.lga,
    required this.community,
    required this.address,
    required this.amenities,
    required this.imageUrls,
    required this.videoUrls,
    required this.contactPhone,
    required this.whatsappNumber,
    required this.approvalStatus,
    required this.isApproved,
    required this.viewsCount,
    required this.favoritesCount,
    required this.inquiriesCount,
    required this.createdAt,
    this.listingType = 'rent',
    this.rentalDurationUnit,
    this.rentalDurationValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'price': price,
      'category': category,
      'state': state,
      'lga': lga,
      'community': community,
      'address': address,
      'amenities': amenities,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'contactPhone': contactPhone,
      'whatsappNumber': whatsappNumber,
      'approvalStatus': approvalStatus,
      'isApproved': isApproved,
      'viewsCount': viewsCount,
      'favoritesCount': favoritesCount,
      'inquiriesCount': inquiriesCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'listingType': listingType,
      'rentalDurationUnit': rentalDurationUnit,
      'rentalDurationValue': rentalDurationValue,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }

    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory PropertyModel.fromMap(Map<String, dynamic> map, String documentId) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    num parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return PropertyModel(
      id: documentId,
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: parseNum(map['price']),
      category: map['category'] ?? '',
      state: map['state'] ?? '',
      lga: map['lga'] ?? '',
      community: map['community'] ?? '',
      address: map['address'] ?? '',
      amenities: (map['amenities'] is List)
          ? List<String>.from((map['amenities'] as List).map((e) => '$e'))
          : <String>[],
      imageUrls: (map['imageUrls'] is List)
          ? List<String>.from((map['imageUrls'] as List).map((e) => '$e'))
          : <String>[],
      videoUrls: (map['videoUrls'] is List)
          ? List<String>.from((map['videoUrls'] as List).map((e) => '$e'))
          : <String>[],
      contactPhone: map['contactPhone'] ?? map['contact'] ?? '',
      whatsappNumber: map['whatsappNumber'] ?? map['whatsapp'] ?? '',
      // Legacy compatibility
      approvalStatus: map['approvalStatus'] ?? 'pending',
      isApproved: map['isApproved'] == true || map['isApproved'] == 1,
      viewsCount: parseInt(map['viewsCount'] ?? 0),
      favoritesCount: parseInt(map['favoritesCount'] ?? 0),
      inquiriesCount: parseInt(map['inquiriesCount'] ?? 0),
      createdAt: _parseDateTime(map['createdAt']),
      listingType: map['listingType'] ?? 'rent',
      rentalDurationUnit: map['rentalDurationUnit'],
      rentalDurationValue: map['rentalDurationValue'] != null ? parseInt(map['rentalDurationValue']) : null,
    );
  }
}
