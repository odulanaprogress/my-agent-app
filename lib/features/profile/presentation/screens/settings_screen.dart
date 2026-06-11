import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = user?.role ?? 'tenant';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsTile(
            icon: Icons.person,
            title: 'Edit profile',
            onTap: () => context.push('/edit-profile'),
          ),
          SettingsTile(
            icon: Icons.verified,
            title: 'Verification',
            onTap: () => context.push('/verification'),
          ),
          SettingsTile(
            icon: Icons.chat_bubble_outline,
            title: 'Chat Conversations',
            onTap: () => context.push('/conversations'),
          ),
          SettingsTile(
            icon: Icons.wallet_outlined,
            title: 'My Wallet',
            onTap: () => context.push('/wallet'),
          ),
          if (role == 'tenant') ...[
            SettingsTile(
              icon: Icons.payment,
              title: 'Pay Rent / Escrow',
              onTap: () => context.push('/payment-method'),
            ),
          ] else if (role == 'landlord') ...[
            SettingsTile(
              icon: Icons.monetization_on_outlined,
              title: 'Payout Settings',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Landlord Bank settings coming soon.')),
                );
              },
            ),
          ] else if (role == 'admin') ...[
            SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Platform Escrows & Revenue',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Platform Financial Console coming soon.')),
                );
              },
            ),
            // Admin dashboard quick-access
            SettingsTile(
              icon: Icons.dashboard_rounded,
              title: 'Go to Admin Dashboard',
              onTap: () => context.push('/admin'),
            ),
          ],
          SettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {},
          ),
          SettingsTile(
            icon: Icons.lock_outline,
            title: 'Privacy & security',
            onTap: () {},
          ),

          SettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
