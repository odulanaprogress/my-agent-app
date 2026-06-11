import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/text_styles.dart';
import '../../../../core/constants/storage_keys.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();

    final privacyAccepted = prefs.getBool(StorageKeys.privacyAccepted) ?? false;
    final onboardingCompleted =
        prefs.getBool(StorageKeys.onboardingCompleted) ?? false;

    if (!mounted) return;

    if (!privacyAccepted) {
      context.go('/privacy');
      return;
    }

    if (!onboardingCompleted) {
      context.go('/onboarding');
      return;
    }

    context.go('/role-selection');
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
              'assets/images/agent_logo.png',
              width: 140,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            Text(
              'AGENT',
              style: AppTextStyles.heading1.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Nigeria’s Trusted Real Estate Platform',
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
