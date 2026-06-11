import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/profile_provider.dart';
import '../widgets/profile_header.dart';
import '../widgets/settings_tile.dart';
import '../widgets/verification_badge.dart';

import 'edit_profile_screen.dart';
import 'settings_screen.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
        data: (profile) {
          final name = (profile?['fullName'] ?? '').toString().trim();
          final role = (profile?['role'] ?? '').toString();
          final isVerified = profile?['isVerified'] == true;

          int asInt(Object? v) =>
              v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

          final favoritesCount = asInt(profile?['favoritesCount']);
          final uploadedPropertiesCount = asInt(
            profile?['uploadedPropertiesCount'],
          );
          final imageUrl = (profile?['profileImage'] ?? '').toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileHeader(
                  name: name.isEmpty ? 'User' : name,
                  imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                  onEdit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    VerificationBadge(isVerified: isVerified),
                    if (role.isNotEmpty) Chip(label: Text(role)),
                  ],
                ),
                const SizedBox(height: 20),

                _statCard(title: 'Favorites', value: favoritesCount),
                const SizedBox(height: 12),
                _statCard(
                  title: 'Uploaded properties',
                  value: uploadedPropertiesCount,
                ),
                const SizedBox(height: 24),

                SettingsTile(
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'Privacy, verification and security',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),

                SettingsTile(
                  icon: Icons.verified,
                  title: 'Verification',
                  subtitle: 'KYC status and documents',
                  onTap: () => context.push('/verification'),
                ),

                SettingsTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true) {
                      await ref.read(authNotifierProvider.notifier).logout();
                      if (!context.mounted) return;
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard({required String title, required int value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
