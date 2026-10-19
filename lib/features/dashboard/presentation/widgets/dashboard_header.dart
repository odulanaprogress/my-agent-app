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

    String? avatarUrl;
    if (profileData != null) {
      for (final key in [
        'profileImage',
        'profileImageUrl',
        'photoUrl',
        'photoURL',
        'avatarUrl',
        'avatar',
        'image',
        'imageUrl',
      ]) {
        final val = profileData[key];
        if (val is String && val.trim().isNotEmpty) {
          avatarUrl = val.trim();
          break;
        }
      }
    }
    avatarUrl ??= (user?.profileImage != null && user!.profileImage!.trim().isNotEmpty)
        ? user.profileImage!.trim()
        : authUser?.photoURL;

    final String firstName = fullName.isNotEmpty ? fullName.split(' ').first : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
                  color: Colors.black.withValues(alpha: 0.08),
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
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: Text(
                            _getInitials(fullName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                firstName.isNotEmpty ? 'Welcome back, $firstName 👋' : 'Welcome Back 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Discover Properties',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.push('/notifications'),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0F172A),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
