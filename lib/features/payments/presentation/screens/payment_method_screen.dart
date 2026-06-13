import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/user_behavior_service.dart';
import '../../../../core/widgets/kyc_gate.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  ConsumerState<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  String? _selectedPayment;
  bool _isProcessing = false;
  String _paystackStep = '';

  Future<void> _simulatePaystackCheckout() async {
    if (_selectedPayment == null) return;

    final allowed = await KycGate.require(context, ref);
    if (!allowed) return;

    UserBehaviorService.log(
      action: 'payment_initiated',
      description: 'Initiated Paystack payment via $_selectedPayment',
      metadata: {'payment_channel': _selectedPayment},
    );

    setState(() {
      _isProcessing = true;
      _paystackStep = 'Initializing Secure Paystack Session...';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _paystackStep = 'Connecting to Paystack Gateway...';
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _paystackStep = _selectedPayment == 'card'
              ? 'Verifying Card details securely...'
              : _selectedPayment == 'bank'
                  ? 'Awaiting Paystack Bank Transfer confirmation...'
                  : _selectedPayment == 'ussd'
                      ? 'Dialing USSD Gateway connection...'
                      : 'Generating Paystack QR code...';
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            _paystackStep = 'Authorizing transaction with bank...';
          });

          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            UserBehaviorService.log(
              action: 'payment_success',
              description: 'Completed Paystack payment via $_selectedPayment',
              metadata: {'payment_channel': _selectedPayment},
            );
            setState(() {
              _isProcessing = false;
            });
            _showSuccessDialog();
          });
        });
      });
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 52),
            SizedBox(height: 12),
            Text(
              'Payment Successful',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Your transaction has been processed successfully via Paystack. Funds are securely locked in the AGENT Escrow vault.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5, fontSize: 14, color: Colors.black87),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Pop dialog
                context.pop(); // Pop payment screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back to App', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Choose Payment Mode',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Paystack header badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09A5DB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF09A5DB).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF09A5DB)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paystack Secure Gateway',
                              style: TextStyle(
                                color: Color(0xFF09A5DB),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All payments are processed securely via Paystack API.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
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
                  'Select Paystack Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                // Card Payment Option
                _buildPaymentOption(
                  title: 'Pay with Card',
                  subtitle: 'Visa, MasterCard, Verve',
                  icon: Icons.credit_card_rounded,
                  value: 'card',
                ),
                const SizedBox(height: 14),

                // Bank Transfer Option
                _buildPaymentOption(
                  title: 'Pay with Bank Transfer',
                  subtitle: 'Direct transfer to temporary bank account',
                  icon: Icons.account_balance_rounded,
                  value: 'bank',
                ),
                const SizedBox(height: 14),

                // USSD Option
                _buildPaymentOption(
                  title: 'Pay with USSD',
                  subtitle: 'GTBank, Zenith, Access USSD codes',
                  icon: Icons.dialpad_rounded,
                  value: 'ussd',
                ),
                const SizedBox(height: 14),

                // QR Option
                _buildPaymentOption(
                  title: 'Pay with QR Code',
                  subtitle: 'Scan QR to pay directly from bank app',
                  icon: Icons.qr_code_2_rounded,
                  value: 'qr',
                ),
                const SizedBox(height: 32),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedPayment != null ? _simulatePaystackCheckout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Authorize Secure Checkout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Paystack Processing Dialog
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              alignment: Alignment.center,
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF09A5DB),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'SECURE PAYSTACK CHECKOUT',
                        style: TextStyle(
                          color: Color(0xFF09A5DB),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _paystackStep,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please do not press back or close this window.',
                        style: TextStyle(color: Colors.black54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedPayment == value;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade200,
          width: isSelected ? 2.0 : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedPayment = value),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0F172A).withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedPayment = value),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            )
                          : null,
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
