import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/verification_repository.dart';
import '../domain/verification_status.dart';
import '../domain/verification_type.dart';

import '../../../auth/presentation/providers/current_user_provider.dart';

class VerificationState {
  final bool loading;
  final VerificationStatus status;
  final String? error;
  final String? rejectionReason;
  final Map<String, dynamic>? documentData;

  const VerificationState({
    required this.loading,
    required this.status,
    this.error,
    this.rejectionReason,
    this.documentData,
  });

  factory VerificationState.initial() => const VerificationState(
    loading: false,
    status: VerificationStatus.none,
    rejectionReason: null,
    documentData: null,
  );

  VerificationState copyWith({
    bool? loading,
    VerificationStatus? status,
    String? error,
    String? rejectionReason,
    Map<String, dynamic>? documentData,
  }) {
    return VerificationState(
      loading: loading ?? this.loading,
      status: status ?? this.status,
      error: error,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      documentData: documentData ?? this.documentData,
    );
  }
}

class VerificationController {
  VerificationController({required this.ref, required this.repository});

  final Ref ref;
  final VerificationRepository repository;

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final doc = await repository.getVerificationDoc(user.uid);
    if (doc == null) {
      ref.read(_verificationStateProvider.notifier).state = ref
          .read(_verificationStateProvider)
          .copyWith(status: VerificationStatus.none, rejectionReason: null, documentData: null);
      return;
    }

    final statusValue = (doc['status'] ?? 'none').toString();
    final st = VerificationStatusX.fromFirestore(statusValue);
    final reason = doc['rejectionReason'] as String?;

    ref.read(_verificationStateProvider.notifier).state = ref
        .read(_verificationStateProvider)
        .copyWith(status: st, rejectionReason: reason, documentData: doc);
  }

  Future<void> submitVerification({
    required VerificationType verificationType,
    required String fullName,
    String? documentNumber,
    String? documentFront,
    String? documentBack,
    String? selfieImage,
    String? propertyOwnershipDoc,
    String? utilityBill,
    String? role,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw StateError('No current user');
    }

    ref.read(_verificationStateProvider.notifier).state = ref
        .read(_verificationStateProvider)
        .copyWith(loading: true, error: null);

    try {
      await repository.upsertVerification(
        uid: user.uid,
        verificationType: verificationType.asFirestoreValue,
        fullName: fullName,
        documentNumber: documentNumber,
        documentFront: documentFront,
        documentBack: documentBack,
        selfieImage: selfieImage,
        propertyOwnershipDoc: propertyOwnershipDoc,
        utilityBill: utilityBill,
        role: role,
        email: user.email,
        status: VerificationStatus.pending,
        submittedAt: DateTime.now(),
        reviewedAt: null,
        rejectionReason: null,
      );


      ref.read(_verificationStateProvider.notifier).state = ref
          .read(_verificationStateProvider)
          .copyWith(loading: false, status: VerificationStatus.pending);
    } catch (e) {
      ref.read(_verificationStateProvider.notifier).state = ref
          .read(_verificationStateProvider)
          .copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> adminReview({
    required String uid,
    required VerificationStatus newStatus,
    required String reason,
  }) async {
    // Admin bypass rules should be enforced in backend / security rules.
    await repository.reviewVerification(
      uid: uid,
      newStatus: newStatus,
      reviewedReason: reason,
    );
  }
}

final _verificationStateProvider = StateProvider<VerificationState>(
  (ref) => VerificationState.initial(),
);

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepository(FirebaseFirestore.instance);
});

final verificationControllerProvider = Provider<VerificationController>((ref) {
  return VerificationController(
    ref: ref,
    repository: ref.watch(verificationRepositoryProvider),
  );
});

final verificationStateProvider = Provider<VerificationState>((ref) {
  return ref.watch(_verificationStateProvider);
});
