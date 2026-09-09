import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/super_admin_provider.dart';
import '../widgets/audit_log_tile.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('System Audit Logs'),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('ALL', 'All Events'),
                  const SizedBox(width: 8),
                  _filterChip('SETTINGS', 'Settings Changes'),
                  const SizedBox(width: 8),
                  _filterChip('ROLE', 'Role Modifications'),
                  const SizedBox(width: 8),
                  _filterChip('AUTH', 'Security & Access'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Logs List
          Expanded(
            child: auditLogsAsync.when(
              loading: () => const Center(child: AppLoader(size: 32)),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load audit logs: $err'),
                ),
              ),
              data: (logs) {
                final filtered = logs.where((log) {
                  if (_selectedFilter == 'ALL') return true;
                  final act = (log['action'] ?? '').toString().toUpperCase();
                  return act.contains(_selectedFilter);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No audit logs recorded yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return AuditLogTile(
                      action: log['action'] ?? 'UNKNOWN_ACTION',
                      details: log['details'] ?? 'No details provided',
                      actorEmail: log['actorEmail'] ?? 'system',
                      timestamp: log['timestamp'],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }
}
