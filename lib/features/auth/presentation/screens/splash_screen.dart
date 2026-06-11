import 'dart:async';

import 'package:flutter/material.dart';

import '../../../onboarding/presentation/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Image.asset('assets/images/agent_logo.png', height: 120),

            const SizedBox(height: 30),

            const Text(
              'AGENT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Secure Real Estate Marketplace',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const SizedBox(height: 50),

            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
