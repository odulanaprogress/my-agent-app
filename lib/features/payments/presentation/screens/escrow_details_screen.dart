import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


import '../../domain/escrow_status.dart';
import '../../providers/payment_provider.dart';
import '../../data/transaction_model.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../widgets/escrow_status_badge.dart';
import 'package:agent_app/core/widgets/app_loader.dart';
import 'package:agent_app/core/services/escrow_api_service.dart';
import '../../../legal/presentation/screens/tenancy_agreement_screen.dart';

import '../widgets/payment_receipt_dialog.dart';
import 'package:agent_app/core/utils/app_exception.dart';

class EscrowDetailsScreen extends ConsumerWidget {
  const EscrowDetailsScreen({super.key, required this.transactionId});

  final String transactionId;

  void _showPinInputDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String transactionId,
    required String userRole,
    required String title,
    required String subtitle,
  }) {
    final controller = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pin_outlined, color: Color(0xFF0F172A), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                      color: Color(0xFF0F172A),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade300,
                        letterSpacing: 10,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final pin = controller.text.trim();
                            if (pin.length != 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a 6-digit PIN.')),
                              );
                              return;
                            }

                            setModalState(() => isLoading = true);

                            try {
                              final res = await ref
                                  .read(paymentControllerProvider)
                                  .verifyEscrowPin(
                                    transactionId: transactionId,
                                    pin: pin,
                                    role: userRole,
                                  );

                              if (context.mounted) {
                                Navigator.pop(context);

                                final bothVerified = res['bothVerified'] == true;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF047857),
                                    content: Text(
                                      bothVerified
                                          ? '🎉 Escrow Handshake Complete! Money released to Landlord.'
                                          : '✅ Your PIN was verified! Waiting for counterparty confirmation.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isLoading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.redAccent,
                                    content: Text(extractErrorMessage(e)),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const AppLoader(size: 20)
                        : const Text(
                            'Verify Handshake PIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser?.role ?? 'tenant';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: AppLoader(size: 24)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Escrow Details'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: const Center(child: Text('Transaction not found.')),
          );
        }

        final txMap = snapshot.data!.data()!;
        final tx = TransactionModel.fromFirestore(snapshot.data!.id, txMap);
        final status = EscrowStatusX.fromFirestore(tx.status);

        final isTenant = role == 'tenant';

        final myPin = isTenant ? tx.tenantPin : tx.landlordPin;

        final counterpartyVerified = isTenant ? tx.landlordPinVerified : tx.tenantPinVerified;
        final myVerified = isTenant ? tx.tenantPinVerified : tx.landlordPinVerified;

        final formattedAmt = tx.amount.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text(
              'Escrow & Handshake',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Amount Header Card
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade100, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          EscrowStatusBadge(status: status),
                          const SizedBox(height: 16),
                          Text(
                            status == EscrowStatus.pending ? 'Expected Escrow Funds' : 'Total Escrowed Funds',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₦$formattedAmt',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: status == EscrowStatus.pending ? Colors.orange.shade800 : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.grey.shade200),
                          const SizedBox(height: 12),

                          // Fee Breakdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Platform Fee (5%):', style: TextStyle(fontSize: 13, color: Colors.black54)),
                              Text('₦${tx.commissionAmount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Landlord Net Payout:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                              Text('₦${tx.netPayoutAmount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            ],
                          ),

                          if (status == EscrowStatus.held || status == EscrowStatus.released) ...[
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.shade200),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  PaymentReceiptDialog.show(
                                    context,
                                    transactionId: tx.id,
                                    txRef: tx.txRef ?? 'FLW-ESC-${tx.id.substring(0, 8).toUpperCase()}',
                                    propertyTitle: 'Rental Property',
                                    amount: tx.amount,
                                    tenantName: currentUser?.fullName ?? 'Tenant',
                                    bankName: tx.virtualBankName ?? 'Wema Bank (Flutterwave)',
                                    accountNumber: tx.virtualAccountNumber ?? '',
                                    paidAt: tx.paidAt?.toDate(),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0F172A), size: 18),
                                label: const Text(
                                  'View Official Payment Receipt 📄',
                                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],

                          if (status == EscrowStatus.released) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TenancyAgreementScreen(
                                        propertyId: tx.propertyId,
                                        propertyTitle: 'Rental Property',
                                        landlordId: tx.landlordId,
                                        rentAmount: tx.amount.toDouble(),
                                        tenantName: isTenant ? (currentUser?.fullName ?? 'Tenant') : 'Tenant',
                                        landlordName: !isTenant ? (currentUser?.fullName ?? 'Landlord') : 'Landlord',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.description_rounded, color: Colors.white, size: 18),
                                label: const Text(
                                  'View Signed Tenancy Agreement Letter 📜',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            if (!isTenant) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showLandlordPayoutBankSheet(context, ref, tx),
                                  icon: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
                                  label: Text(
                                    'Disburse ₦${tx.netPayoutAmount} to My Bank Account 🏦',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // UNVERIFIED / PENDING PAYMENT NOTICE & VERIFY BUTTON
                  if (status == EscrowStatus.pending) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.shade300, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.hourglass_empty_rounded, color: Colors.amber.shade900, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Awaiting Flutterwave Transfer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Please transfer ₦$formattedAmt to the Flutterwave Virtual Account (${tx.virtualAccountNumber ?? ''} - ${tx.virtualBankName ?? ''}). Handshake PIN verification will unlock immediately after payment verification.',
                            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await ref.read(paymentControllerProvider).verifyPaymentTransfer(transactionId: tx.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF047857),
                                        content: Text('🎉 Payment Verified! Funds are now secured in Escrow Vault.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.redAccent,
                                        content: Text(e.toString().replaceAll('Exception:', '').replaceAll('StateError:', '').trim()),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'I Have Sent the Money (Verify Payment)',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],


                  // 🔐 DUAL 6-DIGIT PIN HANDSHAKE CARD
                  if (status == EscrowStatus.held) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Handshake Verification PIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isTenant
                                ? 'Your key receipt PIN to give to the landlord upon physical inspection & key handover:'
                                : 'Your handover confirmation PIN to give to the tenant when keys are delivered:',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          ),
                          const SizedBox(height: 14),

                          // PIN DISPLAY BOX
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  myPin ?? '──────',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 6,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                                  onPressed: myPin == null
                                      ? null
                                      : () {
                                          Clipboard.setData(ClipboardData(text: myPin));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('PIN copied to clipboard!')),
                                          );
                                        },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          Divider(color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(height: 14),

                          // LIVE HANDSHAKE PROGRESS
                          Row(
                            children: [
                              _buildStatusIndicator(
                                title: 'My Entry',
                                isDone: myVerified,
                              ),
                              const SizedBox(width: 12),
                              _buildStatusIndicator(
                                title: isTenant ? 'Landlord Entry' : 'Tenant Entry',
                                isDone: counterpartyVerified,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ACTION BUTTON: ENTER COUNTERPARTY PIN
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _showPinInputDialog(
                                context: context,
                                ref: ref,
                                transactionId: tx.id,
                                userRole: role,
                                title: isTenant ? "Enter Landlord's PIN" : "Enter Tenant's PIN",
                                subtitle: isTenant
                                    ? "Enter the 6-digit PIN given to you by the Landlord."
                                    : "Enter the 6-digit PIN given to you by the Tenant.",
                              ),
                              icon: const Icon(Icons.lock_open_rounded, color: Color(0xFF0F172A)),
                              label: Text(
                                isTenant ? "Enter Landlord's PIN" : "Enter Tenant's PIN",
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          if (isTenant && status == EscrowStatus.held) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.undo_rounded, color: Colors.redAccent),
                                          SizedBox(width: 10),
                                          Text('Request Escrow Refund', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      content: const Text(
                                        'If keys were not delivered or property inspection was unsuccessful, you can request a full refund of your escrow deposit back to your source bank account.',
                                        style: TextStyle(fontSize: 13, height: 1.4),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx),
                                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(dialogCtx);
                                            try {
                                              await ref.read(paymentControllerProvider).requestRefund(transactionId: tx.id);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    backgroundColor: Color(0xFF2563EB),
                                                    content: Text('🎉 Escrow Refund Requested! Flutterwave will process funds back to your account.'),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: Colors.redAccent,
                                                    content: Text('Refund Failed: $e'),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text('Confirm Refund', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.undo_rounded, color: Colors.redAccent, size: 18),
                                label: const Text(
                                  'Request Escrow Refund / Cancel',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  const Text(
                    'TRANSACTION AUDIT DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black54,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailTile('Transaction ID', tx.id),
                  _buildDetailTile('Property ID', tx.propertyId),
                  _buildDetailTile('Tenant UID', tx.tenantId),
                  _buildDetailTile('Landlord UID', tx.landlordId),
                  _buildDetailTile(
                    'Created At',
                    tx.createdAt.toDate().toLocal().toString().substring(0, 19),
                  ),
                  _buildDetailTile(
                    'Possession Confirmed',
                    tx.possessionConfirmed ? 'Yes ✅' : 'No ⏳',
                  ),
                  _buildDetailTile(
                    'Landlord Paid Out',
                    tx.landlordPaidOut ? 'Yes ✅' : 'No ⏳',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator({required String title, required bool isDone}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFF10B981).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
              size: 16,
              color: isDone ? const Color(0xFF34D399) : Colors.white60,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDone ? const Color(0xFF34D399) : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLandlordPayoutBankSheet(BuildContext context, WidgetRef ref, TransactionModel tx) {
    final currentUser = ref.read(currentUserProvider);
    final accountController = TextEditingController();
    String selectedBankCode = '058';
    String selectedBankName = 'Guaranty Trust Bank (GTBank)';
    bool isProcessing = false;
    bool isResolving = false;
    String? resolvedAccountName;
    String? resolveError;
    String? transferError;

    final banks = [
      {'code': '058', 'name': 'Guaranty Trust Bank (GTBank)'},
      {'code': '044', 'name': 'Access Bank'},
      {'code': '057', 'name': 'Zenith Bank PLC'},
      {'code': '033', 'name': 'United Bank for Africa (UBA)'},
      {'code': '011', 'name': 'First Bank of Nigeria'},
      {'code': '100004', 'name': 'OPay Digital Services'},
      {'code': '100033', 'name': 'PalmPay'},
      {'code': '090405', 'name': 'Moniepoint Microfinance Bank'},
      {'code': '090267', 'name': 'Kuda Bank'},
      {'code': '035', 'name': 'Wema Bank PLC'},
      {'code': '214', 'name': 'First City Monument Bank (FCMB)'},
      {'code': '070', 'name': 'Fidelity Bank'},
      {'code': '232', 'name': 'Sterling Bank'},
      {'code': '032', 'name': 'Union Bank of Nigeria'},
      {'code': '221', 'name': 'Stanbic IBTC Bank'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> triggerAccountResolve(String acct, String bank) async {
              if (acct.length != 10) {
                setModalState(() {
                  isResolving = false;
                  resolvedAccountName = null;
                  resolveError = null;
                });
                return;
              }
              setModalState(() {
                isResolving = true;
                resolveError = null;
                resolvedAccountName = null;
              });
              try {
                final res = await EscrowApiService().resolveAccountName(
                  accountNumber: acct,
                  bankCode: bank,
                );
                final data = res['data'] as Map<String, dynamic>?;
                final name = data?['account_name'] ?? 'Account Verified';
                setModalState(() {
                  isResolving = false;
                  resolvedAccountName = name.toString();
                });
              } catch (e) {
                final msg = extractErrorMessage(e);
                final isCors = msg.toLowerCase().contains('cors') ||
                    msg.toLowerCase().contains('xmlhttprequest') ||
                    msg.toLowerCase().contains('failed to fetch') ||
                    msg.toLowerCase().contains('network') ||
                    msg.contains('minified') ||
                    msg.startsWith('Instance of ');
                setModalState(() {
                  isResolving = false;
                  resolveError = isCors
                      ? 'Account name lookup unavailable on web. Please verify the number manually before proceeding.'
                      : msg;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.account_balance_rounded, color: Color(0xFF10B981), size: 26),
                      SizedBox(width: 12),
                      Text(
                        'Landlord Direct Bank Payout',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Disburse ₦${tx.netPayoutAmount} net rent directly from Flutterwave Escrow Vault to your bank account.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBankCode,
                    decoration: InputDecoration(
                      labelText: 'Select Destination Bank',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: banks.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['code']!,
                        child: Text(b['name']!, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedBankCode = val;
                          selectedBankName = banks.firstWhere((b) => b['code'] == val)['name']!;
                        });
                        triggerAccountResolve(accountController.text.trim(), selectedBankCode);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    onChanged: (val) => triggerAccountResolve(val.trim(), selectedBankCode),
                    decoration: InputDecoration(
                      labelText: '10-Digit NUBAN Account Number',
                      hintText: '0123456789',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (isResolving) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        AppLoader(size: 14),
                        SizedBox(width: 8),
                        Text('Resolving account name with Flutterwave...', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                      ],
                    ),
                  ] else if (resolvedAccountName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Account Name: $resolvedAccountName',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (resolveError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resolveError!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (transferError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transferError!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final acct = accountController.text.trim();
                              if (acct.length != 10) {
                                setModalState(() => transferError = 'Please enter a valid 10-digit NUBAN account number.');
                                return;
                              }
                              setModalState(() {
                                isProcessing = true;
                                transferError = null;
                              });
                              try {
                                await EscrowApiService().disburseLandlordPayout(
                                  transactionId: tx.id,
                                  amount: tx.netPayoutAmount,
                                  bankCode: selectedBankCode,
                                  accountNumber: acct,
                                );

                                // Deduct balance in Firestore
                                if (currentUser != null) {
                                  await ref.read(walletRepositoryProvider).incrementBalance(
                                    uid: currentUser.uid,
                                    delta: -tx.netPayoutAmount,
                                    updatedAt: DateTime.now(),
                                  );
                                }

                                Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF10B981),
                                      content: Text('🎉 Payout of ₦${tx.netPayoutAmount} sent to $acct (${resolvedAccountName ?? selectedBankName}) via Flutterwave!'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                final errStr = extractErrorMessage(e);
                                setModalState(() {
                                  isProcessing = false;
                                  transferError = errStr;
                                });
                              }
                            },
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(
                        isProcessing ? 'Processing Live Payout...' : 'Transfer ₦${tx.netPayoutAmount} to My Bank 🚀',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

