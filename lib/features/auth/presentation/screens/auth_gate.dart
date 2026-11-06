import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../providers/current_user_provider.dart';
import '../../../dashboard/presentation/screens/tenant_dashboard_screen.dart';
import '../../../dashboard/presentation/screens/landlord_dashboard_screen.dart';
import '../../../dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../../../admin/screens/customer_support_dashboard_screen.dart';
import 'role_selection_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    switch (authState.status) {
      case AuthStatus.loading:
        return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(child: AppLoader(size: 64)),
        );

      case AuthStatus.authenticated:
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final cachedUser = ref.watch(currentUserProvider);

            // Determine role with strict prioritization:
            // 1. Live Firestore snapshot
            // 2. Verified cached user from provider
            final rawRole = data?['role'] ?? cachedUser?.role;

            // PREVENT FLASHING: While Firestore is fetching and no cached role is present,
            // render a clean dark branded loading screen. NEVER fall back to TenantDashboardScreen!
            if (rawRole == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0F172A),
                  body: Center(child: AppLoader(size: 64)),
                );
              }
              // If Firestore finished loading and user has no role assigned:
              return const RoleSelectionScreen();
            }

            final effectiveRole = rawRole.toString().trim().toLowerCase();

            switch (effectiveRole) {
              case 'landlord':
              case 'agent':
              case 'broker':
                return const LandlordDashboardScreen();
              case 'admin':
              case 'super_admin':
                return const AdminDashboardScreen();
              case 'customer_support':
                return const CustomerSupportDashboardScreen();
              case 'tenant':
                return const TenantDashboardScreen();
              default:
                return const RoleSelectionScreen();
            }
          },
        );

      case AuthStatus.error:
      case AuthStatus.unauthenticated:
      case AuthStatus.initial:
        return const LoginScreen();
    }
  }
}
