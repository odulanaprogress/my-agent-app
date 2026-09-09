import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/super_admin_provider.dart';
import '../widgets/audit_log_tile.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  void _showRoleManagementDialog(BuildContext context) {
    final emailController = TextEditingController();
    String selectedRole = 'admin';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: Color(0xFF0F172A)),
              SizedBox(width: 10),
              Text('Assign Admin Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the email address of the registered user you want to grant administrative permissions to.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'User Email Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Target Role',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Operational Admin')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                  DropdownMenuItem(value: 'tenant', child: Text('Demote to Tenant')),
                  DropdownMenuItem(value: 'landlord', child: Text('Demote to Landlord')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final email = emailController.text.trim().toLowerCase();
                if (email.isEmpty) return;

                Navigator.of(dialogCtx).pop();

                try {
                  final snap = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();

                  if (snap.docs.isEmpty) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No registered account found with email: $email'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                    return;
                  }

                  final targetUser = snap.docs.first;
                  final currentAdmin = FirebaseAuth.instance.currentUser;
                  final repo = ref.read(superAdminRepositoryProvider);

                  await repo.setUserRole(
                    targetUid: targetUser.id,
                    newRole: selectedRole,
                    actorEmail: currentAdmin?.email ?? 'super_admin',
                    targetEmail: email,
                  );

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Role updated to $selectedRole for $email'),
                      backgroundColor: const Color(0xFF0F172A),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.red.shade700),
                  );
                }
              },
              child: const Text('Confirm Role Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    final auditLogsAsync = ref.watch(auditLogsProvider);
    final adminsAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Super Admin Console'),
        centerTitle: false,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Operational Admin Dashboard',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => context.go('/admin'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(platformSettingsProvider);
              ref.invalidate(auditLogsProvider);
              ref.invalidate(adminUsersProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'GOVERNANCE & PROTOCOL',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Platform Control Tower',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage fee rates, system emergency toggles, administrative privileges & audit logs.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Cards
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          title: 'Platform Fee',
                          value: settingsAsync.when(
                            data: (d) => '${((d['commissionRate'] ?? 5.0) as num).toStringAsFixed(1)}%',
                            loading: () => '...',
                            error: (e, s) => '5.0%',
                          ),
                          subtitle: 'Retained on Rent',
                          icon: Icons.percent_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _statCard(
                          title: 'Active Admins',
                          value: adminsAsync.when(
                            data: (list) => '${list.length}',
                            loading: () => '...',
                            error: (e, s) => '1',
                          ),
                          subtitle: 'Authorized Staff',
                          icon: Icons.admin_panel_settings_rounded,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions Section
                  const Text(
                    'Administrative Governance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 14),

                  _actionTile(
                    title: 'Platform Settings & Fees',
                    subtitle: 'Modify commission rates, escrow expiry & maintenance flags',
                    icon: Icons.tune_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push('/super-admin/settings'),
                  ),
                  const SizedBox(height: 12),

                  _actionTile(
                    title: 'System Audit Logs',
                    subtitle: 'Inspect immutable records of all administrative actions & events',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/super-admin/audit-logs'),
                  ),
                  const SizedBox(height: 12),

                  _actionTile(
                    title: 'Staff Role Management',
                    subtitle: 'Promote users to Admin status or manage staff access levels',
                    icon: Icons.badge_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => _showRoleManagementDialog(context),
                  ),
                  const SizedBox(height: 12),

                  _actionTile(
                    title: 'Customer 360° Diagnostic Console',
                    subtitle: 'Inspect any customer by ID/Email: escrows, PIN recovery, wallet & error logs',
                    icon: Icons.person_search_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: () => context.push('/admin/customer-360'),
                  ),
                  const SizedBox(height: 12),

                  _actionTile(
                    title: 'Operational Admin Dashboard',
                    subtitle: 'Manage property approvals, KYC identity verifications & support tickets',
                    icon: Icons.dashboard_customize_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.go('/admin'),
                  ),
                  const SizedBox(height: 28),

                  // Recent Audit Logs Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Audit Records',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextButton(
                        onPressed: () => context.push('/super-admin/audit-logs'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  auditLogsAsync.when(
                    loading: () => const Center(child: AppLoader(size: 24)),
                    error: (err, _) => Text('Could not load audit stream: $err'),
                    data: (logs) {
                      if (logs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Text('No system audit events recorded yet.'),
                          ),
                        );
                      }

                      final recent = logs.take(3).toList();
                      return Column(
                        children: recent.map((l) {
                          return AuditLogTile(
                            action: l['action'] ?? 'EVENT',
                            details: l['details'] ?? '',
                            actorEmail: l['actorEmail'] ?? 'system',
                            timestamp: l['timestamp'],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
