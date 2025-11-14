import '../models/library_item_model.dart';
import '../models/library_section_model.dart';
import 'api_service.dart';

class LibraryItemsRequest {
  const LibraryItemsRequest({
    required this.section,
    this.parentId,
    this.path,
    this.page = 1,
    this.limit = 40,
    this.includeStreams = false,
  });

  final String section;
  final String? parentId;
  final String? path;
  final int page;
  final int limit;
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
        other.includeStreams == includeStreams;
  }

  @override
  int get hashCode => Object.hash(
        normalizedSection,
        parentId,
        path,
        page,
        limit,
        includeStreams,
      );
}

class LibraryService {
  LibraryService._();

  static final LibraryService _instance = LibraryService._();
  factory LibraryService() => _instance;

  final ApiService _apiService = ApiService();

  Future<List<LibrarySectionModel>> fetchSections() async {
    final response = await _apiService.getLibrarySections();
    final data = response['data'];
    if (data is List) {
      return data
          .map((section) =>
              LibrarySectionModel.fromJson((section as Map).cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<List<LibraryItemModel>> fetchItems(LibraryItemsRequest request) async {
    final response = await _apiService.getLibraryItems(
      request.normalizedSection,
      page: request.page,
      limit: request.limit,
      parentId: request.parentId,
      path: request.path,
      includeStreams: request.includeStreams,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'];
    if (items is List) {
      return items
          .map((item) =>
              LibraryItemModel.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<LibraryItemModel?> fetchItemById(
    String id, {
    bool includeStreams = true,
  }) async {
    final response =
        await _apiService.getLibraryItem(id, includeStreams: includeStreams);
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      return null;
    }
    return LibraryItemModel.fromJson(data);
  }
}
