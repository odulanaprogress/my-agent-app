import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../properties/models/property_model.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/screens/property_details_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/property_service.dart';
import '../../../../core/constants/mock_properties.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final propertyService = PropertyService();

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
        title: Text('Favorites ❤', style: AppTextStyles.title),
      ),
      body: uid.isEmpty
          ? Center(
              child: Text(
                'Please log in to view favorites.',
                style: AppTextStyles.bodyMedium,
              ),
            )
          : ref.watch(favoritesIdsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (ids) {
                if (ids.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No saved properties yet',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  );
                }

                return StreamBuilder<List<PropertyModel>>(
                  stream: propertyService.getApprovedProperties(),
                  builder: (context, propSnap) {
                    if (propSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allProps = propSnap.data ?? [];
                    final Map<String, PropertyModel> uniqueProps = {};
                    for (final p in mockProperties) {
                      uniqueProps[p.id] = p;
                    }
                    for (final p in allProps) {
                      uniqueProps[p.id] = p;
                    }
                    final savedProps = uniqueProps.values
                        .where((p) => ids.contains(p.id))
                        .toList();

                    if (savedProps.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'No saved properties yet',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: savedProps.length,
                      itemBuilder: (context, index) {
                        final property = savedProps[index];

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PropertyDetailsScreen(property: property),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: property.imageUrl.isNotEmpty
                                      ? Image.network(
                                          property.imageUrl,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          height: 200,
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: Icon(Icons.home, size: 60),
                                          ),
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
                                      const SizedBox(height: 8),
                                      Text(
                                        property.location,
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₦${property.price}',
                                            style: AppTextStyles.title.copyWith(
                                              color: AppColors.primary,
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
}
