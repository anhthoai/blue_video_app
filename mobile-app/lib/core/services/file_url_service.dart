import 'api_service.dart';

String? appendCacheBuster(String? url, DateTime? version) {
  if (url == null || url.isEmpty) return url;
  if (version == null) return url;
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    // Keep storage object keys untouched; query params break presigned lookup.
    return url;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  final updatedQuery = Map<String, String>.from(uri.queryParameters)
    ..['v'] = version.millisecondsSinceEpoch.toString();
  return uri.replace(queryParameters: updatedQuery).toString();
}

/// Service to handle file URL resolution (CDN or presigned URLs)
class FileUrlService {
  static final FileUrlService _instance = FileUrlService._internal();
  factory FileUrlService() => _instance;
  FileUrlService._internal();

  final ApiService _apiService = ApiService();

  // Cache presigned URLs to avoid redundant API calls
  final Map<String, _CachedUrl> _urlCache = {};

  String _normalizeObjectKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('s3://')) {
      final withoutScheme = trimmed.substring(5);
      final slashIndex = withoutScheme.indexOf('/');
      if (slashIndex >= 0 && slashIndex < withoutScheme.length - 1) {
        return withoutScheme.substring(slashIndex + 1);
      }
      return withoutScheme;
    }
    return trimmed;
  }

  /// Get accessible file URL (CDN or presigned URL)
  /// Returns null if URL is null/empty or if fetching fails
  Future<String?> getAccessibleUrl(String? url) async {
    if (url == null || url.isEmpty) return null;

    final normalized = _normalizeObjectKey(url);

    // If URL already starts with http/https, it's a CDN URL
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    // Check cache first
    final cached = _urlCache[normalized];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Fetch presigned URL from backend
    try {
      final presignedUrl = await _apiService.getPresignedUrl(normalized);
      if (presignedUrl != null) {
        // Cache for 50 minutes (presigned URLs expire in 1 hour)
        _urlCache[normalized] = _CachedUrl(
          url: presignedUrl,
          expiresAt: DateTime.now().add(const Duration(minutes: 50)),
        );
        return presignedUrl;
      }
    } catch (e) {
      print('Error getting presigned URL for $normalized: $e');
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
