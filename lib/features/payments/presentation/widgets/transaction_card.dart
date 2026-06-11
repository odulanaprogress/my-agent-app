import 'package:flutter/material.dart';

import '../../domain/escrow_status.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.amount,
    required this.status,
  });

  final int amount;
  final EscrowStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EscrowStatus.held => Colors.orange,
      EscrowStatus.released => Colors.green,
      EscrowStatus.refunded => Colors.blue,
      EscrowStatus.failed => Colors.red,
      EscrowStatus.cancelled => Colors.grey,
      EscrowStatus.pending => Colors.black54,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₦$amount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Status: ${status.name}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
