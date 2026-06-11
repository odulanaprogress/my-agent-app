import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminBehaviorLogsScreen extends StatefulWidget {
  const AdminBehaviorLogsScreen({super.key});

  @override
  State<AdminBehaviorLogsScreen> createState() =>
      _AdminBehaviorLogsScreenState();
}

class _AdminBehaviorLogsScreenState extends State<AdminBehaviorLogsScreen> {
  String _filterAction = 'all';

  static const _actions = [
    'all',
    'login',
    'logout',
    'property_view',
    'payment_initiated',
    'search',
    'support_ticket_opened',
    'profile_update',
    'verification_submitted',
  ];

  static const _actionColors = <String, Color>{
    'login': Colors.green,
    'logout': Colors.grey,
    'property_view': Colors.blue,
    'payment_initiated': Colors.orange,
    'search': Colors.purple,
    'support_ticket_opened': Colors.red,
    'profile_update': Colors.teal,
    'verification_submitted': Colors.indigo,
  };

  static const _actionIcons = <String, IconData>{
    'login': Icons.login_rounded,
    'logout': Icons.logout_rounded,
    'property_view': Icons.home_work_outlined,
    'payment_initiated': Icons.payment_rounded,
    'search': Icons.search_rounded,
    'support_ticket_opened': Icons.support_agent_outlined,
    'profile_update': Icons.person_outline_rounded,
    'verification_submitted': Icons.verified_outlined,
  };

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('user_behavior_logs')
        .orderBy('timestamp', descending: true)
        .limit(100);

    if (_filterAction != 'all') {
      query = FirebaseFirestore.instance
          .collection('user_behavior_logs')
          .where('action', isEqualTo: _filterAction)
          .orderBy('timestamp', descending: true)
          .limit(100);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF0F172A)),
        title: const Text(
          'User Behavior Logs',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter bar
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _actions.length,
              itemBuilder: (context, i) {
                final action = _actions[i];
                final selected = _filterAction == action;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                  child: FilterChip(
                    label: Text(
                      action == 'all' ? 'All' : action.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterAction = action),
                    selectedColor: const Color(0xFF0F172A),
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No logs found',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final action = data['action'] ?? 'unknown';
                    final description = data['description'] ?? '';
                    final userEmail = data['userEmail'] ?? 'unknown';
                    final timestamp = data['timestamp'];

                    String timeStr = '';
                    if (timestamp is Timestamp) {
                      final dt = timestamp.toDate();
                      timeStr =
                          '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                    }

                    final color = _actionColors[action] ?? Colors.grey;
                    final icon = _actionIcons[action] ?? Icons.info_outline;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (description.toString().isNotEmpty)
                                  Text(
                                    description.toString(),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined,
                                        size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        userEmail.toString(),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
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
}
