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

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final email = (map['email'] ?? '').toString();
    final fullName = (map['fullName'] ??
            map['displayName'] ??
            map['name'] ??
            (email.isNotEmpty ? email.split('@').first : 'User'))
        .toString();

    return UserModel(
      uid: (map['uid'] ?? docId ?? '').toString(),
      email: email,
      fullName: fullName,
      role: (map['role'] ?? 'tenant').toString(),
      profileImage: map['profileImage']?.toString() ??
          map['profileImageUrl']?.toString() ??
          map['photoUrl']?.toString() ??
          map['avatarUrl']?.toString(),
      favoritesCount: (map['favoritesCount'] is int)
          ? (map['favoritesCount'] as int)
          : int.tryParse('${map['favoritesCount'] ?? 0}') ?? 0,
      isVerified: _parseBool(map['isVerified'] ?? map['verificationStatus'], false),
      privacyAccepted: _parseBool(map['privacyAccepted'], true),
      onboardingCompleted: _parseBool(map['onboardingCompleted'], false),
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  static bool _parseBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'approved' || s == 'verified') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'rejected' || s == 'pending') return false;
    return fallback;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    final s = value.toString();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

