import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/payment_repository.dart';
import '../data/wallet_repository.dart';
import '../data/escrow_repository.dart';
import '../data/transaction_model.dart';
import '../domain/escrow_status.dart';

import '../../../features/auth/presentation/providers/current_user_provider.dart';

class PaymentState {
  final int balance;
  final bool loading;
  final String? error;

  const PaymentState({
    required this.balance,
    required this.loading,
    this.error,
  });

  factory PaymentState.initial() =>
      const PaymentState(balance: 0, loading: false);

  PaymentState copyWith({int? balance, bool? loading, String? error}) {
    return PaymentState(
      balance: balance ?? this.balance,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class PaymentController {
  PaymentController({
    required this.ref,
    required this.paymentRepository,
    required this.walletRepository,
    required this.escrowRepository,
  });

  final Ref ref;
  final PaymentRepository paymentRepository;
  final WalletRepository walletRepository;
  final EscrowRepository escrowRepository;

  Future<void> refreshWalletBalance() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final nextBalance = await walletRepository.getBalance(user.uid);
    ref.read(_paymentStateProvider.notifier).state = ref
        .read(_paymentStateProvider)
        .copyWith(balance: nextBalance);
  }

  /// Placeholder deposit action (demo only). Later: separate available/escrow buckets.
  Future<void> deposit({required int amount}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final stateNotifier = ref.read(_paymentStateProvider.notifier);
    stateNotifier.state = stateNotifier.state.copyWith(
      loading: true,
      error: null,
    );

    try {
      await walletRepository.incrementBalance(
        uid: user.uid,
        delta: amount,
        updatedAt: DateTime.now(),
      );

      final nextBalance = await walletRepository.getBalance(user.uid);
      stateNotifier.state = stateNotifier.state.copyWith(
        balance: nextBalance,
        loading: false,
      );
    } catch (e) {
      stateNotifier.state = stateNotifier.state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  /// Withdraw action with naive balance check (real enforcement must be backend).
  Future<void> withdraw({required int amount}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final stateNotifier = ref.read(_paymentStateProvider.notifier);
    stateNotifier.state = stateNotifier.state.copyWith(
      loading: true,
      error: null,
    );

    try {
      final current = await walletRepository.getBalance(user.uid);
      if (current < amount) {
        throw StateError('Insufficient balance');
      }

      await walletRepository.incrementBalance(
        uid: user.uid,
        delta: -amount,
        updatedAt: DateTime.now(),
      );

      final nextBalance = await walletRepository.getBalance(user.uid);
      stateNotifier.state = stateNotifier.state.copyWith(
        balance: nextBalance,
        loading: false,
      );
    } catch (e) {
      stateNotifier.state = stateNotifier.state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<String> createEscrowPayment({
    required String landlordId,
    required String propertyId,
    required int amount,
    String? transactionId,
  }) async {
    final tenant = ref.read(currentUserProvider);
    if (tenant == null) {
      throw StateError('No current user');
    }

    final id =
        transactionId ??
        FirebaseFirestore.instance.collection('transactions').doc().id;

    // SECURITY NOTE: This demo provider does not deduct/hold funds yet.
    // We create the transaction and mark it as `held`.
    await paymentRepository.createEscrowTransaction(
      transactionId: id,
      tenantId: tenant.uid,
      landlordId: landlordId,
      propertyId: propertyId,
      amount: amount,
      status: EscrowStatus.held,
      createdAt: DateTime.now(),
    );

    return id;
  }

  Future<void> confirmPossession({required String transactionId}) async {
    // held -> released (demo assumes valid transition)
    await paymentRepository.transitionEscrowStatus(
      transactionId: transactionId,
      from: EscrowStatus.held,
      to: EscrowStatus.released,
    );
  }

  Future<void> requestRefund({required String transactionId}) async {
    await paymentRepository.transitionEscrowStatus(
      transactionId: transactionId,
      from: EscrowStatus.held,
      to: EscrowStatus.refunded,
    );
  }
}

final _paymentStateProvider = StateProvider<PaymentState>(
  (ref) => PaymentState.initial(),
);

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(FirebaseFirestore.instance);
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(FirebaseFirestore.instance);
});

final escrowRepositoryProvider = Provider<EscrowRepository>((ref) {
  return EscrowRepository(FirebaseFirestore.instance);
});

final paymentControllerProvider = Provider<PaymentController>((ref) {
  return PaymentController(
    ref: ref,
    paymentRepository: ref.watch(paymentRepositoryProvider),
    walletRepository: ref.watch(walletRepositoryProvider),
    escrowRepository: ref.watch(escrowRepositoryProvider),
  );
});

final paymentStateProvider = Provider<PaymentState>((ref) {
  return ref.watch(_paymentStateProvider);
});

final tenantTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getTenantTransactions();
});

final landlordTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getLandlordTransactions();
});

final adminTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getAllTransactions();
});
