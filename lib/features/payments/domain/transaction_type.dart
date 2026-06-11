enum TransactionType { escrow, deposit, withdrawal, refund }

extension TransactionTypeX on TransactionType {
  String get asFirestoreValue => name;

  static TransactionType fromFirestore(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransactionType.escrow,
    );
  }
}
