import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/category_section.dart';
import '../widgets/featured_property_section.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../../../../features/support/support_inquiry_screen.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/user_behavior_service.dart';
import '../../../../features/ai/screens/ai_chat_screen.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/biometric_registration_prompt.dart';

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  ConsumerState<TenantDashboardScreen> createState() =>
      _TenantDashboardScreenState();
}


class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen> {
  int currentIndex = 0;
  String searchQuery = '';
  String? selectedCategory;

  TutorialCoachMark? tutorialCoachMark;
  final GlobalKey _aiChatKey = GlobalKey();
  final GlobalKey _supportKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _quickActionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.requestLocationPermission(context);
      UserBehaviorService.logLogin();
      _checkAndShowTour();
      _checkJustRegistered();
    });
  }

  Future<void> _checkJustRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    final justRegistered = prefs.getBool('just_registered') ?? false;
    final justLoggedIn = prefs.getBool('just_logged_in') ?? false;
    if (justRegistered) {
      await prefs.setBool('just_registered', false);
      if (mounted) {
        await showBiometricRegistrationPromptIfNeeded(context);
      }
    } else if (justLoggedIn) {
      await prefs.setBool('just_logged_in', false);
      if (mounted) {
        await showBiometricRegistrationPromptIfNeeded(context);
      }
    }
  }

  Future<void> _checkAndShowTour() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTour = prefs.getBool('has_seen_tour_tenant') ?? false;
    
    if (!hasSeenTour && mounted) {
      _showTour();
      await prefs.setBool('has_seen_tour_tenant', true);
    }
  }

  void _showTour() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: const Color(0xFF0F172A),
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {},
      onClickTarget: (target) {},
      onClickTargetWithTapPosition: (target, tapDetails) {},
      onClickOverlay: (target) {},
      onSkip: () => true,
    )..show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "searchKey",
        keyTarget: _searchKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Search Properties",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Find your dream home by searching through our premium listings.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "quickActionsKey",
        keyTarget: _quickActionsKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Actions",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Access your wallet, rentals, verification, and saved properties quickly.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "aiChatKey",
        keyTarget: _aiChatKey,
        shape: ShapeLightFocus.Circle,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Assistant",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Need help finding a property? Chat with our smart AI assistant anytime.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "supportKey",
        keyTarget: _supportKey,
        shape: ShapeLightFocus.RRect,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Customer Support",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Have an issue? Open a ticket or chat with our live support agents.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ];
  }

  Future<void> _confirmLogout(BuildContext context) async {
    // Prompt biometric registration if not set up
    final proceed = await showBiometricRegistrationPromptIfNeeded(context);
    if (!proceed) return;
    if (!context.mounted) return;

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await ref.read(authNotifierProvider.notifier).logout();
      if (!context.mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            key: _aiChatKey,
            heroTag: 'ai_chat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AIChatScreen()),
            ),
            backgroundColor: const Color(0xFF0F172A),
            tooltip: 'AI Assistant',
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            key: _supportKey,
            heroTag: 'support',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportInquiryScreen()),
            ),
            backgroundColor: const Color(0xFF6366F1),
            icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
            label: const Text(
              'Support',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            tooltip: 'Contact Support / Make Inquiry',
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            onPressed: () => _showHelpSheet(context),
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF0F172A), size: 20),
            tooltip: 'Help & Tour',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_outlined, color: Colors.redAccent, size: 20),
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DashboardHeader(),
                const SizedBox(height: 12),

                // Search field with compact premium container styling
                Container(
                  key: _searchKey,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        searchQuery = val.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search premium listings...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF0F172A),
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF0F172A),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Premium Hero Promotion Banner Card (Compact Layout)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'EXCLUSIVE OFFERS',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Verified Only',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Find Your Dream Sanctuary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Explore premium properties with fully integrated smart features.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Category section
                CategorySection(
                  onCategorySelected: (cat) {
                    setState(() {
                      selectedCategory = cat;
                    });
                  },
                ),
                const SizedBox(height: 8),

                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text(
                    'Featured Properties',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Quick Actions Grid ─────────────────────────────
                Container(
                  key: _quickActionsKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 10),
                        child: Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      _buildQuickActions(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text(
                    'Featured Properties',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                FeaturedPropertySection(
                  searchQuery: searchQuery,
                  category: selectedCategory,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() => currentIndex = index);
          
          switch (index) {
            case 0:
              break;
            case 1:
              context.push('/search/favorites');
              break;
            case 2:
              context.push('/conversations');
              break;
            case 3:
              context.push('/profile');
              break;
          }
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.account_balance_wallet_rounded,
        label: 'My Wallet',
        color: const Color(0xFF6366F1),
        onTap: () => context.push('/wallet'),
      ),
      _QuickAction(
        icon: Icons.home_work_rounded,
        label: 'My Rentals',
        color: const Color(0xFF10B981),
        onTap: () => context.push('/my-rentals'),
      ),
      _QuickAction(
        icon: Icons.draw_rounded,
        label: 'Agreements',
        color: const Color(0xFF0F172A),
        onTap: () => context.push('/my-rentals'),
      ),
      _QuickAction(
        icon: Icons.verified_user_rounded,
        label: 'Verify ID',
        color: const Color(0xFFF59E0B),
        onTap: () => context.push('/verification'),
      ),
      _QuickAction(
        icon: Icons.search_rounded,
        label: 'Search',
        color: const Color(0xFF0EA5E9),
        onTap: () => context.push('/search'),
      ),
      _QuickAction(
        icon: Icons.favorite_rounded,
        label: 'Saved',
        color: const Color(0xFFEF4444),
        onTap: () => context.push('/search/favorites'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: a.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.icon, color: a.color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  a.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showHelpSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Tenant App Guide', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._tenantHelpItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(item.$1, color: item.$3, size: 18)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(item.$4, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4)),
                  ],
                )),
              ],
            ),
          )),
        ],
      ),
    ),
  );
}

const _tenantHelpItems = [
  (Icons.search_rounded, 'Search Properties', Color(0xFF6366F1), 'Browse and filter thousands of verified property listings by location, price, and type.'),
  (Icons.favorite_outlined, 'Save Favourites', Color(0xFFEF4444), 'Tap the heart icon on any property to save it to your Saved list.'),
  (Icons.account_balance_wallet_outlined, 'Wallet & Payments', Color(0xFF10B981), 'Top up your wallet and pay rent securely through our escrow system.'),
  (Icons.verified_user_outlined, 'KYC Verification', Color(0xFFF59E0B), 'Complete identity verification to unlock payments and rental agreements.'),
  (Icons.chat_bubble_outline, 'Message Landlords', Color(0xFF0EA5E9), 'Directly message property owners from any listing page.'),
  (Icons.smart_toy_rounded, 'AI Assistant', Color(0xFF8B5CF6), 'Get instant answers about properties, pricing, and the rental process.'),
  (Icons.draw_rounded, 'Tenancy Agreement', Color(0xFF0F172A), 'Sign your digital rental agreement safely within the app.'),
  (Icons.support_agent_rounded, 'Customer Support', Color(0xFF64748B), 'Raise tickets or chat with our live support team anytime.'),
];

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
