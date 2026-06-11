import 'package:flutter/material.dart';

import '../../domain/escrow_status.dart';

class EscrowStatusBadge extends StatelessWidget {
  const EscrowStatusBadge({super.key, required this.status});

  final EscrowStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      EscrowStatus.held => (
        Colors.orange.withValues(alpha: 0.12),
        Colors.orange,
      ),
      EscrowStatus.released => (
        Colors.green.withValues(alpha: 0.12),
        Colors.green,
      ),
      EscrowStatus.refunded => (
        Colors.blue.withValues(alpha: 0.12),
        Colors.blue,
      ),
      EscrowStatus.failed => (Colors.red.withValues(alpha: 0.12), Colors.red),
      EscrowStatus.cancelled => (
        Colors.grey.withValues(alpha: 0.2),
        Colors.grey,
      ),
      EscrowStatus.pending => (
        Colors.black.withValues(alpha: 0.08),
        Colors.black87,
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
