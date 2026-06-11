import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../properties/models/property_model.dart';
import '../providers/favorites_provider.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  final PropertyModel property;

  const FavoriteButton({super.key, required this.property});

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool? _isFavorite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isFavorite = false);
      return;
    }

    final repo = ref.read(favoritesRepositoryProvider);
    final fav = await repo.isFavorite(uid: uid, propertyId: widget.property.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_isFavorite == null) return;

    final repo = ref.read(favoritesRepositoryProvider);

    final next = !_isFavorite!;
    setState(() => _isFavorite = next); // optimistic

    try {
      if (next) {
        await repo.addFavorite(uid: uid, propertyId: widget.property.id);
      } else {
        await repo.removeFavorite(uid: uid, propertyId: widget.property.id);
      }
    } catch (_) {
      // rollback
      setState(() => _isFavorite = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = _isFavorite ?? false;

    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: Colors.red,
        ),
      ),
    );
  }
}
