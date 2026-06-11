import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;

  final String email;
  final String fullName;
  final String role;

  final String? profileImage;
  final int favoritesCount;
  final bool isVerified;
  final bool privacyAccepted;
  final bool onboardingCompleted;

  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.profileImage,
    this.favoritesCount = 0,
    required this.isVerified,
    required this.privacyAccepted,
    required this.onboardingCompleted,
    required this.createdAt,
  });

  bool get isLandlord => role == 'landlord';

  bool get isTenant => role == 'tenant';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'profileImage': profileImage,
      'favoritesCount': favoritesCount,
      'isVerified': isVerified,
      'privacyAccepted': privacyAccepted,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? 'tenant',
      profileImage: map['profileImage'],
      favoritesCount: (map['favoritesCount'] is int)
          ? (map['favoritesCount'] as int)
          : int.tryParse('${map['favoritesCount'] ?? 0}') ?? 0,
      isVerified: map['isVerified'] ?? false,
      privacyAccepted: map['privacyAccepted'] ?? false,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    final s = value.toString();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
