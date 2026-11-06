import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/contact_support_dialog.dart';

import '../../../auth/presentation/providers/current_user_provider.dart';

class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  ConsumerState<PrivacySecurityScreen> createState() =>
      _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends ConsumerState<PrivacySecurityScreen> {
  bool _biometricsEnabled = false;
  bool _analyticsConsent = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
        _analyticsConsent = prefs.getBool('analytics_consent') ?? true;
      });
    }
  }

  Future<void> _toggleBiometrics(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', val);
    setState(() => _biometricsEnabled = val);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          val ? 'Biometric login enabled' : 'Biometric login disabled',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email found for this account.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email ✉️'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset email: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temporary cache and media cleared successfully! 🧹'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing cache: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Privacy & Security',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── SECURITY SECTION ──
          _sectionHeader('ACCOUNT SECURITY', Icons.security_rounded),
          _buildCard([
            _tile(
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFF4A43EB),
              title: 'Biometric Login',
              subtitle: 'Use fingerprint or face recognition',
              trailing: Switch.adaptive(
                value: _biometricsEnabled,
                activeThumbColor: const Color(0xFF4A43EB),
                onChanged: _toggleBiometrics,
              ),
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.lock_reset_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: 'Change Password',
              subtitle: 'Send reset link to ${user?.email ?? "your email"}',
              trailing: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
              onTap: _sendPasswordReset,
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF10B981),
              title: 'Session & Data Encryption',
              subtitle: 'End-to-end 256-bit AES encryption active',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── PRIVACY & COMPLIANCE SECTION ──
          _sectionHeader('PRIVACY & NDPR COMPLIANCE', Icons.policy_rounded),
          _buildCard([
            _tile(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFF6366F1),
              title: 'Privacy Policy',
              subtitle: 'NDPR compliant data processing notice',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => context.push('/privacy'),
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.gavel_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Terms of Service',
              subtitle: 'Escrow payment rules & rental terms',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => _showTermsDialog(),
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.analytics_outlined,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Anonymous Usage Analytics',
              subtitle: 'Help improve app performance & speed',
              trailing: Switch.adaptive(
                value: _analyticsConsent,
                activeThumbColor: const Color(0xFF4A43EB),
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('analytics_consent', val);
                  setState(() => _analyticsConsent = val);
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── PERMISSIONS SECTION ──
          _sectionHeader('DEVICE PERMISSIONS', Icons.perm_device_information_rounded),
          _buildCard([
            _tile(
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFFEF4444),
              title: 'Location Services',
              subtitle: 'Used solely for displaying property coordinates',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => openAppSettings(),
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.camera_alt_outlined,
              iconColor: const Color(0xFF0F172A),
              title: 'Camera & Gallery',
              subtitle: 'For KYC verification & property photos',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => openAppSettings(),
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.mic_none_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Microphone & Audio',
              subtitle: 'For encrypted voice calls & audio notes',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => openAppSettings(),
            ),
          ]),

          const SizedBox(height: 24),

          // ── STORAGE & DATA MANAGEMENT ──
          _sectionHeader('STORAGE & DATA MANAGEMENT', Icons.cleaning_services_rounded),
          _buildCard([
            _tile(
              icon: Icons.cleaning_services_outlined,
              iconColor: const Color(0xFF64748B),
              title: 'Clear Cached Media',
              subtitle: 'Frees up storage space on your device',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: _clearCache,
            ),
          ]),

          const SizedBox(height: 24),

          // ── CONTACT & DATA PROTECTION OFFICER ──
          _sectionHeader('CONTACT & DATA PROTECTION OFFICER', Icons.contact_mail_rounded),
          _buildCard([
            _tile(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Telephone Lines',
              subtitle: '08107416745 • 08131154171',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => ContactSupportDialog.show(context),
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.email_outlined,
              iconColor: const Color(0xFF4A43EB),
              title: 'Support & DPO Email',
              subtitle: 'agentcustomercare@gmail.com\nadmin@agentmobiletech.com',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => ContactSupportDialog.show(context),
            ),
            const Divider(height: 1, indent: 56),
            _tile(
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFFEF4444),
              title: 'Registered Office',
              subtitle: 'Agent Platform Ltd, Lagos, Nigeria',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              onTap: () => ContactSupportDialog.show(context),
            ),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          height: 1.3,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFF4A43EB)),
            SizedBox(width: 10),
            Text('Terms of Service', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            '1. Escrow Protection: Rent payments are held in licensed CBN/NDIC insured escrow accounts until the tenant verifies the property and accepts keys.\n\n'
            '2. Identity Verification: All users must complete KYC verification before executing digital tenancy agreements or rental transactions.\n\n'
            '3. Direct Communication: Landlords and tenants may interact directly via encrypted audio calls and in-app chat.\n\n'
            '4. Property Authenticity: Listings undergo automated coordinate checks and admin verification before publication.\n\n'
            '5. Contact & Inquiries: For help or questions, call 08107416745, 08131154171 or email agentcustomercare@gmail.com (Agent Platform Ltd, Lagos, Nigeria).',
            style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A43EB))),
          ),
        ],
      ),
    );
  }
}
