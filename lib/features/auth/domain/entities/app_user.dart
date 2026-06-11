class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final bool isVerified;
  final bool biometricEnabled;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isVerified,
    required this.biometricEnabled,
  });
}
