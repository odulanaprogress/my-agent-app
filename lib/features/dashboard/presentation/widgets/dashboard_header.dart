import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'A';
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return fullName.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);
    final authUser = FirebaseAuth.instance.currentUser;

    final profileData = profileAsync.asData?.value;
    final String fullName = (profileData?['fullName'] as String?)?.trim().isNotEmpty == true
        ? (profileData!['fullName'] as String).trim()
        : (user?.fullName != null && user!.fullName.trim().isNotEmpty)
            ? user.fullName.trim()
            : (authUser?.displayName?.trim() ?? '');

    final String? avatarUrl = (profileData?['profileImage'] as String?)?.trim().isNotEmpty == true
        ? (profileData!['profileImage'] as String).trim()
        : (profileData?['profileImageUrl'] as String?)?.trim().isNotEmpty == true
            ? (profileData!['profileImageUrl'] as String).trim()
            : (user?.profileImage != null && user!.profileImage!.trim().isNotEmpty)
                ? user.profileImage!.trim()
                : authUser?.photoURL;

    final String firstName = fullName.isNotEmpty ? fullName.split(' ').first : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              firstName.isNotEmpty ? 'Welcome back, $firstName 👋' : 'Welcome Back 👋',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Discover Properties',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => context.push('/notifications'),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_none),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? Image.network(
                          avatarUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              _getInitials(fullName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _getInitials(fullName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
