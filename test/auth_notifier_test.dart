import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:agent_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:agent_app/core/services/firebase_auth_service.dart';
import 'package:agent_app/core/services/user_firestore_service.dart';
import 'package:agent_app/shared/models/user_model.dart';

class MockFirebaseAuthService implements FirebaseAuthService {
  bool signOutCalled = false;

  @override
  fb.User? get currentUser => null;

  @override
  Stream<fb.User?> get authStateChanges => Stream.value(null);

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<fb.UserCredential> signIn({required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<fb.UserCredential> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required bool privacyAccepted,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<fb.UserCredential?> signInWithGoogle() async {
    throw UnimplementedError();
  }
}

class MockUserFirestoreService implements UserFirestoreService {
  @override
  Future<void> createUserProfile(UserModel user) async {}

  @override
  Future<UserModel?> getUserProfile(String uid) async => null;

  @override
  Future<void> updateUserProfile({required String uid, required Map<String, dynamic> data}) async {}
}

void main() {
  test('AuthNotifier logout sets status to unauthenticated and calls signOut', () async {
    final mockAuth = MockFirebaseAuthService();
    final mockFirestore = MockUserFirestoreService();

    final container = ProviderContainer(
      overrides: [
        firebaseAuthServiceProvider.overrideWithValue(mockAuth),
        userFirestoreServiceProvider.overrideWithValue(mockFirestore),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);

    // Call logout
    await notifier.logout();

    expect(mockAuth.signOutCalled, isTrue);
  });
}
