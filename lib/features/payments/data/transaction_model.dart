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

  factory TransactionModel.fromFirestore(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      tenantId: (map['tenantId'] ?? '') as String,
      landlordId: (map['landlordId'] ?? '') as String,
      propertyId: (map['propertyId'] ?? '') as String,
      amount: (map['amount'] ?? 0) is int
          ? map['amount'] as int
          : int.tryParse((map['amount'] ?? '0').toString()) ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      type: (map['type'] ?? '').toString(),
      createdAt: map['createdAt'] as Timestamp,

      possessionConfirmed: map['possessionConfirmed'] ?? false,
      possessionConfirmedAt: map['possessionConfirmedAt'] as Timestamp?,
      landlordPaidOut: map['landlordPaidOut'] ?? false,
      payoutAt: map['payoutAt'] as Timestamp?,
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
    };
  }
}
