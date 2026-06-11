import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  AdminAnalyticsScreen({super.key});

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> fetchAnalytics() async {
    final usersSnapshot = await firestore.collection('users').get();
    final propertiesSnapshot = await firestore.collection('properties').get();
    final pendingSnapshot = await firestore
        .collection('properties')
        .where('approvalStatus', isEqualTo: 'pending')
        .get();
    final transactionsSnapshot = await firestore.collection('transactions').get();

    double totalRevenue = 0;
    for (final doc in transactionsSnapshot.docs) {
      final data = doc.data();
      totalRevenue += (data['amount'] ?? 0).toDouble();
    }

    return {
      'users': usersSnapshot.docs.length,
      'properties': propertiesSnapshot.docs.length,
      'pending': pendingSnapshot.docs.length,
      'transactions': transactionsSnapshot.docs.length,
      'revenue': totalRevenue,
    };
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
          'Platform Analytics',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Failed to load analytics',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
            );
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Platform Summary Title
                const Text(
                  'Financial Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                // Large Revenue Card
                _buildAnalyticsCard(
                  title: 'Platform Gross Revenue',
                  value: '₦${data['revenue'].toStringAsFixed(0)}',
                  subtitle: 'Total processed payments through AGENT gateway',
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF10B981),
                  isFullWidth: true,
                ),
                const SizedBox(height: 24),

                const Text(
                  'Resource Metrics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                // Grid for items
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                    _buildAnalyticsCard(
                      title: 'Registered Users',
                      value: '${data['users']}',
                      subtitle: 'Active user accounts',
                      icon: Icons.people_outline_rounded,
                      color: Colors.indigo,
                    ),
                    _buildAnalyticsCard(
                      title: 'Total Properties',
                      value: '${data['properties']}',
                      subtitle: 'Listings uploaded',
                      icon: Icons.home_work_outlined,
                      color: Colors.teal,
                    ),
                    _buildAnalyticsCard(
                      title: 'Pending Approvals',
                      value: '${data['pending']}',
                      subtitle: 'Awaiting moderation',
                      icon: Icons.hourglass_empty_rounded,
                      color: Colors.orange,
                    ),
                    _buildAnalyticsCard(
                      title: 'Revenue',
                      value: '₦${data['revenue'].toStringAsFixed(0)}',
                      subtitle: 'Escrow operations',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: isFullWidth ? 32 : 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
