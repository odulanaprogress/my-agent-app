import 'package:flutter/material.dart';

class AgreementStatusBadge extends StatelessWidget {
  const AgreementStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
