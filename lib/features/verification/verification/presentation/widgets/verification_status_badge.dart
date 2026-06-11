import 'package:flutter/material.dart';

import '../../domain/verification_status.dart';

class VerificationStatusBadge extends StatelessWidget {
  const VerificationStatusBadge({super.key, required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      VerificationStatus.pending => (
        Colors.orange.withValues(alpha: 0.12),
        Colors.orange,
      ),
      VerificationStatus.approved => (
        Colors.green.withValues(alpha: 0.12),
        Colors.green,
      ),
      VerificationStatus.rejected => (
        Colors.red.withValues(alpha: 0.12),
        Colors.red,
      ),
      VerificationStatus.expired => (
        Colors.grey.withValues(alpha: 0.2),
        Colors.grey,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
