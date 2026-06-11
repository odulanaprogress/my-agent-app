import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../properties/models/property_model.dart';
import '../providers/search_provider.dart';
import '../../../../core/services/user_behavior_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _propertyTile(PropertyModel p, BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/properties/details', extra: p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: p.imageUrl.isNotEmpty
                  ? Image.network(
                      p.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 180,
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.home, size: 60)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(p.location, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 14),
                  Text(
                    '₦${p.price}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(searchControllerProvider);
    final searchNotifier = ref.read(searchControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Search Properties'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () => searchNotifier.refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search by title, location, category...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      searchNotifier.setQueryText(v.toLowerCase());
                    },
                    onSubmitted: (v) async {
                      searchNotifier.setQueryText(v.toLowerCase());
                      await searchNotifier.refresh();
                      if (v.trim().isNotEmpty) {
                        await UserBehaviorService.logSearch(v.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Category'),
                        selected: controller.category != null,
                        onSelected: (sel) {
                          if (!sel) {
                            searchNotifier.setFilters(category: null);
                          } else {
                            searchNotifier.setFilters(category: 'Apartment');
                          }
                        },
                      ),
                      FilterChip(
                        label: const Text('State'),
                        selected: controller.state != null,
                        onSelected: (sel) {
                          if (!sel) {
                            searchNotifier.setFilters(state: null);
                          } else {
                            searchNotifier.setFilters(state: 'Lagos');
                          }
                        },
                      ),
                      FilterChip(
                        label: const Text('LGA'),
                        selected: controller.lga != null,
                        onSelected: (sel) {
                          if (!sel) {
                            searchNotifier.setFilters(lga: null);
                          } else {
                            searchNotifier.setFilters(lga: 'Ikeja');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Results',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }

            final itemIndex = index - 1;
            if (itemIndex < controller.items.length) {
              final p = controller.items[itemIndex];
              return _propertyTile(p, context);
            }

            // pagination footer
            if (controller.hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await searchNotifier.loadNextPage();
                    },
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('Load more'),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
