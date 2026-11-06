import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../widgets/settings_tile.dart';
import '../../../../core/widgets/contact_support_dialog.dart';
import 'package:agent_app/core/widgets/app_loader.dart';


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
            icon: Icons.wallet_outlined,
            title: 'My Wallet',
            onTap: () => context.push('/wallet'),
          ),
          if (role == 'landlord' || role == 'tenant' || role == 'user')
            SettingsTile(
              icon: role == 'landlord' ? Icons.person_search_rounded : Icons.real_estate_agent_rounded,
              title: role == 'landlord' ? 'Switch to Tenant View' : 'Switch to Landlord Dashboard',
              subtitle: role == 'landlord' ? 'Browse listings as a regular renter' : 'List and manage properties as a landlord',
              onTap: () async {
                final targetRole = role == 'landlord' ? 'tenant' : 'landlord';
                try {
                  await ref.read(authNotifierProvider.notifier).switchRole(targetRole);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to ${targetRole == "landlord" ? "Landlord" : "Tenant"} mode!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    context.go('/auth');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error switching mode: $e')),
                    );
                  }
                }
              },
            ),
          if (role == 'tenant') ...[
            SettingsTile(
              icon: Icons.payment,
              title: 'Pay Rent / Escrow',
              onTap: () => context.push('/payment-method'),
            ),
          ] else if (role == 'landlord') ...[
            SettingsTile(
              icon: Icons.account_balance_outlined,
              title: 'Bank Account & Payout Setup',
              subtitle: 'Verify your account for payouts',
              onTap: () => context.push('/bank-setup'),
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
            icon: Icons.headset_mic_rounded,
            title: 'Contact Us & Support',
            subtitle: '08107416745, 08131154171 • agentcustomercare@gmail.com',
            onTap: () => ContactSupportDialog.show(context),
          ),
          SettingsTile(
            icon: Icons.lock_outline,
            title: 'Privacy & security',
            subtitle: 'Biometrics, passwords, NDPR & permissions',
            onTap: () => context.push('/privacy-security'),
          ),

          SettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              try {
                await ref.read(authNotifierProvider.notifier).logout();
              } catch (e) {
                debugPrint('[SettingsScreen] Logout error: $e');
              }
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
          
          SettingsTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: const Text(
                      'Are you sure you want to completely delete your account and data? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete Permanently'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => Center(child: AppLoader(size: 24)),
                  );
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
                    await user.delete();
                  }
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    context.go('/auth');
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete account: $e. You may need to re-login to perform this action.')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
