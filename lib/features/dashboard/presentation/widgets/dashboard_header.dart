import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/current_user_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'A';
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return fullName[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.fullName != null && user!.fullName.isNotEmpty
                  ? 'Welcome back, ${user.fullName.split(' ').first} 👋'
                  : 'Welcome Back 👋',
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
                ),
                child: const Icon(Icons.notifications_none),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF0F172A),
              child: Text(
                _getInitials(user?.fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
