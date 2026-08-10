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

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaystackDepositSheet(),
    );
    if (result != null && result > 0) {
      setState(() => _isProcessingDeposit = true);
      try {
        await ref.read(paymentControllerProvider).deposit(amount: result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('₦$result successfully deposited via Paystack!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) _snack('Deposit failed: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isProcessingDeposit = false);
      }
    }
  }

  Future<void> _showWithdrawSheet(int availableBalance) async {
    final allowed = await KycGate.require(context, ref);
    if (!allowed) return;

    if (!mounted) return;

    final currentUser = ref.read(currentUserProvider);
    final amountController = TextEditingController(text: availableBalance > 0 ? availableBalance.toString() : '');
    final accountController = TextEditingController();
    String selectedBankCode = '058';
    String selectedBankName = 'Guaranty Trust Bank (GTBank)';

    bool isProcessing = false;
    bool isResolving = false;
    String? resolvedAccountName;
    String? resolveError;
    String? transferError;

    final banks = [
      {'code': '058', 'name': 'Guaranty Trust Bank (GTBank)'},
      {'code': '044', 'name': 'Access Bank'},
      {'code': '057', 'name': 'Zenith Bank PLC'},
      {'code': '033', 'name': 'United Bank for Africa (UBA)'},
      {'code': '011', 'name': 'First Bank of Nigeria'},
      {'code': '100004', 'name': 'OPay Digital Services'},
      {'code': '100033', 'name': 'PalmPay'},
      {'code': '090405', 'name': 'Moniepoint Microfinance Bank'},
      {'code': '090267', 'name': 'Kuda Bank'},
      {'code': '035', 'name': 'Wema Bank PLC'},
      {'code': '214', 'name': 'First City Monument Bank (FCMB)'},
      {'code': '070', 'name': 'Fidelity Bank'},
      {'code': '232', 'name': 'Sterling Bank'},
      {'code': '032', 'name': 'Union Bank of Nigeria'},
      {'code': '221', 'name': 'Stanbic IBTC Bank'},
    ];

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
              setModalState(() {
                isResolving = false;
                resolveError = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '').trim();
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
                              final amt = int.tryParse(amountController.text.trim()) ?? 0;
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
                                await EscrowApiService().disburseLandlordPayout(
                                  transactionId: 'WITHDRAW_${DateTime.now().millisecondsSinceEpoch}',
                                  amount: amt,
                                  bankCode: selectedBankCode,
                                  accountNumber: acct,
                                );

                                // Deduct balance in Firestore
                                if (currentUser != null) {
                                  await WalletRepository(FirebaseFirestore.instance).incrementBalance(
                                    uid: currentUser.uid,
                                    delta: -amt,
                                    updatedAt: DateTime.now(),
                                  );
                                }

                                Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  _snack('🎉 ₦$amt withdrawal sent to $acct (${resolvedAccountName ?? selectedBankName}) via Flutterwave!');
                                }
                              } catch (e) {
                                final errStr = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '').trim();
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
              if (user == null) return;
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
                    .where('landlordId', isEqualTo: user.uid)
                    .get();
                
                int totalReleased = 0;
                for (var doc in txs.docs) {
                  final data = doc.data();
                  if (data['status'] == 'released' || data['status'] == 'completed') {
                    final amt = data['netPayoutAmount'] ?? data['amount'] ?? 0;
                    totalReleased += (amt as num).toInt();
                  }
                }

                await FirebaseFirestore.instance.collection('wallets').doc(user.uid).set({
                  'availableBalance': totalReleased,
                  'balance': totalReleased,
                  'updatedAt': Timestamp.now(),
                }, SetOptions(merge: true));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Wallet Synced Successfully!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

// ── Paystack Deposit Sheet ────────────────────────────────────────────────────
class _PaystackDepositSheet extends StatefulWidget {
  @override
  State<_PaystackDepositSheet> createState() => _PaystackDepositSheetState();
}

class _PaystackDepositSheetState extends State<_PaystackDepositSheet> {
  final _controller = TextEditingController(text: '10000');
  String? _selectedMethod;
  bool _isProcessing = false;

  static const _amounts = [5000, 10000, 25000, 50000, 100000];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _processDeposit() async {
    final amount = int.tryParse(_controller.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate Paystack
    if (mounted) Navigator.pop(context, amount);
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF09A5DB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF09A5DB).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF09A5DB), size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'Paystack Secure Deposit',
                    style: TextStyle(
                      color: Color(0xFF09A5DB),
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
                        borderSide: const BorderSide(color: Color(0xFF09A5DB), width: 2),
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
                  ...[
                    ('card', Icons.credit_card_rounded, 'Debit/Credit Card'),
                    ('bank', Icons.account_balance_rounded, 'Bank Transfer'),
                    ('ussd', Icons.dialpad_rounded, 'USSD'),
                  ].map((m) => _methodTile(m.$1, m.$2, m.$3)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processDeposit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF09A5DB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: const Color(0xFF09A5DB).withValues(alpha: 0.5),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 18, height: 18, child: AppLoader(size: 24)),
                                SizedBox(width: 10),
                                Text('Processing via Paystack...'),
                              ],
                            )
                          : const Text('Deposit Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
