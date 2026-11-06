import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
              'assets/logos/agent_logo.png',
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (_, a, b) => const SizedBox.shrink(),
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
