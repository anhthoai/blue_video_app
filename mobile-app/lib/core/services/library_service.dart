import 'dart:collection';

import '../models/library_item_model.dart';
import '../models/library_section_model.dart';
import 'api_service.dart';

class _CachedValue<T> {
  const _CachedValue(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class LibraryItemsRequest {
  const LibraryItemsRequest({
    required this.section,
    this.parentId,
    this.path,
    this.page = 1,
    this.limit = 40,
    this.search,
    this.includeStreams = false,
  });

  final String section;
  final String? parentId;
  final String? path;
  final int page;
  final int limit;
  final String? search;
  final bool includeStreams;

  String get normalizedSection => section.toLowerCase();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibraryItemsRequest &&
        other.normalizedSection == normalizedSection &&
        other.parentId == parentId &&
        other.path == path &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.includeStreams == includeStreams;
  }

  @override
  int get hashCode => Object.hash(
        normalizedSection,
        parentId,
        path,
        page,
        limit,
        search,
        includeStreams,
      );
}

class LibraryVideoFeedRequest {
  const LibraryVideoFeedRequest({
    this.page = 1,
    this.limit = 60,
    this.sortBy = 'newest',
    this.section,
    this.includeStreams = false,
  });

  final int page;
  final int limit;
  final String sortBy;
  final String? section;
  final bool includeStreams;

  String get normalizedSortBy => sortBy.trim().toLowerCase();
  String? get normalizedSection => section?.trim().toLowerCase();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibraryVideoFeedRequest &&
        other.page == page &&
        other.limit == limit &&
        other.normalizedSortBy == normalizedSortBy &&
        other.normalizedSection == normalizedSection &&
        other.includeStreams == includeStreams;
  }

  @override
  int get hashCode => Object.hash(
        page,
        limit,
        normalizedSortBy,
        normalizedSection,
        includeStreams,
      );
}

class LibraryService {
  LibraryService._();

  static final LibraryService _instance = LibraryService._();
  factory LibraryService() => _instance;

  final ApiService _apiService = ApiService();

  // Cache responses briefly to speed up repeat navigations.
  // This mirrors the short-lived caching added to MovieService for stream URLs.
  static const Duration _cacheTtl = Duration(minutes: 2);
  static _CachedValue<List<LibrarySectionModel>>? _sectionsCache;
  static final Map<LibraryItemsRequest, _CachedValue<List<LibraryItemModel>>>
      _itemsCache = {};
    static final Map<LibraryVideoFeedRequest, _CachedValue<List<LibraryItemModel>>>
      _videoFeedCache = {};
  static final Map<String, _CachedValue<LibraryItemModel?>> _itemByIdCache = {};

  Future<List<LibrarySectionModel>> fetchSections() async {
    final cached = _sectionsCache;
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final response = await _apiService.getLibrarySections();
    final data = response['data'];
    if (data is List) {
      final sections = data
          .map((section) =>
              LibrarySectionModel.fromJson((section as Map).cast<String, dynamic>()))
          .toList();

      _sectionsCache = _CachedValue(
        sections,
        DateTime.now().add(_cacheTtl),
      );

      return sections;
    }
    return [];
  }

  Future<List<LibraryItemModel>> fetchItems(LibraryItemsRequest request) async {
    final cached = _itemsCache[request];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final response = await _apiService.getLibraryItems(
      request.normalizedSection,
      page: request.page,
      limit: request.limit,
      parentId: request.parentId,
      path: request.path,
      search: request.search,
      includeStreams: request.includeStreams,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'];
    if (items is List) {
      final result = items
          .map((item) =>
              LibraryItemModel.fromJson((item as Map).cast<String, dynamic>()))
          .toList();

      _itemsCache[request] = _CachedValue(
        result,
        DateTime.now().add(_cacheTtl),
      );

      return result;
    }
    return [];
  }

  Future<List<LibraryItemModel>> fetchAllSectionItems(
    String section, {
    bool includeStreams = false,
    int limit = 200,
  }) async {
    final queue = Queue<String?>()..add(null);
    final visitedFolders = <String?>{null};
    final seenIds = <String>{};
    final collected = <LibraryItemModel>[];

    while (queue.isNotEmpty) {
      final parentId = queue.removeFirst();
      var page = 1;

      while (true) {
        final items = await fetchItems(
          LibraryItemsRequest(
            section: section,
            parentId: parentId,
            includeStreams: includeStreams,
            page: page,
            limit: limit,
          ),
        );

        if (items.isEmpty) {
          break;
        }

        for (final item in items) {
          if (!seenIds.add(item.id)) {
            continue;
          }

          collected.add(item);

          if (item.isFolder && item.hasChildren && visitedFolders.add(item.id)) {
            queue.add(item.id);
          }
        }

        if (items.length < limit) {
          break;
        }

        page += 1;
      }
    }

    return collected;
  }

  Future<List<LibraryItemModel>> fetchVideoFeed(
    LibraryVideoFeedRequest request,
  ) async {
    final cached = _videoFeedCache[request];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final response = await _apiService.getLibraryVideoFeed(
      page: request.page,
      limit: request.limit,
      sortBy: request.normalizedSortBy,
      section: request.normalizedSection,
      includeStreams: request.includeStreams,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'];
    if (items is List) {
      final result = items
          .map((item) =>
              LibraryItemModel.fromJson((item as Map).cast<String, dynamic>()))
          .toList();

      _videoFeedCache[request] = _CachedValue(
        result,
        DateTime.now().add(_cacheTtl),
      );

      return result;
    }
    return [];
  }

  Future<LibraryItemModel?> fetchItemById(
    String id, {
    bool includeStreams = true,
  }) async {
    final key = '$id:$includeStreams';
    final cached = _itemByIdCache[key];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final response =
        await _apiService.getLibraryItem(id, includeStreams: includeStreams);
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      return null;
    }
    final item = LibraryItemModel.fromJson(data);
    _itemByIdCache[key] = _CachedValue(
      item,
      DateTime.now().add(_cacheTtl),
    );
    return item;
  }
}
