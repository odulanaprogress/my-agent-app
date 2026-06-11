import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.email,
    required super.fullName,
    required super.role,
    required super.isVerified,
    required super.biometricEnabled,
  });

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? 'tenant',
      isVerified: map['isVerified'] ?? false,
      biometricEnabled: map['biometricEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'isVerified': isVerified,
      'biometricEnabled': biometricEnabled,
    };
  }
}
