enum VerificationStatus { pending, approved, rejected, expired }

extension VerificationStatusX on VerificationStatus {
  String get asFirestoreValue => name;

  static VerificationStatus fromFirestore(String value) {
    return VerificationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VerificationStatus.pending,
    );
  }
}
