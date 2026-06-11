import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../admin/screens/admin_support_tickets_screen.dart';
import '../../../admin/screens/admin_behavior_logs_screen.dart';
import '../../../admin/screens/customer_support_dashboard_screen.dart';
import 'tenant_dashboard_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _usersCount = 0;
  int _propertiesCount = 0;
  int _pendingPropertiesCount = 0;
  int _pendingVerificationsCount = 0;
  double _totalRevenue = 0.0;
  bool _loading = true;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initRealtimeMetrics();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _initRealtimeMetrics() {
    final fs = FirebaseFirestore.instance;

    // Listen to users for total count and pending KYC verifications
    _subscriptions.add(
      fs.collection('users').snapshots().listen((snap) {
        if (!mounted) return;
        int pendingKYC = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['verificationStatus'] == 'pending') {
            pendingKYC++;
          }
        }
        setState(() {
          _usersCount = snap.docs.length;
          _pendingVerificationsCount = pendingKYC;
          _loading = false;
        });
      }),
    );

    // Listen to properties for total count and pending approvals
    _subscriptions.add(
      fs.collection('properties').snapshots().listen((snap) {
        if (!mounted) return;
        int pendingApp = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['approvalStatus'] == 'pending') {
            pendingApp++;
          }
        }
        setState(() {
          _propertiesCount = snap.docs.length;
          _pendingPropertiesCount = pendingApp;
          _loading = false;
        });
      }),
    );

    // Listen to transactions to dynamically calculate platform revenue in real-time
    _subscriptions.add(
      fs.collection('transactions').snapshots().listen((snap) {
        if (!mounted) return;
        double revenue = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          revenue += (data['amount'] ?? 0).toDouble();
        }
        setState(() {
          _totalRevenue = revenue;
          _loading = false;
        });
      }),
    );
  }

  Future<void> _confirmLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await ref.read(authNotifierProvider.notifier).logout();
      if (!mounted) return;
      context.go('/login');
    }
  }

  void _openTenantPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.preview_rounded, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    const Text(
                      'Live Tenant Preview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(
                child: TenantDashboardScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Admin Control',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // Welcome Hero Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back,',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.fullName ?? 'Administrator',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'SYSTEM LEVEL: SUPER ADMIN',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openTenantPreview,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.preview_rounded, size: 16),
                            label: const Text('Tenant View Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Metrics Title
                const Text(
                  'Platform Analytics (Realtime)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                // Metrics Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.35,
                  children: [
                    _buildMetricCard(
                      title: 'Total Users',
                      value: '$_usersCount',
                      icon: Icons.people_outline_rounded,
                      color: Colors.indigo,
                    ),
                    _buildMetricCard(
                      title: 'Properties',
                      value: '$_propertiesCount',
                      icon: Icons.holiday_village_outlined,
                      color: Colors.teal,
                    ),
                    _buildMetricCard(
                      title: 'Pending Approvals',
                      value: '$_pendingPropertiesCount',
                      icon: Icons.rate_review_outlined,
                      color: Colors.orange,
                      showBadge: _pendingPropertiesCount > 0,
                    ),
                    _buildMetricCard(
                      title: 'Revenue',
                      value: '₦${_totalRevenue.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.green,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Quick Navigation / Controls
                const Text(
                  'Administrative Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                _buildAdminActionTile(
                  title: 'Property Approvals',
                  subtitle: 'Review & approve premium property uploads',
                  icon: Icons.fact_check_outlined,
                  color: Colors.amber.shade800,
                  badgeCount: _pendingPropertiesCount,
                  onTap: () => context.push('/admin/property-approvals'),
                ),
                const SizedBox(height: 12),

                _buildAdminActionTile(
                  title: 'Verification Requests',
                  subtitle: 'Validate user KYC documents & verified status',
                  icon: Icons.admin_panel_settings_outlined,
                  color: Colors.indigo.shade700,
                  badgeCount: _pendingVerificationsCount,
                  onTap: () => context.push('/admin/verifications'),
                ),
                const SizedBox(height: 12),

                _buildAdminActionTile(
                  title: 'Manage Listings',
                  subtitle: 'View, search, and delete all property listings',
                  icon: Icons.holiday_village_outlined,
                  color: Colors.redAccent.shade700,
                  badgeCount: 0,
                  onTap: () => context.push('/admin/properties'),
                ),
                const SizedBox(height: 12),

                _buildAdminActionTile(
                  title: 'Financial Analytics & Revenue',
                  subtitle: 'Overview of platform transaction history',
                  icon: Icons.analytics_outlined,
                  color: Colors.green.shade700,
                  badgeCount: 0,
                  onTap: () => context.push('/admin/analytics'),
                ),
                const SizedBox(height: 12),

                _buildAdminActionTile(
                  title: 'Support Tickets',
                  subtitle: 'View & reply to user inquiries & complaints',
                  icon: Icons.support_agent_outlined,
                  color: Colors.purple.shade700,
                  badgeCount: 0,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminSupportTicketsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildAdminActionTile(
                  title: 'User Behavior Logs',
                  subtitle: 'Track login, search, payment & user actions',
                  icon: Icons.analytics_rounded,
                  color: Colors.deepPurple,
                  badgeCount: 0,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminBehaviorLogsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildAdminActionTile(
                  title: 'Customer Support Portal',
                  subtitle: 'View & manage customer support agent dashboard',
                  icon: Icons.support_agent_rounded,
                  color: const Color(0xFF6366F1),
                  badgeCount: 0,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerSupportDashboardScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool showBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$badgeCount pending',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade300,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
