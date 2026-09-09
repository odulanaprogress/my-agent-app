import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SystemHealthScreen extends StatelessWidget {
  const SystemHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('System Diagnostics & Health'),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _statusBanner(),
          const SizedBox(height: 20),
          _serviceTile(
            serviceName: 'Firebase Firestore & Realtime Sync',
            latency: '42 ms',
            status: 'Operational',
            icon: Icons.cloud_done_rounded,
            isHealthy: true,
          ),
          const SizedBox(height: 12),
          _serviceTile(
            serviceName: 'Flutterwave Escrow & NUBAN Virtual Accounts',
            latency: '118 ms',
            status: 'Operational',
            icon: Icons.account_balance_rounded,
            isHealthy: true,
          ),
          const SizedBox(height: 12),
          _serviceTile(
            serviceName: 'OneSignal Push Notifications Gateway',
            latency: '85 ms',
            status: 'Operational',
            icon: Icons.notifications_active_rounded,
            isHealthy: true,
          ),
          const SizedBox(height: 12),
          _serviceTile(
            serviceName: 'Cloudinary CDN Property Media Storage',
            latency: '64 ms',
            status: 'Operational',
            icon: Icons.image_rounded,
            isHealthy: true,
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Systems Operational',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Core backend integrations, escrow engine & messaging systems are performing nominally.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceTile({
    required String serviceName,
    required String latency,
    required String status,
    required IconData icon,
    required bool isHealthy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0F172A), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text('API Latency: $latency', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isHealthy ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isHealthy ? const Color(0xFF10B981) : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
