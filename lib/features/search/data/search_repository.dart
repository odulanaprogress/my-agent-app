import 'package:cloud_firestore/cloud_firestore.dart';

import '../../properties/models/property_model.dart';

class SearchRepository {
  final FirebaseFirestore _firestore;

  SearchRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _propertiesCollection = 'properties';

  /// Base public query: ONLY approved properties. No orderBy to avoid composite index requirements.
  Query<Map<String, dynamic>> _baseApprovedQuery() {
    return _firestore
        .collection(_propertiesCollection)
        .where('isApproved', isEqualTo: true);
  }

  Stream<List<PropertyModel>> watchApprovedProperties({required int limit}) {
    return _baseApprovedQuery().limit(limit).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// One-shot search (used for pagination next pages).
  Future<List<PropertyModel>> searchApprovedPropertiesOnce({
    required int limit,
    String? startAfterDocId,
    String? searchText,
    String? state,
    String? lga,
    String? category,
    num? minPrice,
    num? maxPrice,
  }) async {
    Query<Map<String, dynamic>> query = _baseApprovedQuery();

    // Equality filters.
    if (state != null && state.trim().isNotEmpty) {
      query = query.where('state', isEqualTo: state.trim());
    }
    if (lga != null && lga.trim().isNotEmpty) {
      query = query.where('lga', isEqualTo: lga.trim());
    }
    if (category != null && category.trim().isNotEmpty) {
      query = query.where('category', isEqualTo: category.trim());
    }

    // Numeric range filters.
    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    // Text search (MVP): Firestore doesn't support arbitrary contains well
    // without a search index. We'll do a best-effort approximation by fetching
    // approved results and refining client-side on a limited subset.
    //
    // Because this is an MVP, we keep the enforcement rule:
    //   still only read approved properties.

    if (startAfterDocId != null) {
      final startAfterDoc = await _firestore
          .collection(_propertiesCollection)
          .doc(startAfterDocId)
          .get();
      if (startAfterDoc.exists) {
        final createdAt = (startAfterDoc.data())?['createdAt'];
        if (createdAt is Timestamp) {
          query = query.startAfter([createdAt]);
        }
      }
    }

    final snapshot = await query.limit(limit).get();
    var results = snapshot.docs
        .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
        .toList();

    final q = searchText?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      results = results.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.community.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q);
      }).toList();
    }

    return results;
  }
}
