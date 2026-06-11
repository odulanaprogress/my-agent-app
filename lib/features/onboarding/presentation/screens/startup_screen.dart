import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../providers/privacy_provider.dart';
import '../providers/startup_provider.dart';
import '../../../../app/routes/route_names.dart';

/// App entry controller.
///
/// Flow:
/// 1) If onboarding incomplete -> OnboardingScreen
/// 2) Else -> AuthGate
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndRoute();
    });
  }

  Future<void> _initAndRoute() async {
    // SPLASH DELAY
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    // Capture router BEFORE any further async gaps.
    final router = GoRouter.of(context); // ignore: use_build_context_synchronously

    // Privacy check
    final privacyOk = await ref
        .read(privacyProvider.notifier)
        .checkPrivacyStatus();
    if (!mounted) return;
    if (!privacyOk) {
      router.go(RouteNames.privacy);
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

    // Role check (route to role selection if not chosen yet)
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
            Image.asset(
              'assets/logos/agent_logo.png',
              width: 140,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            const Text(
              'AGENT',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B3D2E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nigeria’s Trusted Real Estate Platform',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0B3D2E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFF0B3D2E)),
          ],
        ),
      ),
    );
  }
}
