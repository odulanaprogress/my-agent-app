import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/nigerian_banks.dart';
import '../../../../core/network/api_client.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final _bankSetupProvider =
    StateNotifierProvider.autoDispose<_BankSetupNotifier, _BankSetupState>(
      (_) => _BankSetupNotifier(),
    );

class _BankSetupState {
  final Map<String, String>? selectedBank;
  final String accountNumber;
  final String? resolvedAccountName;
  final bool isResolving;
  final bool isSaving;
  final String? error;

  const _BankSetupState({
    this.selectedBank,
    this.accountNumber = '',
    this.resolvedAccountName,
    this.isResolving = false,
    this.isSaving = false,
    this.error,
  });

  _BankSetupState copyWith({
    Map<String, String>? selectedBank,
    String? accountNumber,
    String? resolvedAccountName,
    bool? isResolving,
    bool? isSaving,
    String? error,
    bool clearResolved = false,
    bool clearError = false,
  }) {
    return _BankSetupState(
      selectedBank: selectedBank ?? this.selectedBank,
      accountNumber: accountNumber ?? this.accountNumber,
      resolvedAccountName:
          clearResolved ? null : (resolvedAccountName ?? this.resolvedAccountName),
      isResolving: isResolving ?? this.isResolving,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class _BankSetupNotifier extends StateNotifier<_BankSetupState> {
  _BankSetupNotifier() : super(const _BankSetupState());

  Timer? _debounce;

  void selectBank(Map<String, String> bank) {
    state = state.copyWith(
      selectedBank: bank,
      clearResolved: true,
      clearError: true,
    );
    _tryResolve();
  }

  void onAccountNumberChanged(String value) {
    state = state.copyWith(
      accountNumber: value,
      clearResolved: true,
      clearError: true,
    );
    _debounce?.cancel();
    if (value.length == 10) {
      _debounce = Timer(const Duration(milliseconds: 600), _tryResolve);
    }
  }

  void _tryResolve() {
    if (state.accountNumber.length == 10 && state.selectedBank != null) {
      _resolve(state.accountNumber, state.selectedBank!['code']!);
    }
  }

  Future<void> _resolve(String accountNumber, String bankCode) async {
    state = state.copyWith(isResolving: true, clearResolved: true, clearError: true);
    try {
      final result = await ApiClient.workerPost('/bank/resolve', {
        'accountNumber': accountNumber,
        'bankCode': bankCode,
      });
      final name = result['data']?['accountName'] as String?;
      if (name != null && name.isNotEmpty) {
        state = state.copyWith(
          resolvedAccountName: name,
          isResolving: false,
        );
      } else {
        state = state.copyWith(
          isResolving: false,
          error: 'Could not verify account. Please check the details.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isResolving: false,
        error: 'Verification failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<bool> saveBankDetails() async {
    if (state.resolvedAccountName == null || state.selectedBank == null) {
      return false;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');
      // Bank details live in their own collection, restricted to the owner +
      // admin only (see firestore.rules) — NOT on /users/{uid}, which any
      // signed-in user can read. Field names here match what the payout
      // logic (functions/index.js verifyEscrowPin) reads: top-level
      // bankCode/accountNumber, not nested under a bankDetails map.
      await FirebaseFirestore.instance.collection('bank_accounts').doc(uid).set({
        'accountNumber': state.accountNumber,
        'bankCode': state.selectedBank!['code'],
        'bankName': state.selectedBank!['name'],
        'accountName': state.resolvedAccountName,
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save: ${e.toString().replaceFirst('Exception: ', '')}',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class BankAccountSetupScreen extends ConsumerStatefulWidget {
  const BankAccountSetupScreen({super.key});

  @override
  ConsumerState<BankAccountSetupScreen> createState() =>
      _BankAccountSetupScreenState();
}

class _BankAccountSetupScreenState
    extends ConsumerState<BankAccountSetupScreen> {
  final _accountController = TextEditingController();

  static const _primary = Color(0xFF1E3A8A);
  static const _bg = Color(0xFFF1F5F9);
  static const _surface = Colors.white;
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_bankSetupProvider);
    final notifier = ref.read(_bankSetupProvider.notifier);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        title: const Text(
          'Bank Account Setup',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              _InfoCard(),
              const SizedBox(height: 24),

              // Bank Picker
              _SectionLabel(label: 'Select Bank'),
              const SizedBox(height: 8),
              _BankDropdown(
                selected: s.selectedBank,
                onChanged: notifier.selectBank,
              ),
              const SizedBox(height: 20),

              // Account number
              _SectionLabel(label: 'Account Number'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: notifier.onAccountNumberChanged,
                decoration: InputDecoration(
                  hintText: '10-digit NUBAN',
                  counterText: '',
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: s.isResolving
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : s.resolvedAccountName != null
                      ? const Icon(Icons.verified_rounded, color: _green)
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Resolved name banner
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: s.isResolving
                    ? _StatusBanner(
                        key: const ValueKey('resolving'),
                        icon: Icons.hourglass_top_rounded,
                        color: _primary,
                        message: 'Verifying account with Flutterwave...',
                      )
                    : s.resolvedAccountName != null
                    ? _StatusBanner(
                        key: ValueKey(s.resolvedAccountName),
                        icon: Icons.check_circle_rounded,
                        color: _green,
                        message: s.resolvedAccountName!,
                        isSuccess: true,
                      )
                    : s.error != null
                    ? _StatusBanner(
                        key: ValueKey(s.error),
                        icon: Icons.error_rounded,
                        color: _red,
                        message: s.error!,
                        isError: true,
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),

              const SizedBox(height: 32),

              // Save button
              AnimatedOpacity(
                opacity: s.resolvedAccountName != null ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 250),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: s.resolvedAccountName == null || s.isSaving
                        ? null
                        : () async {
                            final ok = await notifier.saveBankDetails();
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: _green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Bank account saved successfully!',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              context.pop();
                            }
                          },
                    child: s.isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Bank Account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF1E3A8A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Enter your bank account number and we will automatically verify your account name using Flutterwave. Payouts will only be sent to this verified account.',
              style: TextStyle(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Color(0xFF374151),
      ),
    );
  }
}

class _BankDropdown extends StatelessWidget {
  final Map<String, String>? selected;
  final ValueChanged<Map<String, String>> onChanged;

  const _BankDropdown({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, String>>(
          value: selected,
          isExpanded: true,
          hint: const Text('Choose your bank', style: TextStyle(color: Colors.grey)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: nigerianBanks.map((bank) {
            return DropdownMenuItem<Map<String, String>>(
              value: bank,
              child: Text(bank['name']!, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final bool isSuccess;
  final bool isError;

  const _StatusBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.message,
    this.isSuccess = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSuccess)
                  Text(
                    'Account Verified ✓',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontWeight: isSuccess ? FontWeight.w700 : FontWeight.normal,
                    fontSize: isSuccess ? 15 : 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
