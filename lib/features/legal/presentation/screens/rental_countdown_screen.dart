import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Displays a user's active rental/lease with a countdown to expiry.
class RentalCountdownScreen extends StatelessWidget {
  const RentalCountdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tenancy_agreements')
            .where('tenantId', isEqualTo: uid)
            .snapshots(),
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
