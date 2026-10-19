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
        if (!kIsWeb) {
          try { OneSignal.logout(); } catch (_) {}
        }
        return;
      }

      // Link this device to the user's Firebase UID so OneSignal can target them
      if (!kIsWeb) {
        try { OneSignal.login(user.uid); } catch (_) {}
      }

      final cacheService = UserCacheService();
      UserModel? cachedProfile;
      try {
        cachedProfile = await cacheService.getCachedUser();
        if (cachedProfile != null && cachedProfile.uid == user.uid) {
          _ref.read(currentUserProvider.notifier).state = cachedProfile;
          state = state.copyWith(status: AuthStatus.authenticated);
        }
      } catch (e) {
        debugPrint('[AuthNotifier] Cache read error: $e');
      }

      UserModel? profile;
      try {
        profile = await _userFirestoreService.getUserProfile(user.uid);
      } catch (e) {
        debugPrint('[AuthNotifier] Firestore getUserProfile error: $e');
      }

      final userEmail = user.email?.trim().toLowerCase() ?? '';

      // Auto-assign roles for system emails
      if (userEmail == 'agentadminsupport@gmail.com') {
        if (profile == null) {
          final adminProfile = UserModel(
            uid: user.uid,
            email: 'agentadminsupport@gmail.com',
            fullName: user.displayName ?? 'Platform Admin',
            role: 'admin',
            isVerified: true,
            privacyAccepted: true,
            onboardingCompleted: true,
            createdAt: DateTime.now(),
          );
          try {
            await _userFirestoreService.createUserProfile(adminProfile);
          } catch (_) {}
          profile = adminProfile;
        } else if (profile.role != 'admin') {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'role': 'admin'});
            profile = await _userFirestoreService.getUserProfile(user.uid);
          } catch (_) {}
        }
      } else if (userEmail == 'agentcustomercare@gmail.com') {
        if (profile == null) {
          final supportProfile = UserModel(
            uid: user.uid,
            email: 'agentcustomercare@gmail.com',
            fullName: user.displayName ?? 'Customer Care Support',
            role: 'customer_support',
            isVerified: true,
            privacyAccepted: true,
            onboardingCompleted: true,
            createdAt: DateTime.now(),
          );
          try {
            await _userFirestoreService.createUserProfile(supportProfile);
          } catch (_) {}
          profile = supportProfile;
        } else if (profile.role != 'customer_support') {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'role': 'customer_support'});
            profile = await _userFirestoreService.getUserProfile(user.uid);
          } catch (_) {}
        }
      }

      // If user doc is missing from Firestore, auto-create a basic profile
      if (profile == null) {
        debugPrint('[AuthNotifier] No profile found for ${user.uid} — creating fallback.');
        final autoProfile = cachedProfile ?? UserModel(
          uid: user.uid,
          email: user.email ?? '',
          fullName: user.displayName ?? (user.email != null && user.email!.contains('@') ? user.email!.split('@').first : 'User'),
          role: (userEmail == 'agentadminsupport@gmail.com') ? 'admin' : 'tenant',
          isVerified: user.emailVerified,
          privacyAccepted: true,
          onboardingCompleted: false,
          createdAt: DateTime.now(),
        );

        profile = autoProfile;
        try {
          await _userFirestoreService.createUserProfile(autoProfile);
        } catch (e) {
          debugPrint('[AuthNotifier] Failed to persist profile to Firestore: $e');
        }
      }

      // Settle authenticated state safely
      try {
        await cacheService.saveUser(profile);
      } catch (_) {}

      _ref.read(currentUserProvider.notifier).state = profile;
      state = state.copyWith(status: AuthStatus.authenticated);

      // Background telemetry & welcome notification — never block auth
      try {
        UserBehaviorService.logLogin(method: 'email_or_google');
      } catch (_) {}

      if (!kIsWeb) {
        Future.microtask(() async {
          try {
            final granted = await OneSignal.Notifications.requestPermission(true);
            if (granted) {
              await OneSignalApiService.sendNotification(
                receiverUids: [user.uid],
                heading: 'Welcome Back!',
                content: 'You have successfully logged in to AGENT.',
              );
            }
          } catch (e) {
            debugPrint('Push notification background error: $e');
          }
        });
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
    // 1. Immediately reset memory state so UI and routers react synchronously
    _ref.read(currentUserProvider.notifier).state = null;
    state = const AuthState(status: AuthStatus.unauthenticated);

    // 2. Clear local cache
    try {
      await UserCacheService().clearCache();
    } catch (_) {}

    // 3. Fire-and-forget logging and push notification logout without blocking
    UserBehaviorService.logLogout().timeout(const Duration(seconds: 2)).catchError((_) {});
    if (!kIsWeb) {
      try { OneSignal.logout(); } catch (_) {}
    }

    // 4. Sign out Firebase Auth and Google
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('[AuthNotifier] signOut error: $e');
    }
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

