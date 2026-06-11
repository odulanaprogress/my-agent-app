import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_repository.dart';
import 'favorites_provider.dart';

// ── Toggle notifier ──────────────────────────────────────────────────────────
//
// Reads the current uid from FirebaseAuth at the moment of each action so it
// is never stale.  State is seeded from the Firestore stream via ref.listen.

final favoritesNotifierProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final repository = ref.watch(favoritesRepositoryProvider);
  final notifier = FavoritesNotifier(repository);

  // Keep local state in sync with the Firestore stream.
  ref.listen<AsyncValue<List<String>>>(
    favoritesIdsProvider,
    (_, next) {
      next.whenData((ids) => notifier.syncFromFirestore(ids.toSet()));
    },
    fireImmediately: true,
  );

  return notifier;
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final FavoritesRepository _repository;

  FavoritesNotifier(this._repository) : super({});

  /// Called by ref.listen to mirror the Firestore truth.
  void syncFromFirestore(Set<String> ids) {
    state = ids;
  }

  Future<void> toggleFavorite(String propertyId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isCurrentlyFavorite = state.contains(propertyId);

    // Optimistic update.
    if (isCurrentlyFavorite) {
      state = {...state}..remove(propertyId);
      await _repository.removeFavorite(uid: uid, propertyId: propertyId);
    } else {
      state = {...state, propertyId};
      await _repository.addFavorite(uid: uid, propertyId: propertyId);
    }
  }

  bool isFavorite(String propertyId) => state.contains(propertyId);
}
