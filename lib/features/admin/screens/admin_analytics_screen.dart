import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _usersCount = 0;
  int _propertiesCount = 0;
  int _pendingCount = 0;
  double _totalRevenue = 0.0;
  bool _loading = true;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initRealtimeAnalytics();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _initRealtimeAnalytics() {
    // 1. Listen to users
    _subscriptions.add(
      _firestore.collection('users').snapshots().listen((snap) {
        if (!mounted) return;
        setState(() {
          _usersCount = snap.docs.length;
          _loading = false;
        });
      }, onError: (err) {
        debugPrint('Error loading users stream: $err');
      }),
    );

    // 2. Listen to properties
    _subscriptions.add(
      _firestore.collection('properties').snapshots().listen((snap) {
        if (!mounted) return;
        int pending = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['approvalStatus'] == 'pending') {
            pending++;
          }
        }
        setState(() {
          _propertiesCount = snap.docs.length;
          _pendingCount = pending;
          _loading = false;
        });
      }, onError: (err) {
        debugPrint('Error loading properties stream: $err');
      }),
    );

    // 3. Listen to transactions (revenue calculation)
    _subscriptions.add(
      _firestore.collection('transactions').snapshots().listen((snap) {
        if (!mounted) return;
        double revenue = 0.0;
        for (final doc in snap.docs) {
          final data = doc.data();
          revenue += (data['amount'] ?? 0).toDouble();
        }
        setState(() {
          _totalRevenue = revenue;
          _loading = false;
        });
      }, onError: (err) {
        debugPrint('Error loading transactions stream: $err');
      }),
    );
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                    value: '₦${_totalRevenue.toStringAsFixed(0)}',
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

                  // Grid for items with improved childAspectRatio to prevent overflows
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.02, // Adjust aspect ratio to prevent vertical layout clippings
                    children: [
                      _buildAnalyticsCard(
                        title: 'Registered Users',
                        value: '$_usersCount',
                        subtitle: 'Active user accounts',
                        icon: Icons.people_outline_rounded,
                        color: Colors.indigo,
                        onTap: () => context.push('/admin/users'),
                      ),
                      _buildAnalyticsCard(
                        title: 'Total Properties',
                        value: '$_propertiesCount',
                        subtitle: 'Listings uploaded',
                        icon: Icons.home_work_outlined,
                        color: Colors.teal,
                        onTap: () => context.push('/admin/properties'),
                      ),
                      _buildAnalyticsCard(
                        title: 'Pending Approvals',
                        value: '$_pendingCount',
                        subtitle: 'Awaiting moderation',
                        icon: Icons.hourglass_empty_rounded,
                        color: Colors.orange,
                        onTap: () => context.push('/admin/property-approvals'),
                      ),
                      _buildAnalyticsCard(
                        title: 'Revenue',
                        value: '₦${_totalRevenue.toStringAsFixed(0)}',
                        subtitle: 'Escrow operations',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
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
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: color, size: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isFullWidth ? 28 : 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
