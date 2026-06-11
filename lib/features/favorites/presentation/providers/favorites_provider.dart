import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/favorites_repository.dart';

// ── Infrastructure providers ─────────────────────────────────────────────────

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.read(firebaseFirestoreProvider)),
);

// ── Auth stream so every downstream provider reacts to login/logout ──────────

final _authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ── Reactive stream of favorited property IDs for current user ───────────────
//
// This provider is consumed by FavoritesScreen and by the toggle button in
// PropertyDetailsScreen. It automatically emits a new list whenever:
//   • the user favorites / un-favorites a property (Firestore snapshot), OR
//   • the current user changes (login / logout).

final favoritesIdsProvider = StreamProvider<List<String>>((ref) {
  // Re-evaluate whenever the signed-in user changes.
  final authAsync = ref.watch(_authUserProvider);

  return authAsync.when(
    data: (user) {
      if (user == null) return Stream.value(<String>[]);
      final repo = ref.watch(favoritesRepositoryProvider);
      return repo.getFavoritesPropertyIds(user.uid);
    },
    loading: () => Stream.value(<String>[]),
    error: (e, _) => Stream.value(<String>[]),
  );
});
