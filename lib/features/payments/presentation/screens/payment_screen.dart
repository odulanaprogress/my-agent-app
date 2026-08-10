import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/payment_provider.dart';
import '../../../../core/services/access_control_service.dart';
import '../../../../core/services/escrow_api_service.dart';
import '../../../../features/properties/models/property_model.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../domain/escrow_status.dart';
import '../widgets/payment_receipt_dialog.dart';
import 'escrow_details_screen.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final PropertyModel property;
  const PaymentScreen({super.key, required this.property});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final AccessControlService accessControlService = AccessControlService();
  final EscrowApiService escrowApiService = EscrowApiService();
  String _selectedMethod = 'bank_transfer';
  bool _isProcessing = false;

  double get _rentAmount => widget.property.price.toDouble();
  double get _platformFee => _rentAmount * 0.05; // 5% Platform & Escrow Protection Fee
  double get _totalPackage => _rentAmount + _platformFee;

  Future<void> _processFlutterwavePayment() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to complete your payment.')),
      );
      return;
    }

    final isVerified = await accessControlService.isVerified();
    if (!isVerified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orangeAccent,
          content: Text('Verification required before making escrow payments.'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final tempTxId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
      final vaInfo = await escrowApiService.generateFlutterwaveVirtualAccount(
        transactionId: tempTxId,
        amount: _totalPackage.round(),
        propertyTitle: widget.property.title,
        email: currentUser.email,
        fullName: currentUser.fullName,
      );


      final txId = await ref.read(paymentControllerProvider).createEscrowPayment(
            landlordId: widget.property.ownerId,
            propertyId: widget.property.id,
            amount: _totalPackage.round(),
            status: EscrowStatus.pending,
            virtualAccountNumber: vaInfo['accountNumber'],
            virtualBankName: vaInfo['bankName'],
            virtualAccountName: vaInfo['accountName'],
            txRef: vaInfo['txRef'],
          );

      setState(() => _isProcessing = false);

      if (!mounted) return;

      // Show Flutterwave Virtual Account Transfer Sheet
      _showFlutterwaveVirtualAccountModal(context, txId, vaInfo, currentUser.fullName);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Payment Setup Failed: $e'),
        ),
      );
    }
  }

  void _showFlutterwaveVirtualAccountModal(
    BuildContext context,
    String transactionId,
    Map<String, String> vaInfo,
    String tenantName,
  ) {
    bool isVerifying = false;
    bool isVerified = false;
    Timer? pollTimer;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Background Automated Detection Polling Timer
            pollTimer ??= Timer.periodic(const Duration(seconds: 4), (timer) async {
              if (isVerified || !modalContext.mounted) {
                timer.cancel();
                return;
              }
              try {
                final success = await ref.read(paymentControllerProvider).verifyPaymentTransfer(transactionId: transactionId);
                if (success && modalContext.mounted && !isVerified) {
                  timer.cancel();
                  setModalState(() {
                    isVerified = true;
                    isVerifying = false;
                  });
                }
              } catch (_) {
                // Polling attempt continues silently until deposit lands
              }
            });

            final formattedTotal = _totalPackage.round().toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                );


            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5A623).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.account_balance_rounded, color: Color(0xFFF5A623), size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FLUTTERWAVE VIRTUAL ACCOUNT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFF5A623),
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    Text(
                                      'Escrow Direct Transfer',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            pollTimer?.cancel();
                            Navigator.pop(modalContext);
                          },
                          icon: const Icon(Icons.close_rounded, color: Colors.black45),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (!isVerified) ...[
                      // Virtual Account Details Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0F172A).withValues(alpha: 0.12), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Bank Partner', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    vaInfo['bankName'] ?? 'Wema Bank (Flutterwave)',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Account Name', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    vaInfo['accountName'] ?? 'FLUTTERWAVE / AGENT ESCROW',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            const Text('DEDICATED ACCOUNT NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45, letterSpacing: 0.8)),
                            const SizedBox(height: 6),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    vaInfo['accountNumber'] ?? '8030001234',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: vaInfo['accountNumber'] ?? ''));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        duration: Duration(seconds: 2),
                                        content: Text('Account number copied to clipboard!'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                                  label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Exact Amount to Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Text('₦$formattedTotal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Merchant Ref: ${vaInfo['txRef']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace')),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Transfer exact amount via your mobile banking app. Money goes directly to Flutterwave Escrow Vault.',
                              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Primary Action: Verify Payment Transfer
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isVerifying
                            ? null
                            : () async {
                                setModalState(() => isVerifying = true);
                                try {
                                  await ref.read(paymentControllerProvider).verifyPaymentTransfer(transactionId: transactionId);
                                  setModalState(() {
                                    isVerifying = false;
                                    isVerified = true;
                                  });
                                } catch (e) {
                                  setModalState(() => isVerifying = false);
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isVerifying
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppLoader(size: 18),
                                  SizedBox(width: 12),
                                  Text('Verifying Flutterwave Transfer...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              )
                            : const Text(
                                'I Have Sent the Money (Verify Payment)',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ] else ...[
                    // VERIFIED STATE: Payment Confirmed & Secured in Escrow
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Rent Payment Secured in Escrow Vault!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Flutterwave has verified your payment of ₦$formattedTotal into the Escrow Vault. The Landlord has been notified.',
                      style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Action Button 1: View Official Receipt
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          PaymentReceiptDialog.show(
                            context,
                            transactionId: transactionId,
                            txRef: vaInfo['txRef'] ?? '',
                            propertyTitle: widget.property.title,
                            amount: _totalPackage.round(),
                            tenantName: tenantName,
                            bankName: vaInfo['bankName'] ?? 'Wema Bank (Flutterwave)',
                            accountNumber: vaInfo['accountNumber'] ?? '',
                            paidAt: DateTime.now(),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                        label: const Text(
                          'View Official Payment Receipt 📄',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Button 2: View Escrow & Handshake PIN
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EscrowDetailsScreen(transactionId: transactionId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF0F172A)),
                        label: const Text(
                          'View Escrow & Handshake PIN 🔐',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Flutterwave Escrow Checkout',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text(
                  '256-Bit SSL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property Invoice Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.home_work_rounded, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.property.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.property.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rent Amount', style: TextStyle(color: Colors.black54, fontSize: 13)),
                        Text('₦${_rentAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Escrow & Platform Protection (5%)', style: TextStyle(color: Colors.black54, fontSize: 13)),
                        Text('₦${_platformFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Escrow Package',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '₦${_totalPackage.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Escrow Protection Guarantee Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security_rounded, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Flutterwave Escrow Vault Protection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Funds stay locked in Escrow. Money will NOT be sent to the Landlord until key delivery is confirmed via your 6-Digit Handshake Code.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'SELECT PAYMENT METHOD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              // Payment Method Options
              _buildPaymentOptionTile(
                id: 'bank_transfer',
                title: 'Instant Bank Transfer',
                subtitle: 'Dedicated Virtual Account generated by Flutterwave',
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 10),
              _buildPaymentOptionTile(
                id: 'card',
                title: 'Debit / Credit Card',
                subtitle: 'Mastercard, Visa, Verve',
                icon: Icons.credit_card_rounded,
              ),
              const SizedBox(height: 10),
              _buildPaymentOptionTile(
                id: 'ussd',
                title: 'USSD / Bank Mobile App',
                subtitle: 'Pay directly from GTBank, Zenith, Kuda, etc.',
                icon: Icons.qr_code_2_rounded,
              ),

              const SizedBox(height: 32),

              // Primary Action Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processFlutterwavePayment,
                  icon: _isProcessing
                      ? const SizedBox.shrink()
                      : const Icon(Icons.lock_outline_rounded, color: Colors.white),
                  label: _isProcessing
                      ? const AppLoader(size: 20)
                      : Text(
                          'Pay ₦${_totalPackage.toStringAsFixed(0)} via Flutterwave',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: Colors.black45),
                    SizedBox(width: 6),
                    Text(
                      'Powered by Flutterwave Payments Technology Solution',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == id;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF0F172A) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedMethod,
              activeColor: const Color(0xFF0F172A),
              onChanged: (val) {
                if (val != null) setState(() => _selectedMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

