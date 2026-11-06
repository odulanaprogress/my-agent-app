import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../providers/privacy_provider.dart';
import '../providers/startup_provider.dart';

/// Canonical splash/entry screen used by GoRouter.
///
/// Flow:
/// 1) If privacy not accepted -> /privacy
/// 2) Else if onboarding incomplete -> /onboarding
/// 3) Else if role not selected -> /role-selection
/// 4) Else -> /auth
class AuthSplashScreen extends ConsumerStatefulWidget {
  const AuthSplashScreen({super.key});

  @override
  ConsumerState<AuthSplashScreen> createState() => _AuthSplashScreenState();
}

class _AuthSplashScreenState extends ConsumerState<AuthSplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndRoute();
    });
  }

  Future<void> _initAndRoute() async {
    // Sign out any persisted Firebase session so the user must always
    // authenticate on every fresh app launch. Biometric credentials stored
    // in SecureStorage are intentionally NOT cleared so fingerprint login
    // can still retrieve them.
    await FirebaseAuth.instance.signOut();

    // Keep splash visible for a brief moment
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Capture router BEFORE any further async gaps to avoid
    // BuildContext-across-async-gap lint warnings.
    final router = GoRouter.of(context); // ignore: use_build_context_synchronously

    // Privacy check
    final privacyOk = await ref
        .read(privacyProvider.notifier)
        .checkPrivacyStatus();
    if (!mounted) return;
    if (!privacyOk) {
      router.go('/privacy');
      return;
    }

    // Onboarding check
    final onboardingOk = await ref
        .read(onboardingProvider.notifier)
        .checkOnboardingStatus();
    if (!mounted) return;
    if (!onboardingOk) {
      router.go('/onboarding');
      return;
    }

    // Role check
    final role = await ref.read(startupServiceProvider).getUserRole();
    if (!mounted) return;

    if (role == null || role.trim().isEmpty) {
      router.go('/role-selection');
      return;
    }

    router.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Blue Logo
            Hero(
              tag: 'app_logo',
              child: Image.asset(
                'assets/logos/agent_logo.png',
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Beyond Housing',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A43EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
