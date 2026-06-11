enum EscrowStatus { pending, held, released, refunded, failed, cancelled }

extension EscrowStatusX on EscrowStatus {
  String get asFirestoreValue => name;

  static EscrowStatus fromFirestore(String value) {
    // Defensive parsing: map to enum by name. Unknown -> pending.
    return EscrowStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EscrowStatus.pending,
    );
  }
}
