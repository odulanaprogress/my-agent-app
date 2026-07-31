import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_repository.dart';
import 'favorites_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../notifications/repositories/notification_repository.dart';

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
      
      // Send notification to landlord
      try {
        final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
        if (doc.exists) {
          final ownerId = doc.data()?['ownerId'];
          final title = doc.data()?['title'] ?? 'your property';
          if (ownerId != null && ownerId != uid) {
            await NotificationRepository().createNotification(
              userId: ownerId,
              title: 'New Favorite ❤️',
              body: 'Someone just added $title to their favorites.',
            );
          }
        }
      } catch (_) {}
    }
  }

  bool isFavorite(String propertyId) => state.contains(propertyId);
}
