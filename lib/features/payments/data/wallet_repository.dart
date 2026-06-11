import 'package:cloud_firestore/cloud_firestore.dart';

class WalletData {
  final int availableBalance;
  final int escrowBalance;

  const WalletData({
    required this.availableBalance,
    required this.escrowBalance,
  });

  int get totalBalance => availableBalance + escrowBalance;
}

class WalletRepository {
  WalletRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _wallets =>
      _firestore.collection('wallets');

  DocumentReference<Map<String, dynamic>> docFor(String uid) =>
      _wallets.doc(uid);

  Future<int> getBalance(String uid) async {
    final snap = await docFor(uid).get();
    if (!snap.exists) return 0;
    final data = snap.data()!;
    final raw = data['availableBalance'] ?? data['balance'];
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<WalletData> getWalletData(String uid) async {
    final snap = await docFor(uid).get();
    if (!snap.exists) return const WalletData(availableBalance: 0, escrowBalance: 0);
    final data = snap.data()!;

    int avail = 0;
    int escrow = 0;

    final rawAvail = data['availableBalance'] ?? data['balance'];
    if (rawAvail is num) avail = rawAvail.toInt();

    final rawEscrow = data['escrowBalance'];
    if (rawEscrow is num) escrow = rawEscrow.toInt();

    return WalletData(availableBalance: avail, escrowBalance: escrow);
  }

  Stream<WalletData> watchWalletData(String uid) {
    return docFor(uid).snapshots().map((snap) {
      if (!snap.exists) return const WalletData(availableBalance: 0, escrowBalance: 0);
      final data = snap.data()!;

      int avail = 0;
      int escrow = 0;

      final rawAvail = data['availableBalance'] ?? data['balance'];
      if (rawAvail is num) avail = rawAvail.toInt();

      final rawEscrow = data['escrowBalance'];
      if (rawEscrow is num) escrow = rawEscrow.toInt();

      return WalletData(availableBalance: avail, escrowBalance: escrow);
    });
  }

  /// Atomically increments available wallet balance by [delta].
  Future<void> incrementBalance({
    required String uid,
    required int delta,
    required DateTime updatedAt,
  }) async {
    await _firestore.runTransaction((tx) async {
      final ref = docFor(uid);
      final snap = await tx.get(ref);
      final currentBalance = snap.exists
          ? (snap.data()!['availableBalance'] ?? snap.data()!['balance'] as num?)?.toInt() ?? 0
          : 0;

      tx.set(ref, {
        'uid': uid,
        'availableBalance': currentBalance + delta,
        'balance': currentBalance + delta, // keep legacy field in sync
        'updatedAt': Timestamp.fromDate(updatedAt),
      }, SetOptions(merge: true));
    });
  }

  /// Move funds from available to escrow (when payment is initiated).
  Future<void> holdInEscrow({
    required String uid,
    required int amount,
  }) async {
    await _firestore.runTransaction((tx) async {
      final ref = docFor(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};

      final currentAvail = (data['availableBalance'] ?? data['balance'] as num?)?.toInt() ?? 0;
      final currentEscrow = (data['escrowBalance'] as num?)?.toInt() ?? 0;

      if (currentAvail < amount) throw StateError('Insufficient available balance');

      tx.set(ref, {
        'uid': uid,
        'availableBalance': currentAvail - amount,
        'balance': currentAvail - amount,
        'escrowBalance': currentEscrow + amount,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    });
  }

  /// Release escrow funds to landlord (on possession confirmation).
  Future<void> releaseEscrow({
    required String tenantUid,
    required String landlordUid,
    required int amount,
  }) async {
    final batch = _firestore.batch();

    // Deduct from tenant's escrow
    final tenantRef = docFor(tenantUid);
    final tenantSnap = await tenantRef.get();
    final tenantData = tenantSnap.data() ?? {};
    final tenantEscrow = (tenantData['escrowBalance'] as num?)?.toInt() ?? 0;
    batch.set(tenantRef, {
      'escrowBalance': (tenantEscrow - amount).clamp(0, double.maxFinite.toInt()),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    // Add to landlord's available balance
    final landlordRef = docFor(landlordUid);
    final landlordSnap = await landlordRef.get();
    final landlordData = landlordSnap.data() ?? {};
    final landlordAvail = (landlordData['availableBalance'] ?? landlordData['balance'] as num?)?.toInt() ?? 0;
    batch.set(landlordRef, {
      'availableBalance': landlordAvail + amount,
      'balance': landlordAvail + amount,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
