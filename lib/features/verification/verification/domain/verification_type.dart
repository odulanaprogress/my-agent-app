enum VerificationType { bvn, nin, internationalPassport, driversLicense, votersCard }

extension VerificationTypeX on VerificationType {
  String get asFirestoreValue => name;

  static VerificationType fromFirestore(String value) {
    return VerificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VerificationType.nin,
    );
  }

  String get displayName {
    switch (this) {
      case VerificationType.bvn:
        return 'Bank Verification Number (BVN)';
      case VerificationType.nin:
        return 'National Identity Number (NIN)';
      case VerificationType.internationalPassport:
        return 'International Passport';
      case VerificationType.driversLicense:
        return "Driver's License";
      case VerificationType.votersCard:
        return "Voter's Card";
    }
  }
}

