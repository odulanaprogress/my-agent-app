class AccessControlService {
  /// Used by payments.
  Future<bool> isVerified() async {
    // TODO: integrate with VerificationRepository / verification status.
    return true;
  }

  /// Used by upload property.
  Future<bool> isPropertyOwner() async {
    // TODO: integrate with roles/user claims.
    return true;
  }

  bool isAdmin(String role) => role == 'admin';
}
