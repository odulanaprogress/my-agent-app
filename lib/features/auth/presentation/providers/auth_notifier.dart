import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../../../../core/services/firebase_auth_service.dart';
import '../../../../shared/models/user_model.dart';

import 'auth_state.dart';

import '../../../../../core/services/user_firestore_service.dart';
import '../../../../../core/services/user_behavior_service.dart';
import '../../../../../core/services/onesignal_api_service.dart';
import 'current_user_provider.dart';
import 'package:agent_app/core/storage/secure_storage_service.dart';
import 'package:agent_app/core/storage/user_cache_service.dart';
import '../../../../../core/services/security_alert_service.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuthService _authService;
  final UserFirestoreService _userFirestoreService;
  final Ref _ref;
  int _failedLoginAttempts = 0;

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
        if (!kIsWeb) OneSignal.logout();
        return;
      }

      if (!kIsWeb) OneSignal.login(user.uid);

      try {
        final cacheService = UserCacheService();
        var cachedProfile = await cacheService.getCachedUser();

        if (cachedProfile != null && cachedProfile.uid == user.uid) {
          _ref.read(currentUserProvider.notifier).state = cachedProfile;
          state = state.copyWith(status: AuthStatus.authenticated);
        } else if (cachedProfile != null) {
          await cacheService.clearCache();
          cachedProfile = null;
        }

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
        if (profile == null && cachedProfile == null) {
          _ref.read(currentUserProvider.notifier).state = null;
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'User profile not found',
          );
          return;
        }

        if (profile != null) {
          await cacheService.saveUser(profile);
          _ref.read(currentUserProvider.notifier).state = profile;
          state = state.copyWith(status: AuthStatus.authenticated);
        } else if (cachedProfile != null) {
          profile = cachedProfile;
        }
        
        UserBehaviorService.logLogin(method: 'email_or_google');

        // OneSignal & push notifications — mobile only
        if (!kIsWeb) {
          try {
            OneSignal.login(user.uid);
            final granted = await OneSignal.Notifications.requestPermission(true);
            if (granted) {
              await Future.delayed(const Duration(seconds: 4));
              await OneSignalApiService.sendNotification(
                receiverUids: [user.uid],
                heading: 'Welcome Back!',
                content: 'You have successfully logged in to AGENT.',
              );
            }
          } catch (e) {
            debugPrint('Push notification error: $e');
          }
        }
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
      _failedLoginAttempts = 0;
      
      // Save credentials for biometric login — mobile only
      if (!kIsWeb) {
        try {
          final storage = SecureStorageService();
          await storage.write(key: 'biometric_email', value: email);
          await storage.write(key: 'biometric_password', value: password);
        } catch (e) {
          debugPrint('SecureStorage write error: $e');
        }
      }

      // Flag so the dashboard can prompt fingerprint registration on first login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('just_logged_in', true);
    } on FirebaseAuthException catch (e) {
      _failedLoginAttempts++;
      if (_failedLoginAttempts >= 3) {
        await SecurityAlertService.reportAttack(
          'Multiple Failed Logins',
          'User attempted to login with email $email and failed $_failedLoginAttempts times.',
          metadata: {'email': email, 'error': e.toString()},
        );
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
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
      
      if (!kIsWeb) {
        try {
          final storage = SecureStorageService();
          await storage.write(key: 'biometric_email', value: email);
          await storage.write(key: 'biometric_password', value: password);
        } catch (e) {
          debugPrint('SecureStorage write error: $e');
        }
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await UserBehaviorService.logLogout();
    } catch (_) {
      // Ignored to ensure logout proceeds even if offline
    }
    await UserCacheService().clearCache();
    if (!kIsWeb) OneSignal.logout();
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

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred while sending the reset link.');
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred while sending the verification email.');
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }
}

