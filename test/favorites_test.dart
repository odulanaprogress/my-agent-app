import 'package:flutter_test/flutter_test.dart';
import 'package:agent_app/features/favorites/data/favorites_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockFirebaseFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('FavoritesRepository can be instantiated and exposes methods', () {
    final firestore = MockFirebaseFirestore();
    final repo = FavoritesRepository(firestore);
    expect(repo, isNotNull);
  });
}
