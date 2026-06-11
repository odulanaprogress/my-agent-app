import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../providers/privacy_provider.dart';
import '../providers/startup_provider.dart';

/// Canonical splash/entry screen used by `GoRouter`.
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
    // Keep splash visible for 6 seconds
    await Future.delayed(const Duration(seconds: 6));
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
            // Logo
            Image.asset(
              'assets/logos/agent_logo.png',
              height: 120,
              width: 120,
            ),
            const SizedBox(height: 24),
            // App name
            const Text(
              'AGENT',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
