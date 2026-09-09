import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/super_admin_provider.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

class FeatureFlagsScreen extends ConsumerWidget {
  const FeatureFlagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    final repo = ref.read(superAdminRepositoryProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dynamic Feature Flags'),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: AppLoader(size: 32)),
        error: (err, _) => Center(child: Text('Error loading flags: $err')),
        data: (data) {
          final flags = (data['flags'] as Map<String, dynamic>?) ?? {};

          Widget flagTile({
            required String key,
            required String title,
            required String subtitle,
            required bool defaultValue,
            required IconData icon,
          }) {
            final isEnabled = flags[key] ?? defaultValue;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile.adaptive(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isEnabled ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: isEnabled ? const Color(0xFF10B981) : Colors.grey, size: 22),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                value: isEnabled,
                activeTrackColor: const Color(0xFF0F172A),
                onChanged: (val) async {
                  final updatedFlags = Map<String, dynamic>.from(flags);
                  updatedFlags[key] = val;
                  await repo.updatePlatformSettings({
                    'flags': updatedFlags,
                  }, actorEmail: user?.email ?? 'super_admin');
                },
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Kill Switches & Beta Features',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              flagTile(
                key: 'ai_assistant_enabled',
                title: 'AI Real Estate Assistant',
                subtitle: 'Enable Gemini-powered property recommendation & tenancy helper',
                defaultValue: true,
                icon: Icons.auto_awesome_rounded,
              ),
              flagTile(
                key: 'flutterwave_escrow_enabled',
                title: 'Live Flutterwave Escrow NUBAN',
                subtitle: 'Generate dedicated virtual bank accounts for tenant payments',
                defaultValue: true,
                icon: Icons.account_balance_rounded,
              ),
              flagTile(
                key: 'biometrics_enabled',
                title: 'Fingerprint / Biometric Login',
                subtitle: 'Allow biometric credential caching for fast login',
                defaultValue: true,
                icon: Icons.fingerprint_rounded,
              ),
              flagTile(
                key: 'kyc_strict_mode',
                title: 'Strict KYC Verification Enforcement',
                subtitle: 'Block listing and renting until Tier 1 NIN/BVN is verified',
                defaultValue: false,
                icon: Icons.verified_user_rounded,
              ),
              flagTile(
                key: 'direct_chat_enabled',
                title: 'Direct Tenant-Landlord Messaging',
                subtitle: 'Permit real-time encrypted messaging before escrow deposit',
                defaultValue: true,
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}
