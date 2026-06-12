import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/verification_provider.dart';
import '../../domain/verification_status.dart';
import '../widgets/verification_status_badge.dart';

class VerificationStatusScreen extends ConsumerStatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  ConsumerState<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState
    extends ConsumerState<VerificationStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verificationControllerProvider).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificationStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Verification Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VerificationStatusBadge(status: state.status),
              const SizedBox(height: 18),
              Text(
                'Status: ${state.status.name.toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              if (state.status == VerificationStatus.rejected && state.rejectionReason != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Rejection Reason',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.rejectionReason!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                state.status == VerificationStatus.rejected
                    ? 'Please review the reason for rejection above and update your submission with the correct documents.'
                    : 'Admin review is required before you can use escrow/payment or landlord property uploads.',
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    context.push('/verification/upload');
                  },
                  child: Text(state.status == VerificationStatus.rejected
                      ? 'Correct and Resubmit'
                      : 'Update / Resubmit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
