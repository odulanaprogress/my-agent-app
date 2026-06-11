import 'package:flutter/material.dart';

class AuditLogTile extends StatelessWidget {
  const AuditLogTile({
    super.key,
    required this.action,
    required this.actor,
    this.timestamp,
  });

  final String action;
  final String actor;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history_outlined),
      title: Text(action),
      subtitle: Text('$actor${timestamp != null ? ' • $timestamp' : ''}'),
    );
  }
}
