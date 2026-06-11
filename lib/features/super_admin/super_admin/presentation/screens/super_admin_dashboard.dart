import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Placeholder UI for super admin operations.
    return Scaffold(
      appBar: AppBar(title: const Text('Super Admin')),
      body: const Center(child: Text('Super Admin Dashboard (scaffold)')),
    );
  }
}
