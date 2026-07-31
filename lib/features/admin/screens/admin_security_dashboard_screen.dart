import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

class AdminSecurityDashboardScreen extends StatefulWidget {
  const AdminSecurityDashboardScreen({super.key});

  @override
  State<AdminSecurityDashboardScreen> createState() => _AdminSecurityDashboardScreenState();
}

class _AdminSecurityDashboardScreenState extends State<AdminSecurityDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSimulating = false;

  final List<String> _attackTypes = [
    'Brute Force Login Attempt',
    'SQL Injection Detected',
    'DDoS Attack Warning',
    'Unauthorized API Access',
    'Privilege Escalation Attempt',
    'Suspicious IP Login',
  ];

  final List<String> _severities = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  Future<void> _simulateAttack() async {
    setState(() => _isSimulating = true);
    
    try {
      final random = Random();
      final attackType = _attackTypes[random.nextInt(_attackTypes.length)];
      final severity = _severities[random.nextInt(_severities.length)];

      // 1. Add to Firestore
      await _firestore.collection('security_alerts').add({
        'type': attackType,
        'severity': severity,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Unresolved',
        'ip_address': '${random.nextInt(255)}.${random.nextInt(255)}.${random.nextInt(255)}.${random.nextInt(255)}',
      });

      // 2. Send OneSignal Notification
      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      final restApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

      if (appId != null && restApiKey != null) {
        final url = Uri.parse('https://onesignal.com/api/v1/notifications');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic $restApiKey',
          },
          body: jsonEncode({
            'app_id': appId,
            'included_segments': ['Total Subscriptions'],
            'headings': {'en': 'Security Alert: $severity Severity'},
            'contents': {'en': 'Detected $attackType on the platform. Please review the security dashboard.'},
          }),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attack simulated and notification sent successfully.')),
            );
          }
        } else {
          debugPrint('OneSignal error: ${response.body}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attack simulated but failed to send push notification.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Missing OneSignal keys in .env')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error simulating attack: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSimulating = false);
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return Colors.red.shade900;
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orange;
      case 'Low':
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Security & Attack Logs',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('security_alerts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppLoader());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading alerts: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security_rounded, size: 80, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'System Secure',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No active attacks or threats detected.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final alerts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final data = alerts[index].data() as Map<String, dynamic>;
              final type = data['type'] ?? 'Unknown Attack';
              final severity = data['severity'] ?? 'Medium';
              final ip = data['ip_address'] ?? 'Unknown IP';
              final timestamp = data['timestamp'] as Timestamp?;
              final dateStr = timestamp != null
                  ? DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())
                  : 'Just now';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _getSeverityColor(severity).withOpacity(0.1),
                    child: Icon(Icons.warning_amber_rounded, color: _getSeverityColor(severity)),
                  ),
                  title: Text(
                    type,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Source IP: $ip', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(severity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSimulating ? null : _simulateAttack,
        backgroundColor: Colors.redAccent.shade700,
        icon: _isSimulating
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.bug_report, color: Colors.white),
        label: Text(
          _isSimulating ? 'Simulating...' : 'Simulate Attack',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
