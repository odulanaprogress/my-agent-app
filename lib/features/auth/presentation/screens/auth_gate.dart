import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../providers/current_user_provider.dart';
import '../../../dashboard/presentation/screens/tenant_dashboard_screen.dart';
import '../../../dashboard/presentation/screens/landlord_dashboard_screen.dart';
import '../../../dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../../../admin/screens/customer_support_dashboard_screen.dart';

import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    switch (authState.status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case AuthStatus.authenticated:
        final user = ref.watch(currentUserProvider);

        if (user == null) {
          return const LoginScreen();
        }

        // Prefer the role stored in Firestore.
        // (Role selection / onboarding fallback should be handled when the user profile is created/updated.)
        final effectiveRole = user.role.trim().isNotEmpty
            ? user.role.trim()
            : 'tenant';

        switch (effectiveRole) {
          case 'landlord':
            return const LandlordDashboardScreen();
          case 'admin':
            return const AdminDashboardScreen();
          case 'customer_support':
            return const CustomerSupportDashboardScreen();
          case 'tenant':
          default:
            return const TenantDashboardScreen();
        }

      case AuthStatus.error:
      case AuthStatus.unauthenticated:
      case AuthStatus.initial:
        return const LoginScreen();
    }
  }
}
