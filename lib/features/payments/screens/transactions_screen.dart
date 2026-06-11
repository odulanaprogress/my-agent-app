import 'package:flutter/material.dart';

/// STEP 19 — Transactions history MVP scaffold.
///
/// The repo currently has escrow status + transaction lifecycle methods,
/// but not yet the TransactionModel + PaymentRepository.getUserTransactions().
/// This screen is intentionally UI-only until Step 20 wires Firestore.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: const SafeArea(
        child: Center(child: Text('Connect transactions history in Step 20.')),
      ),
    );
  }
}
