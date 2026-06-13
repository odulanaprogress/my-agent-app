import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/privacy_provider.dart';

class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState
    extends ConsumerState<PrivacyConsentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final max = _scrollController.position.maxScrollExtent;
      final pos = _scrollController.position.pixels;
      if (pos >= max - 50 && !_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF0F172A)),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text(
          'Privacy Policy & Consent',
          style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: Column(
        children: [
          // Scroll-to-read hint
          if (!_hasScrolledToBottom)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFEF9C3),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFFCA8A04), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please read the entire policy before accepting.',
                      style: TextStyle(
                          color: Color(0xFFCA8A04),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Policy content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_rounded,
                                color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Privacy Policy',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Effective Date: 13 June 2025  |  Version 2.0',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This Privacy Policy governs how Agent Platform ("Agent", "we", "us", or "our") collects, uses, stores, and protects your personal data. It is designed in compliance with the Nigeria Data Protection Regulation (NDPR) 2019, the General Data Protection Regulation (GDPR) 2018 (EU/EEA users), the Apple App Store Guidelines, and the Google Play Store Developer Programme Policies.',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _section(
                    icon: Icons.person_outline,
                    title: '1. Data Controller',
                    body:
                        'Agent Platform is the Data Controller responsible for your personal data.\n\n'
                        'Data Protection Officer (DPO):\n'
                        'Email: dpo@agentplatform.ng\n'
                        'Address: Lagos, Nigeria\n\n'
                        'For EU/EEA residents, Agent Platform processes your data under Article 6 of the GDPR. Our lawful bases for processing include: your consent, performance of a contract, legal obligation, and our legitimate interests.',
                  ),

                  _section(
                    icon: Icons.storage_outlined,
                    title: '2. Data We Collect',
                    body:
                        'We collect the following categories of data to provide and improve our services:\n\n'
                        '🔵 Identity Data\n'
                        '• Full name, date of birth\n'
                        '• Government-issued ID (NIN, Passport, Driver\'s Licence front and back)\n'
                        '• Selfie / facial image for liveness verification\n\n'
                        '🔵 Contact & Account Data\n'
                        '• Email address, phone number\n'
                        '• Account role (tenant or landlord)\n'
                        '• Profile photo (optional)\n\n'
                        '🔵 Financial Data\n'
                        '• Wallet balance and transaction history\n'
                        '• Escrow transaction records\n'
                        '• Payment method type (card, bank, USSD — stored by Paystack, not us)\n'
                        '• Bank Verification Number (BVN) — required for KYC compliance\n\n'
                        '🔵 Property Data\n'
                        '• Property listings you create, including photos, videos, and descriptions\n'
                        '• Property ownership documents (for landlord KYC)\n'
                        '• Tenancy agreements and digital signatures\n\n'
                        '🔵 Behavioural & Device Data\n'
                        '• Login events (login, logout, method used)\n'
                        '• Property views, saves, and enquiries\n'
                        '• Search queries and filter preferences\n'
                        '• Device model, OS version, app version\n'
                        '• IP address and approximate location\n\n'
                        '🔵 Biometric Data\n'
                        '• Fingerprint / Face ID credentials used for biometric login\n'
                        '• Note: Biometric data is stored ONLY on your device using the platform\'s secure storage. It is never uploaded to our servers.',
                  ),

                  _section(
                    icon: Icons.task_outlined,
                    title: '3. Why We Collect Your Data',
                    body:
                        'We collect your data for the following purposes:\n\n'
                        '✅ Account creation and authentication\n'
                        '✅ Identity verification (KYC) to prevent fraud\n'
                        '✅ Processing rent payments and escrow transactions\n'
                        '✅ Generating tenancy agreements\n'
                        '✅ Sending transaction confirmations and notifications\n'
                        '✅ Improving platform performance and user experience\n'
                        '✅ Complying with Nigerian law, NDPR, EFCC, and FIRS requirements\n'
                        '✅ Preventing money laundering and fraudulent activity\n'
                        '✅ Responding to customer support inquiries\n'
                        '✅ Providing relevant property recommendations (non-advertising)\n\n'
                        'We DO NOT sell your personal data to third parties for advertising or marketing purposes.',
                  ),

                  _section(
                    icon: Icons.share_outlined,
                    title: '4. Who We Share Your Data With',
                    body:
                        'We share your data only when necessary, and only with trusted parties:\n\n'
                        '• Firebase (Google) — Authentication, Firestore database, and cloud storage. Data centres may be located outside Nigeria. Google complies with GDPR Standard Contractual Clauses (SCCs).\n\n'
                        '• Paystack — Payment processing. Only your email and amount are shared; full card or bank details never pass through our servers.\n\n'
                        '• Google Maps / Places API — Property location display. No personally identifiable data is shared.\n\n'
                        '• Regulatory Authorities — We may share data with NITDA, EFCC, or law enforcement if legally required.\n\n'
                        'All third-party partners are contractually bound to protect your data and use it only for the specified purpose.',
                  ),

                  _section(
                    icon: Icons.schedule_outlined,
                    title: '5. Data Retention',
                    body:
                        'We retain your data for the following periods:\n\n'
                        '• Account data: For the duration of your account + 7 years after closure (legal record-keeping)\n'
                        '• KYC documents: 7 years from date of submission (NDPR and AML compliance)\n'
                        '• Transaction records: 7 years (FIRS and tax compliance)\n'
                        '• Tenancy agreements: 7 years from agreement expiry\n'
                        '• Behavioural logs: 12 months rolling\n'
                        '• Device & session data: 90 days\n\n'
                        'After the retention period, data is securely deleted or anonymised.',
                  ),

                  _section(
                    icon: Icons.lock_outlined,
                    title: '6. How We Protect Your Data',
                    body:
                        'We implement industry-standard security measures:\n\n'
                        '🔒 TLS/SSL encryption for all data in transit\n'
                        '🔒 AES-256 encryption for data at rest in Firebase\n'
                        '🔒 Biometric credentials stored in device Secure Enclave only\n'
                        '🔒 Firebase Security Rules to restrict data access\n'
                        '🔒 Role-based access control (tenant, landlord, admin)\n'
                        '🔒 Regular security audits and penetration testing\n'
                        '🔒 Admin access logged and monitored\n\n'
                        'Despite our best efforts, no system is 100% secure. In the event of a data breach, we will notify affected users and NITDA within 72 hours as required by NDPR.',
                  ),

                  _section(
                    icon: Icons.verified_user_outlined,
                    title: '7. Your Rights (NDPR & GDPR)',
                    body:
                        'Under the NDPR and GDPR, you have the following rights:\n\n'
                        '• Right to Access — Request a copy of all data we hold about you.\n'
                        '• Right to Correction — Request correction of inaccurate data.\n'
                        '• Right to Deletion — Request deletion of your account and data (subject to legal retention requirements).\n'
                        '• Right to Portability — Receive your data in a machine-readable format.\n'
                        '• Right to Object — Object to processing based on legitimate interests.\n'
                        '• Right to Restrict Processing — Request we pause processing under certain conditions.\n'
                        '• Right to Withdraw Consent — Withdraw consent at any time; this will not affect prior lawful processing.\n\n'
                        'To exercise any of these rights, contact us at: dpo@agentplatform.ng\n'
                        'We will respond within 30 days as required by NDPR.',
                  ),

                  _section(
                    icon: Icons.child_care_outlined,
                    title: '8. Children\'s Privacy (COPPA / NDPR)',
                    body:
                        'Agent Platform is NOT intended for use by persons under the age of 18.\n\n'
                        'We do not knowingly collect personal data from minors. If you believe a child has provided us with data, please contact dpo@agentplatform.ng immediately and we will delete it within 72 hours.',
                  ),

                  _section(
                    icon: Icons.cookie_outlined,
                    title: '9. Cookies & Tracking',
                    body:
                        'Our mobile application does not use browser cookies. However, we use the following:\n\n'
                        '• Firebase Analytics — anonymised usage statistics (opt-out available in Settings)\n'
                        '• Firebase Crashlytics — crash reporting to improve stability\n'
                        '• SharedPreferences — local storage for your in-app preferences (tour status, theme, etc.)\n\n'
                        'No tracking pixels, ad networks, or cross-app tracking SDKs are used.',
                  ),

                  _section(
                    icon: Icons.public_outlined,
                    title: '10. International Transfers',
                    body:
                        'Your data may be transferred to and stored in countries outside Nigeria (including the United States and EU member states) due to our use of Firebase (Google Cloud).\n\n'
                        'All such transfers are conducted under adequate safeguards including GDPR Standard Contractual Clauses and Google\'s Cloud Data Processing Addendum.\n\n'
                        'For EU/EEA users: You have the right to lodge a complaint with your local Data Protection Authority if you believe your rights have been violated.',
                  ),

                  _section(
                    icon: Icons.update_outlined,
                    title: '11. Policy Updates',
                    body:
                        'We may update this Privacy Policy from time to time. We will notify you of significant changes via:\n'
                        '• In-app notification\n'
                        '• Email to your registered address\n\n'
                        'Continued use of Agent Platform after notification constitutes acceptance of the updated policy.\n\n'
                        'Current version: 2.0\n'
                        'Effective: 13 June 2025',
                  ),

                  _section(
                    icon: Icons.contact_mail_outlined,
                    title: '12. Contact Us',
                    body:
                        'For privacy inquiries, data requests, or complaints:\n\n'
                        '📧 DPO Email: dpo@agentplatform.ng\n'
                        '📧 Support: support@agentplatform.ng\n'
                        '🏢 Agent Platform Ltd, Lagos, Nigeria\n\n'
                        'If you are dissatisfied with our response, you may lodge a complaint with the National Information Technology Development Agency (NITDA) — Nigeria\'s data protection authority — at www.nitda.gov.ng.',
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Accept / Reject bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _accepted,
                      activeColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: _hasScrolledToBottom
                          ? (v) => setState(() => _accepted = v ?? false)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        'I have read and accept this Privacy Policy and the Terms of Service.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasScrolledToBottom
                              ? const Color(0xFF0F172A)
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Accept button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_accepted && _hasScrolledToBottom)
                        ? () async {
                            await ref
                                .read(privacyProvider.notifier)
                                .acceptPrivacy();
                            if (!context.mounted) return;
                            context.go('/onboarding');
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      disabledBackgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      _hasScrolledToBottom
                          ? 'Accept & Continue'
                          : 'Scroll down to accept',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _hasScrolledToBottom
                            ? Colors.white
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Decline
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Decline — Exit App',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF0F172A), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 14),
          Text(
            body,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
