import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rent_subscription_model.dart';

class RentSubscriptionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('rent_subscriptions');

  /// Create a new 12-month rental subscription
  Future<String> createSubscription({
    required String tenantId,
    required String landlordId,
    required String propertyId,
    required String propertyTitle,
    required String propertyAddress,
    required num monthlyAmount,
    required num annualAmount,
    required num securityDeposit,
    required num platformFee,
    required String initialTransactionId,
  }) async {
    final docRef = _collection.doc();
    final now = DateTime.now();
    final nextDueDate = DateTime(now.year, now.month + 1, now.day);

    final schedule = RentSubscriptionModel.generateSchedule(
      monthlyAmount: monthlyAmount,
      startDate: now,
      firstTransactionId: initialTransactionId,
    );

    final model = RentSubscriptionModel(
      id: docRef.id,
      tenantId: tenantId,
      landlordId: landlordId,
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      propertyAddress: propertyAddress,
      frequency: 'monthly',
      totalMonths: 12,
      completedMonths: 1,
      monthlyAmount: monthlyAmount,
      annualAmount: annualAmount,
      securityDeposit: securityDeposit,
      platformFee: platformFee,
      status: 'active',
      nextDueDate: nextDueDate,
      createdAt: now,
      installments: schedule,
    );

    await docRef.set(model.toMap());
    return docRef.id;
  }

  /// Stream of active subscriptions for a tenant
  Stream<List<RentSubscriptionModel>> getTenantSubscriptions(String tenantId) {
    return _collection
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RentSubscriptionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream of active subscriptions for a landlord
  Stream<List<RentSubscriptionModel>> getLandlordSubscriptions(String landlordId) {
    return _collection
        .where('landlordId', isEqualTo: landlordId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RentSubscriptionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream of a single subscription
  Stream<RentSubscriptionModel?> getSubscription(String subscriptionId) {
    return _collection.doc(subscriptionId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return RentSubscriptionModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Mark an installment as paid
  Future<void> markInstallmentPaid({
    required String subscriptionId,
    required int monthNumber,
    required String transactionId,
  }) async {
    final docRef = _collection.doc(subscriptionId);
    final doc = await docRef.get();
    if (!doc.exists || doc.data() == null) return;

    final sub = RentSubscriptionModel.fromMap(doc.data()!, doc.id);
    final updatedInstallments = sub.installments.map((inst) {
      if (inst.monthNumber == monthNumber) {
        return PaymentInstallment(
          monthNumber: inst.monthNumber,
          dueDate: inst.dueDate,
          amount: inst.amount,
          status: 'paid',
          paidAt: DateTime.now(),
          transactionId: transactionId,
        );
      }
      return inst;
    }).toList();

    final completedCount = updatedInstallments.where((i) => i.status == 'paid').length;
    final nextPending = updatedInstallments.firstWhere(
      (i) => i.status != 'paid',
      orElse: () => updatedInstallments.last,
    );

    await docRef.update({
      'installments': updatedInstallments.map((i) => i.toMap()).toList(),
      'completedMonths': completedCount,
      'nextDueDate': Timestamp.fromDate(nextPending.dueDate),
      'status': completedCount >= sub.totalMonths ? 'completed' : 'active',
    });
  }
}
