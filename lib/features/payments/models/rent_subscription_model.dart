import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentInstallment {
  final int monthNumber;
  final DateTime dueDate;
  final num amount;
  final String status; // 'paid' | 'due' | 'upcoming' | 'overdue'
  final DateTime? paidAt;
  final String? transactionId;

  const PaymentInstallment({
    required this.monthNumber,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidAt,
    this.transactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'monthNumber': monthNumber,
      'dueDate': Timestamp.fromDate(dueDate),
      'amount': amount,
      'status': status,
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      if (transactionId != null) 'transactionId': transactionId,
    };
  }

  factory PaymentInstallment.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return PaymentInstallment(
      monthNumber: (map['monthNumber'] as num?)?.toInt() ?? 1,
      dueDate: parseDate(map['dueDate']),
      amount: (map['amount'] as num?) ?? 0,
      status: map['status']?.toString() ?? 'upcoming',
      paidAt: map['paidAt'] != null ? parseDate(map['paidAt']) : null,
      transactionId: map['transactionId']?.toString(),
    );
  }
}

class RentSubscriptionModel {
  final String id;
  final String tenantId;
  final String landlordId;
  final String propertyId;
  final String propertyTitle;
  final String propertyAddress;
  final String frequency; // 'monthly' | 'annual'
  final int totalMonths;
  final int completedMonths;
  final num monthlyAmount;
  final num annualAmount;
  final num securityDeposit;
  final num platformFee;
  final String status; // 'active' | 'overdue' | 'completed' | 'cancelled'
  final DateTime nextDueDate;
  final DateTime createdAt;
  final List<PaymentInstallment> installments;

  const RentSubscriptionModel({
    required this.id,
    required this.tenantId,
    required this.landlordId,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyAddress,
    this.frequency = 'monthly',
    this.totalMonths = 12,
    this.completedMonths = 1,
    required this.monthlyAmount,
    required this.annualAmount,
    required this.securityDeposit,
    required this.platformFee,
    this.status = 'active',
    required this.nextDueDate,
    required this.createdAt,
    this.installments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'landlordId': landlordId,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'propertyAddress': propertyAddress,
      'frequency': frequency,
      'totalMonths': totalMonths,
      'completedMonths': completedMonths,
      'monthlyAmount': monthlyAmount,
      'annualAmount': annualAmount,
      'securityDeposit': securityDeposit,
      'platformFee': platformFee,
      'status': status,
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'installments': installments.map((i) => i.toMap()).toList(),
    };
  }

  factory RentSubscriptionModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawInstallments = map['installments'];
    List<PaymentInstallment> list = [];
    if (rawInstallments is List) {
      list = rawInstallments
          .whereType<Map<String, dynamic>>()
          .map(PaymentInstallment.fromMap)
          .toList();
    }

    return RentSubscriptionModel(
      id: documentId,
      tenantId: map['tenantId']?.toString() ?? '',
      landlordId: map['landlordId']?.toString() ?? '',
      propertyId: map['propertyId']?.toString() ?? '',
      propertyTitle: map['propertyTitle']?.toString() ?? 'Rental Property',
      propertyAddress: map['propertyAddress']?.toString() ?? '',
      frequency: map['frequency']?.toString() ?? 'monthly',
      totalMonths: (map['totalMonths'] as num?)?.toInt() ?? 12,
      completedMonths: (map['completedMonths'] as num?)?.toInt() ?? 1,
      monthlyAmount: (map['monthlyAmount'] as num?) ?? 0,
      annualAmount: (map['annualAmount'] as num?) ?? 0,
      securityDeposit: (map['securityDeposit'] as num?) ?? 0,
      platformFee: (map['platformFee'] as num?) ?? 0,
      status: map['status']?.toString() ?? 'active',
      nextDueDate: parseDate(map['nextDueDate']),
      createdAt: parseDate(map['createdAt']),
      installments: list,
    );
  }

  /// Helper to generate a fresh 12-month installment schedule upon creation
  static List<PaymentInstallment> generateSchedule({
    required num monthlyAmount,
    required DateTime startDate,
    required String firstTransactionId,
  }) {
    final schedule = <PaymentInstallment>[];
    for (int i = 1; i <= 12; i++) {
      final dueDate = DateTime(startDate.year, startDate.month + (i - 1), startDate.day);
      final isFirstMonth = i == 1;
      schedule.add(
        PaymentInstallment(
          monthNumber: i,
          dueDate: dueDate,
          amount: monthlyAmount,
          status: isFirstMonth ? 'paid' : 'upcoming',
          paidAt: isFirstMonth ? startDate : null,
          transactionId: isFirstMonth ? firstTransactionId : null,
        ),
      );
    }
    return schedule;
  }
}
