import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_gate.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/fingerprint_login_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/landlord_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/tenant_dashboard_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/screens/favorites_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/payments/presentation/screens/wallet_screen.dart';

import '../../features/admin/screens/admin_analytics_screen.dart';
import '../../features/admin/screens/admin_property_approval_screen.dart';
import '../../features/admin/screens/admin_verification_screen.dart';
import '../../features/admin/screens/admin_properties_screen.dart';
import '../../features/admin/screens/admin_users_screen.dart';

import '../../features/onboarding/presentation/screens/privacy_consent_screen.dart';
import '../../features/onboarding/presentation/screens/startup_screen.dart';
import '../../features/onboarding/presentation/screens/auth_splash_screen.dart';

import '../../features/verification/verification/presentation/screens/verification_intro_screen.dart';
import '../../features/verification/verification/presentation/screens/upload_verification_screen.dart';
import '../../features/verification/verification/presentation/screens/verification_status_screen.dart';
import '../../features/verification/verification/presentation/screens/verification_required_screen.dart';

import '../../features/properties/screens/upload_property_screen.dart';
import '../../features/properties/screens/property_details_screen.dart';
import '../../features/properties/screens/edit_property_screen.dart';
import '../../features/properties/models/property_model.dart';
import '../../features/search/presentation/screens/property_detail_view_screen.dart';
import '../../features/notifications/presentation/screens/messaging_screen.dart';
import '../../features/payments/presentation/screens/payment_method_screen.dart';
import '../../features/ai/screens/ai_chat_screen.dart';
import '../../features/admin/screens/customer_support_dashboard_screen.dart';
import '../../features/admin/screens/admin_behavior_logs_screen.dart';
import '../../features/legal/presentation/screens/tenancy_agreement_screen.dart';
import '../../features/legal/presentation/screens/rental_countdown_screen.dart';

// ── Protected paths ───────────────────────────────────────────────────────────
const _protectedPaths = {
  '/tenant',
  '/landlord',
  '/admin',
  '/admin/users',
  '/favorites',
  '/profile',
  '/edit-profile',
  '/conversations',
  '/wallet',
  '/notifications',
  '/search',
  '/search/favorites',
  '/verification',
  '/verification/upload',
  '/verification/status',
  '/verification/required',
  '/properties/upload',
  '/properties/details',
  '/properties/edit',
  '/payment-method',
  '/messaging',
  '/ai-chat',
  '/customer-support',
  '/admin/behavior-logs',
  '/tenancy-agreement',
  '/my-rentals',
};

// ── Auth-backed Listenable so GoRouter reacts to login/logout ────────────────

class _AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;

  _AuthChangeNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// ── Router provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier();
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/auth-splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final path = state.matchedLocation;

      final isAuthenticated = user != null;
      final isProtected = _protectedPaths.any((p) => path.startsWith(p));

      // Not authenticated → redirect from protected pages to /login
      if (!isAuthenticated && isProtected) return '/login';

      // Authenticated → don't let them sit on /login or /register
      if (isAuthenticated &&
          (path == '/login' || path == '/register')) {
        return '/auth';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth-splash',
        builder: (context, state) => const AuthSplashScreen(),
      ),
      GoRoute(path: '/startup', redirect: (_, _) => '/auth'),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyConsentScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthGate()),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),

      // Search + favorites
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/search/favorites',
        builder: (context, state) => const SearchFavoritesScreen(),
      ),
      GoRoute(
        path: '/search/property-details',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PropertyDetailViewScreen(propertyData: extra ?? {});
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/tenant',
        builder: (context, state) => const TenantDashboardScreen(),
      ),
      GoRoute(
        path: '/landlord',
        builder: (context, state) => const LandlordDashboardScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (context, state) => AdminAnalyticsScreen(),
      ),
      GoRoute(
        path: '/admin/property-approvals',
        builder: (context, state) => AdminPropertyApprovalScreen(),
      ),
      GoRoute(
        path: '/admin/verifications',
        builder: (context, state) => AdminVerificationScreen(),
      ),
      GoRoute(
        path: '/admin/properties',
        builder: (context, state) => const AdminPropertiesScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/messaging',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return MessagingScreen(
            recipientId: extra?['recipientId'] ?? '',
            recipientName: extra?['recipientName'] ?? 'User',
          );
        },
      ),
      GoRoute(
        path: '/payment-method',
        builder: (context, state) => const PaymentMethodScreen(),
      ),
      GoRoute(
        path: '/conversations',
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),

      // Verification flow
      GoRoute(
        path: '/verification',
        builder: (context, state) => const VerificationIntroScreen(),
      ),
      GoRoute(
        path: '/verification/upload',
        builder: (context, state) => const UploadVerificationScreen(),
      ),
      GoRoute(
        path: '/verification/status',
        builder: (context, state) => const VerificationStatusScreen(),
      ),
      GoRoute(
        path: '/verification/required',
        builder: (context, state) => const VerificationRequiredScreen(),
      ),

      // Auth / misc
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/properties/upload',
        builder: (context, state) => const UploadPropertyScreen(),
      ),
      GoRoute(
        path: '/properties/details',
        builder: (context, state) {
          final property = state.extra as PropertyModel;
          return PropertyDetailsScreen(property: property);
        },
      ),
      GoRoute(
        path: '/properties/edit',
        builder: (context, state) {
          final property = state.extra as PropertyModel;
          return EditPropertyScreen(property: property);
        },
      ),
      GoRoute(
        path: '/fingerprint',
        builder: (context, state) => const FingerprintLoginScreen(),
      ),
      GoRoute(
        path: '/ai-chat',
        builder: (context, state) => const AIChatScreen(),
      ),
      GoRoute(
        path: '/customer-support',
        builder: (context, state) => const CustomerSupportDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/behavior-logs',
        builder: (context, state) => const AdminBehaviorLogsScreen(),
      ),
      GoRoute(
        path: '/tenancy-agreement',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return TenancyAgreementScreen(
            propertyId: extra?['propertyId'],
            propertyTitle: extra?['propertyTitle'],
            landlordId: extra?['landlordId'],
            rentAmount: extra?['rentAmount']?.toDouble(),
            tenantName: extra?['tenantName'],
            landlordName: extra?['landlordName'],
          );
        },
      ),
      GoRoute(
        path: '/my-rentals',
        builder: (context, state) => const RentalCountdownScreen(),
      ),

      // Fallback
      GoRoute(
        path: '/:rest(.*)',
        builder: (context, state) => const StartupScreen(),
      ),
    ],
  );
});

// Backwards-compat export for existing code.
final appRouter = routerProvider;
