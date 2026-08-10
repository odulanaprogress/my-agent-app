// Stub for local_auth on web platform
// This prevents compilation errors on web.

class LocalAuthentication {
  Future<bool> get canCheckBiometrics async => false;
  Future<bool> isDeviceSupported() async => false;
  Future<bool> authenticate({
    required String localizedReason,
    AuthenticationOptions? options,
  }) async => false;
}

class AuthenticationOptions {
  final bool stickyAuth;
  final bool biometricOnly;
  const AuthenticationOptions({this.stickyAuth = false, this.biometricOnly = false});
}
