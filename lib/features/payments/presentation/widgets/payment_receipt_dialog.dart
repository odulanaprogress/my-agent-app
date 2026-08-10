import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentReceiptDialog extends StatelessWidget {
  const PaymentReceiptDialog({
    super.key,
    required this.transactionId,
    required this.txRef,
    required this.propertyTitle,
    required this.amount,
    required this.tenantName,
    required this.bankName,
    required this.accountNumber,
    this.paidAt,
  });

  final String transactionId;
  final String txRef;
  final String propertyTitle;
  final int amount;
  final String tenantName;
  final String bankName;
  final String accountNumber;
  final DateTime? paidAt;

  static void show(
    BuildContext context, {
    required String transactionId,
    required String txRef,
    required String propertyTitle,
    required int amount,
    required String tenantName,
    required String bankName,
    required String accountNumber,
    DateTime? paidAt,
  }) {
    showDialog(
      context: context,
      builder: (context) => PaymentReceiptDialog(
        transactionId: transactionId,
        txRef: txRef,
        propertyTitle: propertyTitle,
        amount: amount,
        tenantName: tenantName,
        bankName: bankName,
        accountNumber: accountNumber,
        paidAt: paidAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = (paidAt ?? DateTime.now()).toLocal().toString().split('.')[0];
    final rentAmt = (amount / 1.05).round();
    final escrowFee = amount - rentAmt;

    final formattedTotal = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    final formattedRent = rentAmt.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    final formattedFee = escrowFee.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'FLUTTERWAVE ESCROW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF5A623),
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Official Payment Receipt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'PAID & SECURED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Amount Hero Section
            Center(
              child: Column(
                children: [
                  const Text(
                    'TOTAL TRANSFERRED INTO ESCROW',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦$formattedTotal',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ref: $txRef',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Property', propertyTitle),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Payer Name', tenantName),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Payment Method', 'Flutterwave Virtual Bank Transfer'),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Bank Provider', bankName),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Virtual NUBAN', accountNumber),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Base Rent Amount', '₦$formattedRent'),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Escrow Fee (5%)', '₦$formattedFee'),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Date & Time', dateStr),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'FLUTTERWAVE ESCROW RECEIPT\nRef: $txRef\nProperty: $propertyTitle\nAmount: ₦$formattedTotal\nStatus: PAID & SECURED IN ESCROW\nDate: $dateStr'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt details copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0F172A)),
                    label: const Text(
                      'Copy Details',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
