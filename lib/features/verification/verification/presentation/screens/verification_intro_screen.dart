import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/verification_provider.dart';
import '../../domain/verification_status.dart';

class VerificationIntroScreen extends ConsumerStatefulWidget {
  const VerificationIntroScreen({super.key});

  @override
  ConsumerState<VerificationIntroScreen> createState() => _VerificationIntroScreenState();
}

class _VerificationIntroScreenState extends ConsumerState<VerificationIntroScreen> {
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

    // If verification has already been submitted and is not "none", redirect to status
    if (state.status != VerificationStatus.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/verification/status');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Verification'),
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
              const Text(
                'Government-grade identity verification',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'To protect both tenants and landlords, you must verify your identity before using escrow/payment features.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    context.push('/verification/upload');
                  },
                  child: const Text('Start Verification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
