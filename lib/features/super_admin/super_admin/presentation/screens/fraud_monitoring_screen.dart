import 'package:flutter/material.dart';

class FraudMonitoringScreen extends StatelessWidget {
  const FraudMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fraud Monitoring')),
      body: const Center(child: Text('Fraud Monitoring (scaffold)')),
    );
  }
}
