import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight TransactionModel for escrow/possession/payout lifecycle.
///
/// NOTE: This repo currently does not have a transaction model file.
/// Step 20 adds escrow foundation by persisting these fields.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.tenantId,
    required this.landlordId,
    required this.propertyId,
    required this.amount,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.possessionConfirmed,
    required this.possessionConfirmedAt,
    required this.landlordPaidOut,
    required this.payoutAt,
    this.tenantPinVerified = false,
    this.landlordPinVerified = false,
    this.commissionPercent = 5.0,
    this.commissionAmount = 0,
    this.netPayoutAmount = 0,
    this.virtualAccountNumber,
    this.virtualBankName,
    this.virtualAccountName,
    this.txRef,
    this.paidAt,
  });

  final String id;
  final String tenantId;
  final String landlordId;
  final String propertyId;
  final int amount;
  final String status;
  final String type;
  final Timestamp createdAt;

  final bool possessionConfirmed;
  final Timestamp? possessionConfirmedAt;
  final bool landlordPaidOut;
  final Timestamp? payoutAt;

  // Dual Escrow PIN Verification Fields
  final bool tenantPinVerified;
  final bool landlordPinVerified;

  // Revenue & Payout Breakdown
  final double commissionPercent;
  final int commissionAmount;
  final int netPayoutAmount;

  // Flutterwave Virtual Account & Receipt metadata
  final String? virtualAccountNumber;
  final String? virtualBankName;
  final String? virtualAccountName;
  final String? txRef;
  final Timestamp? paidAt;

  factory TransactionModel.fromFirestore(String id, Map<String, dynamic> map) {
    int parseAmount(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic val, double fallback) {
      if (val is double) return val;
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '') ?? fallback;
    }

    Timestamp parseTimestamp(dynamic val) {
      if (val is Timestamp) return val;
      if (val is DateTime) return Timestamp.fromDate(val);
      return Timestamp.now();
    }

    Timestamp? parseNullableTimestamp(dynamic val) {
      if (val is Timestamp) return val;
      if (val is DateTime) return Timestamp.fromDate(val);
      return null;
    }

    final amt = parseAmount(map['amount']);
    final commPct = parseDouble(map['commissionPercent'], 5.0);
    final commAmt = map['commissionAmount'] != null
        ? parseAmount(map['commissionAmount'])
        : (amt * (commPct / 100)).round();
    final netAmt = map['netPayoutAmount'] != null
        ? parseAmount(map['netPayoutAmount'])
        : (amt - commAmt);

    return TransactionModel(
      id: id,
      tenantId: map['tenantId']?.toString() ?? '',
      landlordId: map['landlordId']?.toString() ?? '',
      propertyId: map['propertyId']?.toString() ?? '',
      amount: amt,
      status: map['status']?.toString() ?? 'pending',
      type: map['type']?.toString() ?? 'escrow',
      createdAt: parseTimestamp(map['createdAt']),

      possessionConfirmed: map['possessionConfirmed'] == true,
      possessionConfirmedAt: parseNullableTimestamp(map['possessionConfirmedAt']),
      landlordPaidOut: map['landlordPaidOut'] == true,
      payoutAt: parseNullableTimestamp(map['payoutAt']),

      tenantPinVerified: map['tenantPinVerified'] == true,
      landlordPinVerified: map['landlordPinVerified'] == true,
      commissionPercent: commPct,
      commissionAmount: commAmt,
      netPayoutAmount: netAmt,

      virtualAccountNumber: map['virtualAccountNumber']?.toString(),
      virtualBankName: map['virtualBankName']?.toString(),
      virtualAccountName: map['virtualAccountName']?.toString(),
      txRef: map['txRef']?.toString(),
      paidAt: parseNullableTimestamp(map['paidAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'landlordId': landlordId,
      'propertyId': propertyId,
      'amount': amount,
      'status': status,
      'type': type,
      'createdAt': createdAt,

      'possessionConfirmed': possessionConfirmed,
      'possessionConfirmedAt': possessionConfirmedAt,
      'landlordPaidOut': landlordPaidOut,
      'payoutAt': payoutAt,

      'tenantPinVerified': tenantPinVerified,
      'landlordPinVerified': landlordPinVerified,
      'commissionPercent': commissionPercent,
      'commissionAmount': commissionAmount,
      'netPayoutAmount': netPayoutAmount,

      'virtualAccountNumber': virtualAccountNumber,
      'virtualBankName': virtualBankName,
      'virtualAccountName': virtualAccountName,
      'txRef': txRef,
      'paidAt': paidAt,
    };
  }
}


