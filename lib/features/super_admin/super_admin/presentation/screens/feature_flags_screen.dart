import 'package:flutter/material.dart';

class FeatureFlagsScreen extends StatelessWidget {
  const FeatureFlagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feature Flags')),
      body: const Center(child: Text('Feature Flags (scaffold)')),
    );
  }
}
