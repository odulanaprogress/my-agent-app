import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../providers/payment_provider.dart';
import '../widgets/wallet_balance_card.dart';
import '../../data/wallet_repository.dart';
import 'escrow_details_screen.dart';
import '../../../../../core/widgets/kyc_gate.dart';
import 'package:agent_app/core/widgets/app_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/escrow_api_service.dart';
import '../../../../core/utils/app_exception.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import '../../../../core/constants/nigerian_banks.dart';

// Real-time wallet data provider
final _walletDataProvider = StreamProvider.autoDispose<WalletData>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const WalletData(availableBalance: 0, escrowBalance: 0));
  final repo = ref.watch(walletRepositoryProvider);
  return repo.watchWalletData(user.uid);
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final amountController = TextEditingController(text: '10000');
  bool _isProcessingDeposit = false;
  bool _isProcessingWithdraw = false;
  bool _hasSynced = false;

  @override
  void initState() {
    super.initState();
    // Auto-sync wallet balance after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSyncIfNeeded());
  }

  Future<void> _autoSyncIfNeeded() async {
    if (_hasSynced) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final walletSnap = await FirebaseFirestore.instance.collection('wallets').doc(uid).get();
      final avail = (walletSnap.data()?['availableBalance'] ?? walletSnap.data()?['balance'] ?? 0);
      final balance = avail is num ? avail.toInt() : 0;

      // Only sync if balance appears to be 0 — avoids overwriting real balances
      if (balance == 0) {
        final txs = await FirebaseFirestore.instance
            .collection('transactions')
            .where('landlordId', isEqualTo: uid)
            .get();

        int totalReleased = 0;
        for (final doc in txs.docs) {
          final data = doc.data();
          final status = data['status']?.toString() ?? '';
          if (status == 'released' || status == 'completed') {
            final amt = data['netPayoutAmount'] ?? data['amount'] ?? 0;
            totalReleased += (amt as num).toInt();
          }
        }

        if (totalReleased > 0) {
          await FirebaseFirestore.instance.collection('wallets').doc(uid).set({
            'availableBalance': totalReleased,
            'balance': totalReleased,
            'uid': uid,
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));
        }
      }
      if (mounted) setState(() => _hasSynced = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _showDepositSheet() async {
    // KYC check
    final allowed = await KycGate.require(context, ref);
    if (!allowed) return;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FlutterwaveDepositSheet(),
    );

    if (mounted) {
      ref.invalidate(_walletDataProvider);
    }
  }

  Future<void> _showWithdrawSheet(int availableBalance) async {
    final allowed = await KycGate.require(context, ref);
    if (!allowed) return;

    if (!mounted) return;

    final amountController = TextEditingController(text: availableBalance > 0 ? availableBalance.toString() : '');
    final accountController = TextEditingController();
    String selectedBankCode = '058';
    String selectedBankName = 'Guaranty Trust Bank (GTBank)';

    bool isProcessing = false;
    bool isResolving = false;
    String? resolvedAccountName;
    String? resolveError;
    String? transferError;

    // Inside the _showWithdrawSheet method, we can just use the imported nigerianBanks
    final banks = nigerianBanks;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> triggerAccountResolve(String acct, String bank) async {
            if (acct.length != 10) {
              setModalState(() {
                isResolving = false;
                resolvedAccountName = null;
                resolveError = null;
              });
              return;
            }

            setModalState(() {
              isResolving = true;
              resolveError = null;
              resolvedAccountName = null;
            });
            try {
              final res = await EscrowApiService().resolveAccountName(
                accountNumber: acct,
                bankCode: bank,
              );
              final data = res['data'] as Map<String, dynamic>?;
              final name = data?['account_name'] ?? 'Account Verified';
              setModalState(() {
                isResolving = false;
                resolvedAccountName = name.toString();
              });
            } catch (e) {
              final msg = extractErrorMessage(e);
              final isCors = msg.toLowerCase().contains('cors') ||
                  msg.toLowerCase().contains('xmlhttprequest') ||
                  msg.toLowerCase().contains('failed to fetch') ||
                  msg.toLowerCase().contains('network') ||
                  msg.contains('minified') ||
                  msg.startsWith('Instance of ');
              setModalState(() {
                isResolving = false;
                resolveError = isCors
                    ? 'Account name lookup unavailable on web. You can still proceed with the transfer.'
                    : '$msg — You can still proceed with the transfer if the account number is correct.';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct Bank Withdrawal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Transfer funds directly to your Nigerian bank account', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedBankCode,
                    decoration: InputDecoration(
                      labelText: 'Select Destination Bank',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: banks.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['code']!,
                        child: Text(b['name']!, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedBankCode = val;
                          selectedBankName = banks.firstWhere((b) => b['code'] == val)['name']!;
                        });
                        triggerAccountResolve(accountController.text.trim(), selectedBankCode);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: accountController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) => triggerAccountResolve(val.trim(), selectedBankCode),
                    decoration: InputDecoration(
                      labelText: '10-Digit NUBAN Account Number',
                      hintText: '0123456789',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (isResolving) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        AppLoader(size: 14),
                        SizedBox(width: 8),
                        Text('Resolving account name with Flutterwave...', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                      ],
                    ),
                  ] else if (resolvedAccountName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Account Name: $resolvedAccountName',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (resolveError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resolveError!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Amount to Withdraw (₦)',
                      prefixText: '₦ ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (transferError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transferError!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final acct = accountController.text.trim();
                              final rawAmtStr = amountController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
                              final amt = double.tryParse(rawAmtStr)?.toInt() ?? 0;
                              if (acct.length != 10) {
                                setModalState(() => transferError = 'Please enter a valid 10-digit NUBAN account number.');
                                return;
                              }
                              if (amt <= 0) {
                                setModalState(() => transferError = 'Please enter a valid withdrawal amount.');
                                return;
                              }
                              setModalState(() {
                                isProcessing = true;
                                transferError = null;
                              });
                              try {
                                // Server validates real balance, executes transfer,
                                // and decrements wallet atomically.
                                // Client never touches Flutterwave directly.
                                await EscrowApiService().requestWithdrawal(
                                  amount: amt,
                                  bankCode: selectedBankCode,
                                  accountNumber: acct,
                                );
                                // Balance update is handled server-side — no client write needed.

                                Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  _snack('🎉 ₦$amt withdrawal sent to $acct (${resolvedAccountName ?? selectedBankName}) via Flutterwave!');
                                }
                              } catch (e) {
                                final errStr = extractErrorMessage(e);
                                setModalState(() {
                                  isProcessing = false;
                                  transferError = errStr;
                                });
                              }
                            },
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(
                        isProcessing ? 'Processing Live Transfer...' : 'Withdraw to My Bank Account 🚀',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser?.role ?? 'tenant';
    final walletDataAsync = ref.watch(_walletDataProvider);

    final transactionsAsync = role == 'admin'
        ? ref.watch(adminTransactionsProvider)
        : role == 'landlord'
            ? ref.watch(landlordTransactionsProvider)
            : ref.watch(tenantTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            onPressed: () async {
              if (currentUser == null) return;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sync Wallet Balance'),
                  content: const Text('Is your wallet balance not reflecting your released escrow payments? Click Sync to recalculate it from your completed transactions.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sync Balance')),
                  ],
                ),
              );
              if (confirm != true) return;

              try {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing wallet...')));
                final txs = await FirebaseFirestore.instance.collection('transactions')
                    .where('landlordId', isEqualTo: currentUser.uid)
                    .get();
                
                int totalReleased = 0;
                for (var doc in txs.docs) {
                  final data = doc.data();
                  if (data['status'] == 'released' || data['status'] == 'completed') {
                    final amt = data['netPayoutAmount'] ?? data['amount'] ?? 0;
                    totalReleased += (amt as num).toInt();
                  }
                }

                await FirebaseFirestore.instance.collection('wallets').doc(currentUser.uid).set({
                  'availableBalance': totalReleased,
                  'balance': totalReleased,
                  'updatedAt': Timestamp.now(),
                }, SetOptions(merge: true));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Wallet Synced Successfully!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${extractErrorMessage(e)}')));
                }
              }
            },
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Sync Wallet Balance',
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Transaction History',
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_walletDataProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Wallet Card ────────────────────────────────────────
                walletDataAsync.when(
                  loading: () => WalletBalanceCard(
                    balance: 0,
                    escrowBalance: 0,
                    userName: currentUser?.fullName ?? '',
                  ),
                  error: (_, err) => WalletBalanceCard(
                    balance: 0,
                    userName: currentUser?.fullName ?? '',
                  ),
                  data: (data) => WalletBalanceCard(
                    balance: data.availableBalance,
                    escrowBalance: data.escrowBalance,
                    userName: currentUser?.fullName ?? '',
                  ),
                ),
                const SizedBox(height: 20),

                // ── Escrow Info ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Escrow funds are held securely until you confirm possession of the property.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Action Buttons ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _actionBtn(
                        label: 'Deposit',
                        icon: Icons.add_rounded,
                        color: const Color(0xFF10B981),
                        isLoading: _isProcessingDeposit,
                        onTap: _showDepositSheet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: walletDataAsync.when(
                        loading: () => _actionBtn(
                          label: 'Withdraw',
                          icon: Icons.arrow_upward_rounded,
                          color: const Color(0xFF6366F1),
                          isLoading: false,
                          onTap: () => _showWithdrawSheet(0),
                        ),
                        error: (_, err) => _actionBtn(
                          label: 'Withdraw',
                          icon: Icons.arrow_upward_rounded,
                          color: const Color(0xFF6366F1),
                          isLoading: false,
                          onTap: () => _showWithdrawSheet(0),
                        ),
                        data: (d) => _actionBtn(
                          label: 'Withdraw',
                          icon: Icons.arrow_upward_rounded,
                          color: const Color(0xFF6366F1),
                          isLoading: _isProcessingWithdraw,
                          onTap: () => _showWithdrawSheet(d.availableBalance),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Transaction History ────────────────────────────────
                const Text(
                  'Escrow Transactions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                transactionsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: AppLoader(size: 24),
                    ),
                  ),
                  error: (err, _) => Text(
                    'Error loading transactions: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                  data: (txs) {
                    if (txs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your payment history will appear here',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: txs.length,
                      itemBuilder: (context, index) {
                        final tx = txs[index];
                        final statusColor = tx.status == 'released'
                            ? Colors.green
                            : tx.status == 'held'
                                ? Colors.orange
                                : Colors.red;
                        final statusIcon = tx.status == 'released'
                            ? Icons.check_circle_rounded
                            : tx.status == 'held'
                                ? Icons.lock_clock_rounded
                                : Icons.cancel_rounded;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100, width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(statusIcon, color: statusColor, size: 22),
                            ),
                            title: Text(
                              '₦${tx.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  'Property ID: ${tx.propertyId.length > 12 ? tx.propertyId.substring(0, 12) : tx.propertyId}...',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tx.status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EscrowDetailsScreen(transactionId: tx.id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isLoading ? color.withValues(alpha: 0.5) : color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: AppLoader(size: 24)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Flutterwave Deposit Sheet ─────────────────────────────────────────────────
class _FlutterwaveDepositSheet extends ConsumerStatefulWidget {
  const _FlutterwaveDepositSheet();

  @override
  ConsumerState<_FlutterwaveDepositSheet> createState() => _FlutterwaveDepositSheetState();
}

class _FlutterwaveDepositSheetState extends ConsumerState<_FlutterwaveDepositSheet> {
  final _controller = TextEditingController(text: '10000');
  String _selectedMethod = 'bank_transfer';
  bool _isGenerating = false;
  bool _isVerifying = false;
  bool _isVerified = false;
  Timer? _pollTimer;

  Map<String, String>? _vaInfo;
  String? _txId;
  int _depositAmount = 0;

  static const _amounts = [5000, 10000, 25000, 50000, 100000];

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _formatCurrency(num amount) {
    return amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _generateVirtualAccount() async {
    final amount = int.tryParse(_controller.text.replaceAll(',', '').trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid deposit amount.')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to make a deposit.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final escrowApi = EscrowApiService();
      final tempTxId = 'DEP-${currentUser.uid.length >= 6 ? currentUser.uid.substring(0, 6) : currentUser.uid}-${DateTime.now().millisecondsSinceEpoch}';

      final vaInfo = await escrowApi.generateFlutterwaveVirtualAccount(
        transactionId: tempTxId,
        amount: amount,
        propertyTitle: 'Agent Wallet Deposit',
        email: currentUser.email,
        fullName: currentUser.fullName,
      );

      // Create pending deposit transaction in Firestore
      await FirebaseFirestore.instance.collection('transactions').doc(tempTxId).set({
        'id': tempTxId,
        'txRef': vaInfo['txRef'] ?? tempTxId,
        'userId': currentUser.uid,
        'tenantId': currentUser.uid,
        'type': 'deposit',
        'amount': amount,
        'status': 'pending',
        'virtualAccountNumber': vaInfo['accountNumber'],
        'virtualBankName': vaInfo['bankName'],
        'virtualAccountName': vaInfo['accountName'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _vaInfo = vaInfo;
        _txId = tempTxId;
        _depositAmount = amount;
      });

      _startPolling(tempTxId, vaInfo['txRef'] ?? tempTxId, amount, currentUser.uid);
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Deposit setup failed: $e'),
          ),
        );
      }
    }
  }

  void _startPolling(String txId, String txRef, int amount, String uid) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_isVerified || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final verified = await EscrowApiService().verifyPaymentStatus(
          transactionId: txId,
          txRef: txRef,
        );
        if (verified && mounted && !_isVerified) {
          timer.cancel();
          await _onDepositSuccessful(amount, uid);
        }
      } catch (_) {
        // Polling continues silently
      }
    });
  }

  Future<void> _verifyDepositManually() async {
    if (_txId == null || _vaInfo == null) return;
    setState(() => _isVerifying = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      final verified = await EscrowApiService().verifyPaymentStatus(
        transactionId: _txId!,
        txRef: _vaInfo!['txRef'] ?? _txId!,
      );

      if (verified && mounted) {
        await _onDepositSuccessful(_depositAmount, currentUser?.uid ?? '');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(e.toString().replaceAll('Exception:', '').replaceAll('StateError:', '').trim()),
          ),
        );
      }
    }
  }

  Future<void> _onDepositSuccessful(int amount, String uid) async {
    _pollTimer?.cancel();
    if (uid.isNotEmpty) {
      try {
        await ref.read(walletRepositoryProvider).incrementBalance(
          uid: uid,
          delta: amount,
          updatedAt: DateTime.now(),
        );
      } catch (_) {}
    }
    if (mounted) {
      ref.invalidate(_walletDataProvider);
      setState(() {
        _isVerified = true;
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Step 3: Verified State
            if (_isVerified) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Deposit Confirmed & Credited!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${_formatCurrency(_depositAmount)} has been credited directly to your Agent wallet via Flutterwave.',
                      style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ] else if (_vaInfo != null) ...[
              // Step 2: Dedicated Virtual Account Screen
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5A623).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.account_balance_rounded, color: Color(0xFFF5A623), size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FLUTTERWAVE VIRTUAL ACCOUNT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFF5A623),
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Text(
                                  'Wallet Deposit Transfer',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            _pollTimer?.cancel();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close_rounded, color: Colors.black45),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Virtual Account Details Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0F172A).withValues(alpha: 0.12), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bank Partner', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _vaInfo!['bankName'] ?? 'Wema Bank (Flutterwave)',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Account Name', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _vaInfo!['accountName'] ?? 'FLUTTERWAVE / AGENT WALLET',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          const Text('DEDICATED ACCOUNT NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45, letterSpacing: 0.8)),
                          const SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _vaInfo!['accountNumber'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _vaInfo!['accountNumber'] ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      duration: Duration(seconds: 2),
                                      content: Text('Account number copied to clipboard!'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                                label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                            Builder(
                              builder: (context) {
                                final exactAmount = _vaInfo!['amount'] != null ? double.tryParse(_vaInfo!['amount']!) : null;
                                final displayAmount = exactAmount != null ? _formatCurrency(exactAmount) : _formatCurrency(_depositAmount);
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Exact Amount to Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    Text('₦$displayAmount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: 4),
                          Text('Ref: ${_vaInfo!['txRef']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Transfer exact amount via your banking app. The app is actively listening for your deposit.',
                              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Primary Verification Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyDepositManually,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isVerifying
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppLoader(size: 18),
                                  SizedBox(width: 12),
                                  Text('Verifying Flutterwave Transfer...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              )
                            : const Text(
                                'I Have Sent the Money (Verify Payment)',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ] else ...[
              // Step 1: Input Amount & Select Method
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFFF5A623), size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'Flutterwave Secure Deposit',
                      style: TextStyle(
                        color: Color(0xFFF5A623),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('SSL', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      decoration: InputDecoration(
                        prefixText: '₦ ',
                        prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFF5A623), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Quick amounts
                    Wrap(
                      spacing: 8,
                      children: _amounts.map((a) {
                        final label = a >= 1000 ? '₦${a ~/ 1000}K' : '₦$a';
                        return GestureDetector(
                          onTap: () => setState(() => _controller.text = a.toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _controller.text == a.toString()
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: _controller.text == a.toString() ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    _methodTile('bank_transfer', Icons.account_balance_rounded, 'Instant Bank Transfer (Virtual Account)'),
                    _methodTile('card', Icons.credit_card_rounded, 'Debit/Credit Card'),
                    _methodTile('ussd', Icons.dialpad_rounded, 'USSD / Mobile Bank App'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generateVirtualAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          disabledBackgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
                        ),
                        child: _isGenerating
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 18, height: 18, child: AppLoader(size: 24)),
                                  SizedBox(width: 10),
                                  Text('Generating Flutterwave Account...'),
                                ],
                              )
                            : const Text('Proceed to Flutterwave Deposit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _methodTile(String value, IconData icon, String label) {
    final isSelected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A).withValues(alpha: 0.04) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade500, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade700)),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0F172A), size: 18),
          ],
        ),
      ),
    );
  }
}
