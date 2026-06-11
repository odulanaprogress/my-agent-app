import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/payment_provider.dart';
import '../../../../core/services/access_control_service.dart';

import '../../../../features/properties/models/property_model.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final PropertyModel property;
  const PaymentScreen({super.key, required this.property});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final TextEditingController amountController;
  late final TextEditingController landlordIdController;
  late final TextEditingController propertyIdController;

  final AccessControlService accessControlService = AccessControlService();

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: (widget.property.price * 1.20).round().toString(),
    );
    landlordIdController = TextEditingController(text: widget.property.ownerId);
    propertyIdController = TextEditingController(text: widget.property.id);
  }

  @override
  void dispose() {
    amountController.dispose();
    landlordIdController.dispose();
    propertyIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Pay Securely'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escrow payment (demo architecture)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rent Amount',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        Text(
                          '₦${widget.property.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Agency Fee (20%)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        Text(
                          '₦${(widget.property.price * 0.20).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Package',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '₦${(widget.property.price * 1.20).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 16),

              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: landlordIdController,
                decoration: const InputDecoration(
                  labelText: 'Landlord UID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: propertyIdController,
                decoration: const InputDecoration(
                  labelText: 'Property ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: state.loading
                      ? null
                      : () async {
                          final amount =
                              int.tryParse(amountController.text) ?? 0;
                          final landlordId = landlordIdController.text.trim();
                          final propertyId = propertyIdController.text.trim();

                          final isVerified = await accessControlService
                              .isVerified();

                          if (!isVerified) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Complete verification before making payments',
                                ),
                              ),
                            );

                            return;
                          }

                          await ref
                              .read(paymentControllerProvider)
                              .createEscrowPayment(
                                landlordId: landlordId,
                                propertyId: propertyId,
                                amount: amount,
                              );

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Escrow marked as HELD (demo)'),
                            ),
                          );
                        },
                  child: const Text('Pay Securely'),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Paystack integration is not implemented yet. This screen creates a held escrow transaction in Firestore (structure only).',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
