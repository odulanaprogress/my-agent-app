import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/models/property_model.dart';
import '../../data/search_repository.dart';

class SearchState {
  final String queryText;
  final String? state;
  final String? lga;
  final String? category;
  final num? minPrice;
  final num? maxPrice;

  final int pageSize;
  final String? lastDocId;
  final bool hasMore;

  final List<PropertyModel> items;

  const SearchState({
    required this.queryText,
    required this.state,
    required this.lga,
    required this.category,
    required this.minPrice,
    required this.maxPrice,
    required this.pageSize,
    required this.lastDocId,
    required this.hasMore,
    required this.items,
  });

  factory SearchState.initial() {
    return const SearchState(
      queryText: '',
      state: null,
      lga: null,
      category: null,
      minPrice: null,
      maxPrice: null,
      pageSize: 10,
      lastDocId: null,
      hasMore: true,
      items: [],
    );
  }

  SearchState copyWith({
    String? queryText,
    String? state,
    String? lga,
    String? category,
    num? minPrice,
    num? maxPrice,
    int? pageSize,
    String? lastDocId,
    bool? hasMore,
    List<PropertyModel>? items,
  }) {
    return SearchState(
      queryText: queryText ?? this.queryText,
      state: state,
      lga: lga,
      category: category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      pageSize: pageSize ?? this.pageSize,
      lastDocId: lastDocId ?? this.lastDocId,
      hasMore: hasMore ?? this.hasMore,
      items: items ?? this.items,
    );
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository();
});

final searchControllerProvider =
    StateNotifierProvider<SearchController, SearchState>((ref) {
      final repo = ref.read(searchRepositoryProvider);
      return SearchController(repo: repo);
    });

class SearchController extends StateNotifier<SearchState> {
  final SearchRepository repo;

  SearchController({required this.repo}) : super(SearchState.initial()) {
    // initial load
    // ignore: unawaited_futures
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;

    final results = await repo.searchApprovedPropertiesOnce(
      limit: state.pageSize,
      startAfterDocId: null,
      searchText: state.queryText,
      state: state.state,
      lga: state.lga,
      category: state.category,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
    );

    // MVP heuristic: if results < pageSize => no more.
    state = state.copyWith(
      items: results,
      lastDocId: results.isNotEmpty ? results.last.id : null,
      hasMore: results.length >= state.pageSize,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(lastDocId: null, hasMore: true, items: []);
    await _loadFirstPage();
  }

  void setQueryText(String v) {
    state = state.copyWith(queryText: v);
  }

  void setFilters({
    String? state,
    String? lga,
    String? category,
    num? minPrice,
    num? maxPrice,
  }) {
    this.state = this.state.copyWith(
      state: state,
      lga: lga,
      category: category,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }

  Future<void> loadNextPage() async {
    if (!state.hasMore) return;

    final results = await repo.searchApprovedPropertiesOnce(
      limit: state.pageSize,
      startAfterDocId: state.lastDocId,
      searchText: state.queryText,
      state: state.state,
      lga: state.lga,
      category: state.category,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
    );

    final nextItems = [...state.items, ...results];

    state = state.copyWith(
      items: nextItems,
      lastDocId: results.isNotEmpty ? results.last.id : state.lastDocId,
      hasMore: results.length >= state.pageSize,
    );
  }
}
