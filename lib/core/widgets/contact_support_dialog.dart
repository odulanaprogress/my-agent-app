import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../../features/support/support_inquiry_screen.dart';
import '../../features/ai/screens/ai_chat_screen.dart';

class ContactSupportDialog extends StatelessWidget {
  const ContactSupportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContactSupportDialog(),
    );
  }

  Future<void> _makeCall(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        _copyToClipboard(context, phone, 'Phone number copied to clipboard');
      }
    }
  }

  Future<void> _sendEmail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        _copyToClipboard(context, email, 'Email copied to clipboard');
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header with Logo
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A43EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/logo.png',
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.headset_mic_rounded,
                        color: Color(0xFF4A43EB),
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact & Support',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'AGENT • Beyond Housing',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── TELEPHONE NUMBERS ──
            _sectionTitle('PHONE LINES (CALL / WHATSAPP)'),
            const SizedBox(height: 8),
            _contactCard(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF10B981),
              title: AppConstants.supportPhone1,
              subtitle: 'Official Support & Inquiries line',
              actionLabel: 'Call',
              onAction: () => _makeCall(context, AppConstants.supportPhone1),
              onCopy: () => _copyToClipboard(
                context,
                AppConstants.supportPhone1,
                'Phone number copied',
              ),
            ),
            const SizedBox(height: 10),
            _contactCard(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF10B981),
              title: AppConstants.supportPhone2,
              subtitle: 'Alternative Support & Help desk',
              actionLabel: 'Call',
              onAction: () => _makeCall(context, AppConstants.supportPhone2),
              onCopy: () => _copyToClipboard(
                context,
                AppConstants.supportPhone2,
                'Phone number copied',
              ),
            ),
            const SizedBox(height: 20),

            // ── EMAIL ADDRESSES ──
            _sectionTitle('OFFICIAL EMAIL ADDRESSES'),
            const SizedBox(height: 8),
            _contactCard(
              icon: Icons.mail_outline_rounded,
              iconColor: const Color(0xFF4A43EB),
              title: AppConstants.customerCareEmail,
              subtitle: 'Customer Support & Inquiries',
              actionLabel: 'Email',
              onAction: () => _sendEmail(context, AppConstants.customerCareEmail),
              onCopy: () => _copyToClipboard(
                context,
                AppConstants.customerCareEmail,
                'Email copied',
              ),
            ),
            const SizedBox(height: 10),
            _contactCard(
              icon: Icons.admin_panel_settings_outlined,
              iconColor: const Color(0xFF6366F1),
              title: AppConstants.adminSupportEmail,
              subtitle: 'Admin Escalations & Support',
              actionLabel: 'Email',
              onAction: () => _sendEmail(context, AppConstants.adminSupportEmail),
              onCopy: () => _copyToClipboard(
                context,
                AppConstants.adminSupportEmail,
                'Email copied',
              ),
            ),
            const SizedBox(height: 20),

            // ── PHYSICAL / REGISTERED OFFICE ADDRESS ──
            _sectionTitle('REGISTERED OFFICE ADDRESS'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.contactAddress,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nationwide coverage across Nigeria',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                    tooltip: 'Copy address',
                    onPressed: () => _copyToClipboard(
                      context,
                      AppConstants.contactAddress,
                      'Address copied',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── QUICK IN-APP ACTIONS ──
            _sectionTitle('IN-APP SUPPORT OPTIONS'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A43EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportInquiryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: const Text(
                      'Live Ticket Chat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A43EB),
                      side: const BorderSide(color: Color(0xFF4A43EB), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AIChatScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.smart_toy_rounded, size: 18),
                    label: const Text(
                      'AI Assistant',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 17, color: Colors.grey),
            tooltip: 'Copy',
            onPressed: onCopy,
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

