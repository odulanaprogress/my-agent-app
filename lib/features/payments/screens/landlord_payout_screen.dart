import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/transaction_model.dart';
import '../data/payment_repository.dart';

class LandlordPayoutScreen extends StatelessWidget {
  const LandlordPayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = PaymentRepository(FirebaseFirestore.instance);

    return Scaffold(
      appBar: AppBar(title: const Text('Payout Dashboard')),
      body: StreamBuilder<List<TransactionModel>>(
        stream: repository.getLandlordTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No earnings yet'));
          }

          final transactions = snapshot.data!;

          double totalEarnings = 0;
          double escrowPending = 0;
          double completedPayouts = 0;

          for (final transaction in transactions) {
            totalEarnings += transaction.amount;

            if (transaction.landlordPaidOut) {
              completedPayouts += transaction.amount;
            } else {
              escrowPending += transaction.amount;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCard(
                        title: 'Total Earnings',
                        amount: totalEarnings,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCard(
                        title: 'Escrow Pending',
                        amount: escrowPending,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildCard(
                  title: 'Completed Payouts',
                  amount: completedPayouts,
                ),
                const SizedBox(height: 30),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
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
                                '₦${transaction.amount}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: transaction.landlordPaidOut
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  transaction.landlordPaidOut
                                      ? 'Paid Out'
                                      : 'Escrow',
                                  style: TextStyle(
                                    color: transaction.landlordPaidOut
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Reference: ${transaction.id}'),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({required String title, required double amount}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Text(
            '₦${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
