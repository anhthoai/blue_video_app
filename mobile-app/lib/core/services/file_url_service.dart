import 'api_service.dart';

/// Service to handle file URL resolution (CDN or presigned URLs)
class FileUrlService {
  static final FileUrlService _instance = FileUrlService._internal();
  factory FileUrlService() => _instance;
  FileUrlService._internal();

  final ApiService _apiService = ApiService();

  // Cache presigned URLs to avoid redundant API calls
  final Map<String, _CachedUrl> _urlCache = {};

  /// Get accessible file URL (CDN or presigned URL)
  /// Returns null if URL is null/empty or if fetching fails
  Future<String?> getAccessibleUrl(String? url) async {
    if (url == null || url.isEmpty) return null;

    // If URL already starts with http/https, it's a CDN URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Check cache first
    final cached = _urlCache[url];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Fetch presigned URL from backend
    try {
      final presignedUrl = await _apiService.getPresignedUrl(url);
      if (presignedUrl != null) {
        // Cache for 50 minutes (presigned URLs expire in 1 hour)
        _urlCache[url] = _CachedUrl(
          url: presignedUrl,
          expiresAt: DateTime.now().add(const Duration(minutes: 50)),
        );
        return presignedUrl;
      }
    } catch (e) {
      print('Error getting presigned URL for $url: $e');
    }

    return null;
  }

  /// Clear cached URLs
  void clearCache() {
    _urlCache.clear();
  }

  /// Clear expired URLs from cache
  void cleanupCache() {
    _urlCache.removeWhere((key, value) => value.isExpired);
  }
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  _CachedUrl({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
