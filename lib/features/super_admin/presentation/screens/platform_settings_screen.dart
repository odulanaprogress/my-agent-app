import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/super_admin_provider.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

class PlatformSettingsScreen extends ConsumerStatefulWidget {
  const PlatformSettingsScreen({super.key});

  @override
  ConsumerState<PlatformSettingsScreen> createState() => _PlatformSettingsScreenState();
}

class _PlatformSettingsScreenState extends ConsumerState<PlatformSettingsScreen> {
  double _commissionRate = 5.0;
  bool _maintenanceMode = false;
  bool _allowInstantWithdrawals = true;
  int _escrowHandshakeExpiryDays = 7;
  bool _initialized = false;
  bool _saving = false;

  void _initFromData(Map<String, dynamic> data) {
    if (_initialized) return;
    _commissionRate = (data['commissionRate'] as num?)?.toDouble() ?? 5.0;
    _maintenanceMode = data['maintenanceMode'] == true;
    _allowInstantWithdrawals = data['allowInstantWithdrawals'] ?? true;
    _escrowHandshakeExpiryDays = (data['escrowHandshakeExpiryDays'] as num?)?.toInt() ?? 7;
    _initialized = true;
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser;
    final repo = ref.read(superAdminRepositoryProvider);

    try {
      await repo.updatePlatformSettings({
        'commissionRate': _commissionRate,
        'maintenanceMode': _maintenanceMode,
        'allowInstantWithdrawals': _allowInstantWithdrawals,
        'escrowHandshakeExpiryDays': _escrowHandshakeExpiryDays,
      }, actorEmail: user?.email ?? 'super_admin');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Platform settings updated and logged successfully!'),
          backgroundColor: Color(0xFF0F172A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update settings: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(platformSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Platform Governance & Settings'),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: AppLoader(size: 32)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading settings: $err', textAlign: TextAlign.center),
          ),
        ),
        data: (data) {
          _initFromData(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_maintenanceMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Platform Maintenance Mode is ACTIVE. Regular marketplace operations are restricted.',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Commission Rate Card
                _buildCard(
                  title: 'Escrow Platform Commission',
                  subtitle: 'Percentage retained by AGENT on rental transactions',
                  icon: Icons.percent_rounded,
                  iconColor: const Color(0xFF10B981),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Commission Rate:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${_commissionRate.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _commissionRate,
                        min: 1.0,
                        max: 15.0,
                        divisions: 28,
                        activeColor: const Color(0xFF0F172A),
                        label: '${_commissionRate.toStringAsFixed(1)}%',
                        onChanged: (val) => setState(() => _commissionRate = val),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Example on ₦1,000,000 rent: Landlord receives ₦${((100 - _commissionRate) * 10000).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}, AGENT earns ₦${(_commissionRate * 10000).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // System Toggles Card
                _buildCard(
                  title: 'System Operational Controls',
                  subtitle: 'High-level emergency flags and settlement policies',
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFF6366F1),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Temporarily lock out public transactions for upgrades'),
                        value: _maintenanceMode,
                        onChanged: (val) => setState(() => _maintenanceMode = val),
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow Instant Bank Payouts', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Permit automated landlord wallet withdrawals via Flutterwave'),
                        value: _allowInstantWithdrawals,
                        onChanged: (val) => setState(() => _allowInstantWithdrawals = val),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Handshake Expiry Window', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text('Days before unconfirmed escrow enters dispute', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          DropdownButton<int>(
                            value: _escrowHandshakeExpiryDays,
                            items: [3, 5, 7, 14, 30]
                                .map((d) => DropdownMenuItem(value: d, child: Text('$d Days')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _escrowHandshakeExpiryDays = v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saving ? null : _saveSettings,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Save Platform Parameters',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
