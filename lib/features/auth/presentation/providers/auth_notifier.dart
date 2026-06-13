import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/services/firebase_auth_service.dart';
import '../../../../shared/models/user_model.dart';

import 'auth_state.dart';

import '../../../../../core/services/user_firestore_service.dart';
import '../../../../../core/services/user_behavior_service.dart';
import 'current_user_provider.dart';
import 'package:agent_app/core/storage/secure_storage_service.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuthService _authService;
  final UserFirestoreService _userFirestoreService;
  final Ref _ref;

  AuthNotifier(
    this._authService, {
    required UserFirestoreService userFirestoreService,
    required Ref ref,
  }) : _userFirestoreService = userFirestoreService,
       _ref = ref,
       super(const AuthState()) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authService.authStateChanges.listen((User? user) async {
      if (user == null) {
        _ref.read(currentUserProvider.notifier).state = null;
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      try {
        var profile = await _userFirestoreService.getUserProfile(user.uid);

        if (user.email != null && user.email!.trim().toLowerCase() == 'agentadminsupport@gmail.com') {
          if (profile == null) {
            final adminProfile = UserModel(
              uid: user.uid,
              email: 'agentadminsupport@gmail.com',
              fullName: 'Platform Admin',
              role: 'admin',
              isVerified: true,
              privacyAccepted: true,
              onboardingCompleted: true,
              createdAt: DateTime.now(),
            );
            await _userFirestoreService.createUserProfile(adminProfile);
            profile = adminProfile;
          } else if (profile.role != 'admin') {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'role': 'admin'});
            profile = await _userFirestoreService.getUserProfile(user.uid);
          }
        } else if (user.email != null && user.email!.trim().toLowerCase() == 'agentcustomercare@gmail.com') {
          if (profile == null) {
            final supportProfile = UserModel(
              uid: user.uid,
              email: 'agentcustomercare@gmail.com',
              fullName: 'Customer Care Support',
              role: 'customer_support',
              isVerified: true,
              privacyAccepted: true,
              onboardingCompleted: true,
              createdAt: DateTime.now(),
            );
            await _userFirestoreService.createUserProfile(supportProfile);
            profile = supportProfile;
          } else if (profile.role != 'customer_support') {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'role': 'customer_support'});
            profile = await _userFirestoreService.getUserProfile(user.uid);
          }
        }

        // If user doc is missing, keep UX responsive and fall back to an unauthenticated state.
        // This prevents the gate from getting stuck in loading.
        if (profile == null) {
          _ref.read(currentUserProvider.notifier).state = null;
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'User profile not found',
          );
          return;
        }

        _ref.read(currentUserProvider.notifier).state = profile;
        state = state.copyWith(status: AuthStatus.authenticated);
        UserBehaviorService.logLogin(method: 'email_or_google');
      } catch (e) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: e.toString(),
        );
      }
    });
  }

  Future<void> login({required String email, required String password}) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);

      await _authService.signIn(email: email, password: password);
      
      final storage = SecureStorageService();
      await storage.write(key: 'biometric_email', value: email);
      await storage.write(key: 'biometric_password', value: password);

      // Flag so the dashboard can prompt fingerprint registration on first login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('just_logged_in', true);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required bool privacyAccepted,
  }) async {
    try {
      state = state.copyWith(
        status: AuthStatus.loading,
        privacyAccepted: privacyAccepted,
        selectedRole: role,
      );

      await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        privacyAccepted: privacyAccepted,
      );
      
      final storage = SecureStorageService();
      await storage.write(key: 'biometric_email', value: email);
      await storage.write(key: 'biometric_password', value: password);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    }
  }

  Future<void> logout() async {
    await UserBehaviorService.logLogout();
    await _authService.signOut();
  }

  Future<void> loginWithGoogle() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
