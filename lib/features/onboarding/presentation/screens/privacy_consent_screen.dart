import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/text_styles.dart';

import '../providers/privacy_provider.dart';

class PrivacyConsentScreen extends ConsumerWidget {
  const PrivacyConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy & Data Consent')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We collect and use your data to keep transactions safe.',
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: 16),
              const Text(
                'We collect:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Identity information\n'
                '• Payment/escrow-related data\n'
                '• Property transaction details\n'
                '• Location data\n'
                '• Verification documents',
              ),
              const SizedBox(height: 16),
              const Text(
                'We use data for:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Fraud prevention\n'
                '• Escrow security\n'
                '• Legal compliance\n'
                '• Transaction processing',
              ),
              const SizedBox(height: 16),
              const Text(
                'Your rights:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Request deletion\n'
                '• Request correction\n'
                '• Request data export',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(privacyProvider.notifier).acceptPrivacy();
                    if (!context.mounted) return;
                    context.go('/onboarding');
                  },
                  child: const Text('Accept & Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
