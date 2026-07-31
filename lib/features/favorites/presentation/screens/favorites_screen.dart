
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../properties/models/property_model.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/screens/property_details_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/favorites_provider.dart';
import '../providers/favorites_notifier.dart';
import '../../../../core/services/property_service.dart';
import '../../../../core/widgets/skeleton_loader.dart';

class FavoritesScreen extends ConsumerWidget {

  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text('Saved Properties ❤', style: AppTextStyles.title),
      ),
      body: uid.isEmpty
          ? Center(
              child: Text(
                'Please log in to view saved properties.',
                style: AppTextStyles.bodyMedium,
              ),
            )
          // Watch the user's saved property IDs (from Firestore user subcollection)
          : ref.watch(favoritesIdsProvider).when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: 3,
                itemBuilder: (_, __) => const SkeletonCard(),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (ids) {
                if (ids.isEmpty) {
                  return _EmptyState();
                }

                // Fetch all properties and filter locally to avoid Firestore's 30-item 'whereIn' limit.
                // Uses a real-time stream so any property update is reflected immediately.
                return StreamBuilder<List<PropertyModel>>(
                  stream: PropertyService().getApprovedProperties(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: 3,
                        itemBuilder: (_, __) => const SkeletonCard(),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                          child: Text('Error loading properties: ${snap.error}'));
                    }

                    final allProps = snap.data ?? [];
                    final propMap = {for (var p in allProps) p.id: p};

                    // Keep the user's saved order (most recently saved first)
                    // and filter out any properties that no longer exist or aren't approved.
                    final savedProps = ids
                        .where((id) => propMap.containsKey(id))
                        .map((id) => propMap[id]!)
                        .toList();

                    if (savedProps.isEmpty) {
                      return _EmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: savedProps.length,
                      itemBuilder: (context, index) {
                        final property = savedProps[index];
                        final isFav = ref
                            .watch(favoritesNotifierProvider)
                            .contains(property.id);

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PropertyDetailsScreen(property: property),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: Stack(
                                    children: [

                                      property.imageUrl.isNotEmpty
                                          ? Image.network(
                                              property.imageUrl,
                                              width: double.infinity,
                                              height: 200,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (ctx, err, st) => Container(
                                                height: 200,
                                                color: Colors.grey.shade200,
                                                child: const Center(
                                                    child: Icon(Icons.home,
                                                        size: 60,
                                                        color: Colors.grey)),
                                              ),
                                            )
                                          : Container(
                                              height: 200,
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child: Icon(Icons.home,
                                                    size: 60,
                                                    color: Colors.grey),
                                              ),
                                            ),
                                      // Remove button (heart)
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: () async {
                                            await ref
                                                .read(favoritesNotifierProvider
                                                    .notifier)
                                                .toggleFavorite(property.id);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              isFav
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFav
                                                  ? Colors.red
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        property.title,
                                        style: AppTextStyles.title,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                              Icons.location_on_outlined,
                                              size: 14,
                                              color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              property.location,
                                              style: AppTextStyles.caption,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₦${_formatPrice(property.price)}',
                                            style:
                                                AppTextStyles.title.copyWith(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              property.category
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatPrice(num price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    }
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'No saved properties yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the ❤ on any property to save it here for later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
