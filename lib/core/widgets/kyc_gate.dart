import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/verification/verification/providers/verification_provider.dart';
import '../../features/verification/verification/domain/verification_status.dart';

/// Reusable KYC gate.
///
/// Call [KycGate.require] before any gated action (upload, pay, sign).
/// Returns `true` if the user is verified and may proceed.
/// Returns `false` (and shows an explanatory bottom-sheet) otherwise.
class KycGate {
  KycGate._();

  static Future<bool> require(BuildContext context, WidgetRef ref) async {
    final state = ref.read(verificationStateProvider);

    if (state.status == VerificationStatus.approved) return true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KycGateSheet(status: state.status),
    );
    return false;
  }
}

class _KycGateSheet extends StatelessWidget {
  final VerificationStatus status;
  const _KycGateSheet({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPending = status == VerificationStatus.pending;
    final isRejected = status == VerificationStatus.rejected;

    final Color accent = isPending
        ? const Color(0xFFF59E0B)
        : isRejected
            ? const Color(0xFFEF4444)
            : const Color(0xFF6366F1);

    final IconData icon = isPending
        ? Icons.hourglass_top_rounded
        : isRejected
            ? Icons.cancel_rounded
            : Icons.verified_user_rounded;

    final String title = isPending
        ? 'Verification Under Review'
        : isRejected
            ? 'Verification Rejected'
            : 'Identity Verification Required';

    final String body = isPending
        ? 'Your KYC documents are being reviewed by our team. This usually takes 1–2 business days. You\'ll be notified once approved before you can proceed.'
        : isRejected
            ? 'Your KYC submission was not approved. Please re-submit with clear, valid documents to unlock all platform features.'
            : 'To protect all users on this platform, you must complete identity verification (KYC) before uploading properties or making payments. Browsing remains free.';

    final String btnLabel = isPending
        ? 'View Verification Status'
        : isRejected
            ? 'Re-submit Documents'
            : 'Start Verification Now';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 36),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Body
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // CTA
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push(
                  isPending ? '/verification/status' : '/verification',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                btnLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
