import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

import '../../../payments/presentation/screens/rent_schedule_screen.dart';
import '../../../payments/models/rent_subscription_model.dart';

/// Displays a user's active rental/lease with a countdown to expiry.
class RentalCountdownScreen extends StatelessWidget {
  const RentalCountdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Color(0xFF0F172A)),
          title: const Text(
            'My Rentals & Leases',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF0F172A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Monthly Plans'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Agreements & Leases'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Monthly Escrow Plans ────────────────────────────
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rent_subscriptions')
                  .where('tenantId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoader(size: 24));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 14),
                          const Text(
                            'No Monthly Rent Plans Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rent any property with the flexible monthly plan to spread your rent in 12 escrow installments.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final sub = RentSubscriptionModel.fromMap(
                        docs[i].data(), docs[i].id);
                    return _MonthlySubscriptionCard(sub: sub);
                  },
                );
              },
            ),

            // ── Tab 2: Agreements & Leases ─────────────────────────────
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('tenancy_agreements')
                  .where('tenantId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoader(size: 24));
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_work_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No active agreements found',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign a tenancy agreement to track your rental',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    return _RentalCard(data: data);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySubscriptionCard extends StatelessWidget {
  final RentSubscriptionModel sub;

  const _MonthlySubscriptionCard({required this.sub});

  String _formatCurrency(num amount) {
    return amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = sub.totalMonths > 0
        ? (sub.completedMonths / sub.totalMonths).clamp(0.0, 1.0)
        : 0.0;
    final daysToNext = sub.nextDueDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub.propertyTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sub.status == 'active'
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : Colors.orangeAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sub.status.toUpperCase(),
                    style: TextStyle(
                      color: sub.status == 'active'
                          ? const Color(0xFF10B981)
                          : Colors.orangeAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            if (sub.propertyAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sub.propertyAddress,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTHLY RENT',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₦${_formatCurrency(sub.monthlyAmount)}/mo',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'NEXT DUE DATE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(sub.nextDueDate),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: daysToNext <= 7 ? Colors.orangeAccent.shade700 : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${sub.completedMonths} of ${sub.totalMonths} months settled',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RentScheduleScreen(subscriptionId: sub.id),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_view_day_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'View 12-Month Schedule',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RentalCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final propertyTitle = data['propertyTitle'] ?? 'Property';
    final landlordName = data['landlordName'] ?? 'Landlord';
    final rentalDuration = data['rentalDuration'] ?? '12 months';
    final rentAmount = (data['rentAmount'] ?? 0).toDouble();
    final signedAt = data['signedAt'];
    final status = data['status'] ?? 'signed_by_tenant';

    DateTime? startDate;
    if (signedAt is Timestamp) startDate = signedAt.toDate();

    DateTime? endDate;
    int? daysRemaining;
    double progress = 0;

    if (startDate != null) {
      final months = _parseMonths(rentalDuration);
      endDate = DateTime(
        startDate.year,
        startDate.month + months,
        startDate.day,
      );
      final totalDays = endDate.difference(startDate).inDays;
      final elapsed = DateTime.now().difference(startDate).inDays;
      daysRemaining = endDate.difference(DateTime.now()).inDays;
      progress = totalDays > 0 ? (elapsed / totalDays).clamp(0.0, 1.0) : 0;
    }

    final isExpired = daysRemaining != null && daysRemaining <= 0;
    final isExpiringSoon =
        daysRemaining != null && daysRemaining > 0 && daysRemaining <= 30;

    Color statusColor = Colors.green;
    String statusText = 'Active';
    if (isExpired) {
      statusColor = Colors.red;
      statusText = 'Expired';
    } else if (isExpiringSoon) {
      statusColor = Colors.orange;
      statusText = 'Expiring Soon';
    } else if (status == 'signed_by_tenant') {
      statusColor = Colors.blue;
      statusText = 'Awaiting Landlord';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    propertyTitle.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Landlord: $landlordName',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            if (daysRemaining != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rental Progress',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isExpired
                        ? 'Expired'
                        : '$daysRemaining days left',
                    style: TextStyle(
                      color: isExpired
                          ? Colors.red
                          : isExpiringSoon
                              ? Colors.orange
                              : const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isExpired
                        ? Colors.red
                        : isExpiringSoon
                            ? Colors.orange
                            : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Details row
            Row(
              children: [
                _detailChip(
                  Icons.timer_outlined,
                  rentalDuration.toString(),
                  Colors.indigo,
                ),
                const SizedBox(width: 8),
                _detailChip(
                  Icons.account_balance_wallet_outlined,
                  '₦${rentAmount.toStringAsFixed(0)}/mo',
                  Colors.green,
                ),
                if (endDate != null) ...[
                  const SizedBox(width: 8),
                  _detailChip(
                    Icons.calendar_today_outlined,
                    'Ends: ${endDate.day}/${endDate.month}/${endDate.year}',
                    Colors.orange,
                  ),
                ],
              ],
            ),

            if (isExpiringSoon) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your rental expires in $daysRemaining days. Contact your landlord for renewal.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  int _parseMonths(String duration) {
    final match = RegExp(r'(\d+)').firstMatch(duration);
    if (match != null) return int.tryParse(match.group(1) ?? '12') ?? 12;
    return 12;
  }
}
