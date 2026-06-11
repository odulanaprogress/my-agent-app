import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();

  int currentIndex = 0;

  final List<Map<String, String>> slides = [
    {
      'image': 'assets/images/onboarding/house_search.png',
      'title': 'Verified Properties',
      'description': 'Browse trusted and verified properties safely.',
    },

    {
      'image': 'assets/images/onboarding/secure_payment.png',
      'title': 'Secure Escrow Payments',
      'description': 'Pay safely with AGENT escrow protection.',
    },

    {
      'image': 'assets/images/onboarding/smart_investment.png',
      'title': 'Smart Property Experience',
      'description': 'Manage homes, payments, and support easily.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,

                itemCount: slides.length,

                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },

                itemBuilder: (context, index) {
                  final slide = slides[index];

                  return Padding(
                    padding: const EdgeInsets.all(24),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Image.asset(slide['image']!, height: 300),

                        const SizedBox(height: 40),

                        Text(
                          slide['title']!,
                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          slide['description']!,
                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),

              child: SizedBox(
                width: double.infinity,
                height: 58,

                child: ElevatedButton(
                  onPressed: () async {
                    if (currentIndex == slides.length - 1) {
                      await ref
                          .read(onboardingProvider.notifier)
                          .completeOnboarding();
                      if (!context.mounted) return;
                      context.go('/role-selection');
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },

                  child: Text(
                    currentIndex == slides.length - 1 ? 'Get Started' : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
