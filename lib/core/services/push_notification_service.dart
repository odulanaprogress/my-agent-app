// STEP 28 placeholder.
//
// Real FCM implementation requires adding pub dependencies:
// - firebase_messaging
// - flutter_local_notifications
//
// This repo currently cannot resolve those dependencies due to existing
// version constraints elsewhere, so this file intentionally provides a
// compile-safe stub.

class PushNotificationService {
  Future<void> initialize() async {}

  Future<String?> getDeviceToken() async => null;
}
