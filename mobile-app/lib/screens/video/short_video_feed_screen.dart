import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/library_item_model.dart';
import '../../core/models/library_navigation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/file_url_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/video_service.dart';
import '../../models/video_model.dart';
import '../../utils/media_kit_low_latency.dart';
import '../../widgets/common/presigned_image.dart';

enum ShortVideoFeedScope { forYou, following }

const int _shortFeedPaginationThreshold = 3;
const int _shortFeedMaxSequentialPageScan = 4;

class ShortVideoFeedQuery {
  final String? categoryId;
  final String sortBy;
  final ShortVideoFeedScope scope;
  final int limit;
  final bool includeLibraryVideos;

  const ShortVideoFeedQuery({
    this.categoryId,
    this.sortBy = 'newest',
    this.scope = ShortVideoFeedScope.forYou,
    this.limit = 60,
    this.includeLibraryVideos = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ShortVideoFeedQuery &&
        other.categoryId == categoryId &&
        other.sortBy == sortBy &&
        other.scope == scope &&
        other.limit == limit &&
        other.includeLibraryVideos == includeLibraryVideos;
  }

  @override
  int get hashCode {
    return Object.hash(
      categoryId,
      sortBy,
      scope,
      limit,
      includeLibraryVideos,
    );
  }
}

class _ShortVideoFeedPageResult {
  const _ShortVideoFeedPageResult({
    required this.videos,
    required this.hasMore,
  });

  final List<VideoModel> videos;
  final bool hasMore;
}

Future<_ShortVideoFeedPageResult> _loadShortVideoFeedPage({
  required WidgetRef ref,
  required ShortVideoFeedQuery query,
  required int page,
}) async {
  final videoService = ref.read(videoServiceProvider);
  final sourceLimit = query.scope == ShortVideoFeedScope.following
      ? query.limit * 3
      : query.limit;
  final baseVideos = await videoService.getVideos(
    page: page,
    limit: sourceLimit,
    category: query.categoryId,
    sortBy: query.sortBy,
  );

  final videos = query.scope == ShortVideoFeedScope.forYou
      ? baseVideos
      : await _filterShortVideosByFollowing(baseVideos);
  final baseHasMore = baseVideos.length >= sourceLimit;

  if (!query.includeLibraryVideos ||
      query.scope != ShortVideoFeedScope.forYou) {
    return _ShortVideoFeedPageResult(
      videos: videos.take(query.limit).toList(growable: false),
      hasMore: baseHasMore,
    );
  }

  final libraryLimit = query.limit <= 18 ? query.limit : query.limit ~/ 3;
  final libraryVideos = await _loadLibraryShortVideos(
    page: page,
    limit: libraryLimit,
    sortBy: query.sortBy,
  );

  return _ShortVideoFeedPageResult(
    videos: _interleaveShortFeedVideos(
      videos,
      libraryVideos,
      totalLimit: query.limit,
    ),
    hasMore: baseHasMore || libraryVideos.length >= libraryLimit,
  );
}

Future<List<VideoModel>> _filterShortVideosByFollowing(
  List<VideoModel> videos,
) async {
    final apiService = ApiService();
    final userIds =
        videos.map((video) => video.userId).toSet().toList(growable: false);
    final followEntries = await Future.wait(
      userIds.map((userId) async {
        try {
          final response = await apiService.getUserProfile(userId);
          final data = response['data'];
          final isFollowing = response['success'] == true &&
              data is Map<String, dynamic> &&
              data['isFollowing'] == true;
          return MapEntry(userId, isFollowing);
        } catch (_) {
          return MapEntry(userId, false);
        }
      }),
    );

    final followedUserIds = <String>{
      for (final entry in followEntries)
        if (entry.value) entry.key,
    };

    return videos
        .where((video) => followedUserIds.contains(video.userId))
        .toList(growable: false);
}

Future<List<VideoModel>> _loadLibraryShortVideos({
  required int page,
  required int limit,
  required String sortBy,
}) async {
  if (limit <= 0) {
    return const <VideoModel>[];
  }

  final videos = await LibraryService().fetchVideoFeed(
    LibraryVideoFeedRequest(
      page: page,
      limit: limit,
      sortBy: sortBy,
    ),
  );

  final sortedVideos = sortBy == 'random'
      ? _sortShortFeedLibraryVideos(videos, sortBy)
      : videos;
  return sortedVideos
      .take(limit)
      .map(_libraryItemToShortVideo)
      .toList(growable: false);
}

List<VideoModel> _interleaveShortFeedVideos(
  List<VideoModel> primaryVideos,
  List<VideoModel> libraryVideos, {
  required int totalLimit,
}) {
  if (libraryVideos.isEmpty) {
    return primaryVideos.take(totalLimit).toList(growable: false);
  }

  final mixed = <VideoModel>[];
  var primaryIndex = 0;
  var libraryIndex = 0;

  while (mixed.length < totalLimit &&
      (primaryIndex < primaryVideos.length || libraryIndex < libraryVideos.length)) {
    for (var count = 0;
        count < 3 &&
            primaryIndex < primaryVideos.length &&
            mixed.length < totalLimit;
        count++) {
      mixed.add(primaryVideos[primaryIndex]);
      primaryIndex += 1;
    }

    if (libraryIndex < libraryVideos.length && mixed.length < totalLimit) {
      mixed.add(libraryVideos[libraryIndex]);
      libraryIndex += 1;
    }

    if (primaryIndex >= primaryVideos.length) {
      while (libraryIndex < libraryVideos.length && mixed.length < totalLimit) {
        mixed.add(libraryVideos[libraryIndex]);
        libraryIndex += 1;
      }
    }

    if (libraryIndex >= libraryVideos.length) {
      while (primaryIndex < primaryVideos.length && mixed.length < totalLimit) {
        mixed.add(primaryVideos[primaryIndex]);
        primaryIndex += 1;
      }
    }
  }

  return mixed;
}

List<LibraryItemModel> _sortShortFeedLibraryVideos(
  List<LibraryItemModel> videos,
  String sortBy,
) {
  final sortedVideos = List<LibraryItemModel>.from(videos);

  switch (sortBy) {
    case 'newest':
      sortedVideos.sort(
        (a, b) => _shortFeedLibraryDate(b).compareTo(_shortFeedLibraryDate(a)),
      );
      break;
    case 'trending':
      sortedVideos.sort((a, b) {
        final bScore = _shortFeedLibraryMetricInt(
                  b,
                  const ['viewCount', 'views', 'watchCount'],
                ) +
            _shortFeedLibraryMetricInt(
              b,
              const ['likeCount', 'likes'],
            ) +
            ((b.duration ?? 0) ~/ 60);
        final aScore = _shortFeedLibraryMetricInt(
                  a,
                  const ['viewCount', 'views', 'watchCount'],
                ) +
            _shortFeedLibraryMetricInt(
              a,
              const ['likeCount', 'likes'],
            ) +
            ((a.duration ?? 0) ~/ 60);
        return bScore.compareTo(aScore);
      });
      break;
    case 'topRated':
      sortedVideos.sort((a, b) {
        final ratingCompare = _shortFeedLibraryMetricDouble(
          b,
          const ['rating', 'score'],
        ).compareTo(
          _shortFeedLibraryMetricDouble(
            a,
            const ['rating', 'score'],
          ),
        );
        if (ratingCompare != 0) {
          return ratingCompare;
        }
        return (b.duration ?? 0).compareTo(a.duration ?? 0);
      });
      break;
    case 'mostViewed':
      sortedVideos.sort(
        (a, b) => _shortFeedLibraryMetricInt(
          b,
          const ['viewCount', 'views', 'watchCount'],
        ).compareTo(
          _shortFeedLibraryMetricInt(
            a,
            const ['viewCount', 'views', 'watchCount'],
          ),
        ),
      );
      break;
    case 'random':
      sortedVideos.shuffle();
      break;
  }

  return sortedVideos;
}

VideoModel _libraryItemToShortVideo(LibraryItemModel item) {
  final creatorName =
      _shortFeedLibraryString(item, const ['creatorName', 'author', 'uploader']) ??
          _shortFeedSectionLabel(item.section);
  final creatorAvatarUrl = _shortFeedLibraryString(
    item,
    const ['creatorAvatarUrl', 'avatarUrl', 'authorAvatarUrl'],
  );
  final category =
      _shortFeedLibraryString(item, const ['category', 'genre']) ??
          _shortFeedSectionLabel(item.section);
  final tags = _shortFeedLibraryTags(item);
  final metadata = Map<String, dynamic>.from(item.metadata)
    ..['shortSource'] = 'library'
    ..['libraryItemId'] = item.id
    ..['librarySection'] = item.section
    ..['libraryCreatorName'] = creatorName
    ..['libraryCategory'] = category;

  if (creatorAvatarUrl != null && creatorAvatarUrl.isNotEmpty) {
    metadata['libraryCreatorAvatarUrl'] = creatorAvatarUrl;
  }
  if (tags.isNotEmpty) {
    metadata['libraryTags'] = tags;
  }

  return VideoModel(
    id: item.id,
    userId: '_library_${item.section}',
    title: item.displayTitle,
    description: item.description,
    videoUrl: '',
    remotePlayUrl: null,
    thumbnailUrl: item.imageUrl,
    duration: item.duration ?? 0,
    viewCount: _shortFeedLibraryMetricInt(
      item,
      const ['viewCount', 'views', 'watchCount'],
    ),
    likeCount: _shortFeedLibraryMetricInt(
      item,
      const ['likeCount', 'likes'],
    ),
    commentCount: _shortFeedLibraryMetricInt(
      item,
      const ['commentCount', 'comments'],
    ),
    shareCount: _shortFeedLibraryMetricInt(
      item,
      const ['shareCount', 'shares'],
    ),
    isLiked: false,
    isPublic: true,
    status: 'PUBLIC',
    isFeatured: false,
    createdAt: item.createdAt ?? DateTime.now(),
    updatedAt: item.updatedAt,
    tags: tags.isEmpty ? null : tags,
    category: category,
    cost: 0,
    isPaid: true,
    metadata: metadata,
    username: creatorName,
    userAvatarUrl: creatorAvatarUrl,
  );
}

String? _shortFeedPlayableLibraryUrl(LibraryItemModel? item) {
  if (item == null) {
    return null;
  }

  final streamUrl = item.streamUrl;
  if (streamUrl != null && streamUrl.isNotEmpty) {
    return streamUrl;
  }

  final fileUrl = item.fileUrl;
  if (fileUrl != null && fileUrl.startsWith('http')) {
    return fileUrl;
  }

  return null;
}

DateTime _shortFeedLibraryDate(LibraryItemModel item) {
  return item.updatedAt ??
      item.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

int _shortFeedLibraryMetricInt(LibraryItemModel item, List<String> keys) {
  for (final key in keys) {
    final value = item.metadata[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return 0;
}

double _shortFeedLibraryMetricDouble(LibraryItemModel item, List<String> keys) {
  for (final key in keys) {
    final value = item.metadata[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return 0;
}

String? _shortFeedLibraryString(LibraryItemModel item, List<String> keys) {
  for (final key in keys) {
    final value = item.metadata[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

List<String> _shortFeedLibraryTags(LibraryItemModel item) {
  final rawTags = item.metadata['tags'] ?? item.metadata['keywords'];
  if (rawTags is List) {
    return rawTags
        .map((tag) => tag.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }
  if (rawTags is String) {
    return rawTags
        .split(RegExp(r'[,|#]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }
  return const <String>[];
}

bool _isLibraryShortSource(VideoModel video) {
  return video.metadata?['shortSource'] == 'library';
}

String? _libraryShortSourceId(VideoModel video) {
  final itemId = video.metadata?['libraryItemId']?.toString().trim();
  if (itemId != null && itemId.isNotEmpty) {
    return itemId;
  }
  return null;
}

String? _libraryShortSection(VideoModel video) {
  final section = video.metadata?['librarySection']?.toString().trim();
  if (section != null && section.isNotEmpty) {
    return section;
  }
  return null;
}

String? _shortFeedLibraryPlaybackUrl(VideoModel video) {
  final streamUrl = video.metadata?['libraryStreamUrl']?.toString().trim();
  if (streamUrl != null && streamUrl.isNotEmpty) {
    return streamUrl;
  }

  return null;
}

String _shortFeedSectionLabel(String section) {
  if (section.trim().isEmpty) {
    return 'Library';
  }

  return section
      .split(RegExp(r'[-_]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase(),
      )
      .join(' ');
}

String _formatShortVideoDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class ShortVideoFeedScreen extends StatelessWidget {
  final String? categoryId;
  final String sortBy;
  final ShortVideoFeedScope scope;

  const ShortVideoFeedScreen({
    super.key,
    this.categoryId,
    this.sortBy = 'newest',
    this.scope = ShortVideoFeedScope.forYou,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ShortVideoFeedView(
        query: ShortVideoFeedQuery(
          categoryId: categoryId,
          sortBy: sortBy,
          scope: scope,
        ),
        immersiveMode: true,
        showHeader: true,
        showBackButton: true,
      ),
    );
  }
}

class ShortVideoFeedView extends ConsumerStatefulWidget {
  final ShortVideoFeedQuery query;
  final bool immersiveMode;
  final bool showHeader;
  final bool showBackButton;

  const ShortVideoFeedView({
    super.key,
    required this.query,
    this.immersiveMode = false,
    this.showHeader = false,
    this.showBackButton = false,
  });

  @override
  ConsumerState<ShortVideoFeedView> createState() => _ShortVideoFeedViewState();
}

class _ShortVideoFeedViewState extends ConsumerState<ShortVideoFeedView> {
  late final PageController _pageController;
  int _currentIndex = 0;
  int _nextPage = 1;
  int _feedGeneration = 0;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreVideos = true;
  String? _loadErrorMessage;
  List<VideoModel> _videos = const <VideoModel>[];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    unawaited(_refreshFeed());
    if (widget.immersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (widget.immersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShortVideoFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.query != widget.query) {
      unawaited(_refreshFeed());
    }
  }

  Future<void> _refreshFeed() async {
    _feedGeneration += 1;
    final generation = _feedGeneration;

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    if (mounted) {
      setState(() {
        _currentIndex = 0;
        _nextPage = 1;
        _isInitialLoading = true;
        _isLoadingMore = false;
        _hasMoreVideos = true;
        _loadErrorMessage = null;
        _videos = const <VideoModel>[];
      });
    }

    await _loadNextPage(generation: generation, reset: true);
  }

  Future<void> _loadNextPage({
    int? generation,
    bool reset = false,
  }) async {
    final activeGeneration = generation ?? _feedGeneration;

    if (!reset) {
      if (_isInitialLoading || _isLoadingMore || !_hasMoreVideos) {
        return;
      }

      setState(() {
        _isLoadingMore = true;
      });
    }

    var requestedPage = reset ? 1 : _nextPage;
    var nextPage = requestedPage;
    var hasMore = _hasMoreVideos;
    var appendedVideos = const <VideoModel>[];

    try {
      for (var scanCount = 0;
          scanCount < _shortFeedMaxSequentialPageScan;
          scanCount++) {
        final pageResult = await _loadShortVideoFeedPage(
          ref: ref,
          query: widget.query,
          page: requestedPage,
        );

        if (!mounted || activeGeneration != _feedGeneration) {
          return;
        }

        nextPage = requestedPage + 1;
        appendedVideos = pageResult.videos;
        hasMore = pageResult.hasMore;

        if (appendedVideos.isNotEmpty || !hasMore) {
          break;
        }

        requestedPage += 1;
      }

      if (!mounted || activeGeneration != _feedGeneration) {
        return;
      }

      setState(() {
        _videos = reset
            ? appendedVideos
            : _mergeShortFeedVideos(_videos, appendedVideos);
        _nextPage = nextPage;
        _hasMoreVideos = hasMore;
        _loadErrorMessage = null;
        _isInitialLoading = false;
        _isLoadingMore = false;
        if (_videos.isNotEmpty && _currentIndex >= _videos.length) {
          _currentIndex = _videos.length - 1;
        }
      });
    } catch (error) {
      if (!mounted || activeGeneration != _feedGeneration) {
        return;
      }

      setState(() {
        if (reset) {
          _videos = const <VideoModel>[];
        }
        _loadErrorMessage = error.toString();
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;

    if (_isInitialLoading && videos.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_loadErrorMessage != null && videos.isEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: _buildErrorState(_loadErrorMessage!),
      );
    }

    if (videos.isEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: _buildEmptyState(),
      );
    }

    final safeIndex = _currentIndex.clamp(0, videos.length - 1);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            dragStartBehavior: DragStartBehavior.down,
            itemCount: videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (index >= videos.length - _shortFeedPaginationThreshold) {
                unawaited(_loadNextPage());
              }
            },
            itemBuilder: (context, index) {
              final video = videos[index];
              return _ShortVideoPage(
                key: ValueKey('${video.id}-$index'),
                video: video,
                isActive: index == _currentIndex,
                shouldPreload: index == _currentIndex + 1,
                immersiveMode: widget.immersiveMode,
              );
            },
          ),
          if (_isLoadingMore)
            Positioned(
              top: widget.showHeader ? 72 : 24,
              right: 16,
              child: SafeArea(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.54),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading more',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (widget.showHeader)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    if (widget.showBackButton)
                      IconButton(
                        onPressed: () => context.pop(),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.black.withValues(alpha: 0.28),
                        ),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                    if (widget.showBackButton) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.query.scope == ShortVideoFeedScope.forYou
                                ? 'For You'
                                : 'Following',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${safeIndex + 1}/${videos.length}${_hasMoreVideos ? '+' : ''}  •  ${_labelForSort(widget.query.sortBy)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _TopPillLabel(
                      icon: Icons.swipe_vertical_rounded,
                      label: 'Swipe up or down',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFollowing = widget.query.scope == ShortVideoFeedScope.following;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_collection_outlined,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                isFollowing
                    ? 'No videos from creators you follow yet.'
                    : 'No videos available for short mode yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isFollowing
                    ? 'Follow more creators or switch to For You.'
                    : 'Try again later or switch to Explore.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              if (widget.showBackButton) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back to Home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Short mode could not load videos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => unawaited(_refreshFeed()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<VideoModel> _mergeShortFeedVideos(
  List<VideoModel> existingVideos,
  List<VideoModel> incomingVideos,
) {
  final mergedVideos = List<VideoModel>.from(existingVideos);
  final seenKeys = existingVideos
      .map(_shortFeedVideoUniqueKey)
      .toSet();

  for (final video in incomingVideos) {
    if (seenKeys.add(_shortFeedVideoUniqueKey(video))) {
      mergedVideos.add(video);
    }
  }

  return mergedVideos;
}

String _shortFeedVideoUniqueKey(VideoModel video) {
  if (_isLibraryShortSource(video)) {
    return 'library:${_libraryShortSourceId(video) ?? video.id}';
  }
  return 'video:${video.id}';
}

class _ShortVideoPage extends ConsumerStatefulWidget {
  final VideoModel video;
  final bool isActive;
  final bool shouldPreload;
  final bool immersiveMode;

  const _ShortVideoPage({
    super.key,
    required this.video,
    required this.isActive,
    required this.shouldPreload,
    required this.immersiveMode,
  });

  @override
  ConsumerState<_ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends ConsumerState<_ShortVideoPage> {
  final ApiService _apiService = ApiService();
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  Timer? _likeBurstTimer;
  bool _isInitializing = false;
  bool _isReady = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _hasTrackedView = false;
  bool _showLikeBurst = false;
  bool _isScrubbing = false;
  bool _isFollowingCreator = false;
  bool _isLoadingFollow = false;
  Offset? _likeBurstOffset;
  Offset? _lastDoubleTapPosition;
  double? _scrubPositionMilliseconds;
  String? _followStatusLoadedForUserId;
  String? _errorMessage;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late int _likeCount;
  late int _shareCount;
  late bool _isLiked;

  bool get _isLibraryVideo => _isLibraryShortSource(widget.video);
  String get _durationLabel {
    if (_isLibraryVideo && _totalDuration.inMilliseconds > 0) {
      return _formatShortVideoDuration(_totalDuration);
    }
    return widget.video.formattedDuration;
  }

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.likeCount;
    _shareCount = widget.video.shareCount;
    _isLiked = widget.video.isLiked;

    if ((widget.isActive || widget.shouldPreload) && !_isLockedVideo) {
      unawaited(_ensureVideoReady(autoPlay: widget.isActive));
    }

    unawaited(_loadCreatorFollowStatus());
  }

  @override
  void didUpdateWidget(covariant _ShortVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.video.id != widget.video.id) {
      _resetState();
      _likeCount = widget.video.likeCount;
      _shareCount = widget.video.shareCount;
      _isLiked = widget.video.isLiked;
      if ((widget.isActive || widget.shouldPreload) && !_isLockedVideo) {
        unawaited(_ensureVideoReady(autoPlay: widget.isActive));
      }
      unawaited(_loadCreatorFollowStatus());
      return;
    }

    if (!oldWidget.shouldPreload && widget.shouldPreload && !_isLockedVideo) {
      unawaited(_ensureVideoReady(autoPlay: false));
    }

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive && !_isLockedVideo) {
        if (_videoController == null) {
          unawaited(_ensureVideoReady(autoPlay: true));
        } else {
          unawaited(_player?.play());
          if (!_hasTrackedView) {
            unawaited(_incrementViewCount());
          }
        }
      } else {
        unawaited(_player?.pause());
      }
    }
  }

  @override
  void dispose() {
    _likeBurstTimer?.cancel();
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }

  bool get _isLockedVideo {
    if (_isLibraryVideo) {
      return false;
    }

    final currentUser = ref.read(authServiceProvider).currentUser;
    final isUserVip = currentUser?.isVip ?? false;
    final needsVip =
        widget.video.requiresVIP && !isUserVip && !widget.video.isPaid;
    final needsPayment = widget.video.hasCost && !widget.video.isPaid;
    return needsVip || needsPayment;
  }

  bool get _canFollowCreator {
    if (_isLibraryVideo) {
      return false;
    }

    final currentUserId = ref.read(authServiceProvider).currentUser?.id;
    return currentUserId != null && currentUserId != widget.video.userId;
  }

  Future<void> _loadCreatorFollowStatus() async {
    if (_isLibraryVideo) {
      return;
    }

    final creatorId = widget.video.userId;
    if (!_canFollowCreator || _followStatusLoadedForUserId == creatorId) {
      return;
    }

    try {
      final response = await _apiService.getUserProfile(creatorId);
      if (!mounted) {
        return;
      }

      final data = response['data'];
      if (response['success'] == true && data is Map<String, dynamic>) {
        setState(() {
          _isFollowingCreator = data['isFollowing'] == true;
          _followStatusLoadedForUserId = creatorId;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleCreatorFollow() async {
    if (!_canFollowCreator || _isLoadingFollow) {
      return;
    }

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      final response = _isFollowingCreator
          ? await _apiService.unfollowUser(widget.video.userId)
          : await _apiService.followUser(widget.video.userId);

      if (!mounted) {
        return;
      }

      if (response['success'] == true) {
        setState(() {
          _isFollowingCreator = !_isFollowingCreator;
          _followStatusLoadedForUserId = widget.video.userId;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  Future<void> _ensureVideoReady({required bool autoPlay}) async {
    if (_isInitializing || _videoController != null) {
      return;
    }

    if (widget.video.embedCode != null && widget.video.embedCode!.isNotEmpty) {
      setState(() {
        _errorMessage = 'Open this video in the full player.';
      });
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final playbackUrl = await _resolvePlaybackUrl(widget.video);
      if (!mounted) {
        return;
      }
      if (playbackUrl == null || playbackUrl.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Playback URL is not available for this video.';
        });
        return;
      }

      final player = Player();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          androidAttachSurfaceAfterVideoParameters: false,
        ),
      );
      _player = player;
      _videoController = controller;

      await _configurePlayback(player, playbackUrl);

      _playingSubscription = player.stream.playing.listen((playing) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPlaying = playing;
        });
      });

      _positionSubscription = player.stream.position.listen((position) {
        if (!mounted || _isScrubbing) {
          return;
        }
        setState(() {
          _currentPosition = position;
        });
      });

      _durationSubscription = player.stream.duration.listen((duration) {
        if (!mounted) {
          return;
        }
        setState(() {
          _totalDuration = duration;
        });
      });

      await player.open(Media(playbackUrl), play: autoPlay && widget.isActive);
      await player.setVolume(_isMuted ? 0 : 100);

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _isReady = true;
      });

      if (widget.isActive) {
        await _incrementViewCount();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Unable to start this video right now.';
      });
    }
  }

  Future<void> _configurePlayback(Player player, String playbackUrl) async {
    final preferLowLatency = shouldUseLowLatencyProfile(playbackUrl);

    try {
      final platform = player.platform;

      await applyMediaKitLowLatency(player, sourceUrl: playbackUrl);
      await (platform as dynamic).setProperty('ao', 'audiotrack,opensles');
      await (platform as dynamic).setProperty(
        'audio-normalize-downmix',
        'yes',
      );
      await (platform as dynamic).setProperty('audio-channels', 'stereo');
      await (platform as dynamic).setProperty(
        'cache',
        preferLowLatency ? 'no' : 'yes',
      );
      await (platform as dynamic).setProperty('cache-on-disk', 'no');
      await (platform as dynamic).setProperty('network-timeout', '30');

      final existing = await (platform as dynamic).getProperty('demuxer-lavf-o');
      final extra = [
        'reconnect=1',
        'reconnect_streamed=1',
        'reconnect_on_network_error=1',
        'reconnect_delay_max=5',
      ].join(',');
      final combined = (existing is String && existing.isNotEmpty)
          ? '$existing,$extra'
          : extra;
      await (platform as dynamic).setProperty('demuxer-lavf-o', combined);
    } catch (_) {}
  }

  Future<String?> _resolvePlaybackUrl(VideoModel video) async {
    if (_isLibraryShortSource(video)) {
      final directUrl = _shortFeedLibraryPlaybackUrl(video);
      if (directUrl != null && directUrl.isNotEmpty) {
        return directUrl;
      }

      final libraryItemId = _libraryShortSourceId(video);
      if (libraryItemId != null) {
        final detailedItem = await LibraryService().fetchItemById(
          libraryItemId,
          includeStreams: true,
        );
        return _shortFeedPlayableLibraryUrl(detailedItem);
      }

      return null;
    }

    if (video.remotePlayUrl != null && video.remotePlayUrl!.isNotEmpty) {
      return video.remotePlayUrl;
    }

    if (video.fileName != null && video.fileDirectory != null) {
      final objectKey = 'videos/${video.fileDirectory}/${video.fileName}';
      return FileUrlService().getAccessibleUrl(objectKey);
    }

    if (video.videoUrl.isNotEmpty) {
      return video.videoUrl;
    }

    return null;
  }

  Future<void> _incrementViewCount() async {
    if (_hasTrackedView) {
      return;
    }

    if (_isLibraryVideo) {
      _hasTrackedView = true;
      return;
    }

    try {
      final response = await _apiService.incrementVideoView(widget.video.id);
      if (response['success'] == true) {
        _hasTrackedView = true;
      }
    } catch (_) {
      _hasTrackedView = true;
    }
  }

  Future<void> _toggleLike({bool preferLikeOnly = false}) async {
    if (_isLibraryVideo) {
      return;
    }

    if (preferLikeOnly && _isLiked) {
      return;
    }

    try {
      final response = await _apiService.toggleVideoLike(widget.video.id);
      if (!mounted) {
        return;
      }

      final data = response['data'];
      if (response['success'] == true && data is Map<String, dynamic>) {
        setState(() {
          _likeCount = data['likes'] as int? ?? _likeCount;
          _isLiked = data['isLiked'] as bool? ?? !_isLiked;
        });
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (preferLikeOnly) {
        if (!_isLiked) {
          _isLiked = true;
          _likeCount += 1;
        }
        return;
      }

      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      if (_likeCount < 0) {
        _likeCount = 0;
      }
    });
  }

  Future<void> _handleDoubleTap() async {
    if (_isLibraryVideo) {
      return;
    }

    _triggerLikeBurst(_lastDoubleTapPosition);
    await _toggleLike(preferLikeOnly: true);
  }

  void _triggerLikeBurst(Offset? position) {
    _likeBurstTimer?.cancel();
    setState(() {
      _showLikeBurst = true;
      _likeBurstOffset = position;
    });

    _likeBurstTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showLikeBurst = false;
      });
    });
  }

  Future<void> _shareVideo() async {
    final libraryShareUrl = _isLibraryVideo
        ? (_shortFeedLibraryPlaybackUrl(widget.video) ??
            await _resolvePlaybackUrl(widget.video))
        : null;

    await SharePlus.instance.share(
      ShareParams(
        text: _isLibraryVideo && libraryShareUrl != null
            ? 'Check out "${widget.video.title}" from ${widget.video.category ?? 'Library'} on Blue Video\n$libraryShareUrl'
            : 'Check out "${widget.video.title}" on Blue Video',
      ),
    );

    if (_isLibraryVideo) {
      if (!mounted) {
        return;
      }
      setState(() {
        _shareCount += 1;
      });
      return;
    }

    try {
      final response = await _apiService.incrementVideoShare(
        widget.video.id,
        platform: 'short_mode',
      );
      if (!mounted) {
        return;
      }
      final data = response['data'];
      if (response['success'] == true && data is Map<String, dynamic>) {
        setState(() {
          _shareCount = data['shares'] as int? ?? _shareCount;
        });
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _shareCount += 1;
    });
  }

  Future<void> _toggleMute() async {
    final player = _player;
    if (player == null) {
      return;
    }

    if (_isMuted) {
      await player.setVolume(100);
    } else {
      await player.setVolume(0);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _handleSeekChanged(double value) {
    if (_totalDuration.inMilliseconds <= 0) {
      return;
    }

    final clamped = value.clamp(0.0, _totalDuration.inMilliseconds.toDouble());
    setState(() {
      _isScrubbing = true;
      _scrubPositionMilliseconds = clamped;
      _currentPosition = Duration(milliseconds: clamped.round());
    });
  }

  Future<void> _handleSeekEnd(double value) async {
    final player = _player;
    final clamped = _totalDuration.inMilliseconds > 0
        ? value.clamp(0.0, _totalDuration.inMilliseconds.toDouble())
        : 0.0;
    final nextPosition = Duration(milliseconds: clamped.round());

    if (player != null) {
      await player.seek(nextPosition);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isScrubbing = false;
      _scrubPositionMilliseconds = null;
      _currentPosition = nextPosition;
    });
  }

  Future<void> _openFullPlayer() async {
    if (_player != null) {
      await _player!.pause();
    }
    if (widget.immersiveMode) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (!mounted) {
      return;
    }

    if (_isLibraryVideo) {
      final section = _libraryShortSection(widget.video);
      final itemId = _libraryShortSourceId(widget.video);
      if (section == null || itemId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library video details are unavailable.')),
        );
      } else {
        try {
          final detailedVideo = await LibraryService().fetchItemById(
                itemId,
                includeStreams: true,
              ) ??
              LibraryItemModel(
                id: itemId,
                title: widget.video.title,
                description: widget.video.description,
                contentType: 'video',
                section: section,
                isFolder: false,
                fileUrl: widget.video.videoUrl.isNotEmpty ? widget.video.videoUrl : null,
                streamUrl: _shortFeedLibraryPlaybackUrl(widget.video),
                thumbnailUrl: widget.video.thumbnailUrl,
                mimeType: 'video/mp4',
                duration: widget.video.duration,
                metadata: widget.video.metadata,
                createdAt: widget.video.createdAt,
                updatedAt: widget.video.updatedAt,
              );

          if (!mounted) {
            return;
          }

          await context.push(
            '/main/library/section/${Uri.encodeComponent(section)}/video-player',
            extra: LibraryVideoPlayerArgs(
              section: section,
              videos: [detailedVideo],
              initialIndex: 0,
              folderTitle: detailedVideo.displayTitle,
            ),
          );
        } catch (error) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open library video: $error')),
          );
        }
      }
    } else {
      await context.push('/main/video/${widget.video.id}/player');
    }

    if (!mounted || !widget.immersiveMode) {
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
  }

  void _resetState() {
    _likeBurstTimer?.cancel();
    _playingSubscription?.cancel();
    _playingSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription?.cancel();
    _durationSubscription = null;
    _player?.dispose();
    _player = null;
    _videoController = null;
    _errorMessage = null;
    _isInitializing = false;
    _isReady = false;
    _isPlaying = false;
    _isMuted = false;
    _hasTrackedView = false;
    _showLikeBurst = false;
    _likeBurstOffset = null;
    _isScrubbing = false;
    _isFollowingCreator = false;
    _isLoadingFollow = false;
    _scrubPositionMilliseconds = null;
    _followStatusLoadedForUserId = null;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final likeOffset = _likeBurstOffset ??
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2.2);
        final captionMaxWidth = constraints.maxWidth * 0.78;

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaSurface(),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.58),
                      ],
                      stops: const [0.0, 0.18, 0.56, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (_showLikeBurst)
              Positioned(
                left: (likeOffset.dx - 48).clamp(20.0, constraints.maxWidth - 96.0),
                top: (likeOffset.dy - 48).clamp(60.0, constraints.maxHeight - 180.0),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showLikeBurst ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedScale(
                      scale: _showLikeBurst ? 1.0 : 0.6,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 96,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              bottom: 10,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLibraryVideo) ...[
                      _ActionBubble(
                        icon: Icons.folder_outlined,
                        label: widget.video.category ?? 'Library',
                        color: Colors.white,
                        onTap: _openFullPlayer,
                      ),
                      const SizedBox(height: 6),
                    ] else ...[
                      _ActionBubble(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        label: _formatCount(_likeCount),
                        color: _isLiked ? const Color(0xFFFF5C83) : Colors.white,
                        onTap: _toggleLike,
                      ),
                      const SizedBox(height: 6),
                      _ActionBubble(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: _formatCount(widget.video.commentCount),
                        color: Colors.white,
                        onTap: _openFullPlayer,
                      ),
                      const SizedBox(height: 6),
                    ],
                    _ActionBubble(
                      icon: Icons.share_outlined,
                      label: _formatCount(_shareCount),
                      color: Colors.white,
                      onTap: _shareVideo,
                    ),
                    const SizedBox(height: 6),
                    _ActionBubble(
                      icon: _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      label: _isMuted ? 'Muted' : 'Sound',
                      color: Colors.white,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(height: 6),
                    _ActionBubble(
                      icon: Icons.open_in_new_rounded,
                      label: 'Open',
                      color: Colors.white,
                      onTap: _openFullPlayer,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 8,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 6),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: captionMaxWidth),
                  child: _BottomVideoCaption(
                    video: widget.video,
                    durationLabel: _durationLabel,
                    isLibrarySource: _isLibraryVideo,
                    canFollow: _canFollowCreator,
                    isFollowing: _isFollowingCreator,
                    isLoadingFollow: _isLoadingFollow,
                    onFollowTap: _toggleCreatorFollow,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 4),
                child: _BottomSeekBar(
                  value: _seekPositionMilliseconds,
                  max: _maxSeekMilliseconds,
                  onChanged: _handleSeekChanged,
                  onChangeEnd: _handleSeekEnd,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double get _maxSeekMilliseconds {
    if (_totalDuration.inMilliseconds <= 0) {
      return 1;
    }
    return _totalDuration.inMilliseconds.toDouble();
  }

  double get _seekPositionMilliseconds {
    final current = _isScrubbing
        ? (_scrubPositionMilliseconds ?? _currentPosition.inMilliseconds.toDouble())
        : _currentPosition.inMilliseconds.toDouble();
    return current.clamp(0.0, _maxSeekMilliseconds);
  }

  Widget _buildMediaSurface() {
    if (_isLockedVideo) {
      return _buildFallbackSurface(
        title: widget.video.hasCost ? 'Unlock to watch' : 'VIP only',
        subtitle: widget.video.hasCost
            ? '${widget.video.cost} coins required for full playback.'
            : 'Open the full player to preview or unlock this video.',
      );
    }

    if (_isReady && _videoController != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (details) {
          _lastDoubleTapPosition = details.localPosition;
        },
        onDoubleTap: _handleDoubleTap,
        onTap: () async {
          final player = _player;
          if (player == null) {
            return;
          }
          if (_isPlaying) {
            await player.pause();
          } else {
            await player.play();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Video(
                  controller: _videoController!,
                  controls: AdaptiveVideoControls,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (!_isPlaying)
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_isInitializing) {
      return _buildLoadingSurface();
    }

    if (_errorMessage != null) {
      return _buildFallbackSurface(
        title: 'Open in full player',
        subtitle: _errorMessage!,
      );
    }

    return _buildLoadingSurface();
  }

  Widget _buildLoadingSurface() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailBackdrop(),
        const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildFallbackSurface({
    required String title,
    required String subtitle,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailBackdrop(),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.44),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _openFullPlayer,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Full Player'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailBackdrop() {
    final thumbnailUrl = widget.video.calculatedThumbnailUrl;
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Icon(
            Icons.video_library_rounded,
            color: Colors.white54,
            size: 62,
          ),
        ),
      );
    }

    return PresignedImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorWidget: Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 48,
          ),
        ),
      ),
    );
  }
}

class _BottomVideoCaption extends StatelessWidget {
  final VideoModel video;
  final String durationLabel;
  final bool isLibrarySource;
  final bool canFollow;
  final bool isFollowing;
  final bool isLoadingFollow;
  final Future<void> Function() onFollowTap;

  const _BottomVideoCaption({
    required this.video,
    required this.durationLabel,
    required this.isLibrarySource,
    required this.canFollow,
    required this.isFollowing,
    required this.isLoadingFollow,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    final tags = video.tags ?? const <String>[];
    final creatorLabel = isLibrarySource ? video.displayName : '@${video.displayName}';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: ClipOval(
                  child: video.userAvatarUrl != null &&
                          video.userAvatarUrl!.isNotEmpty
                      ? PresignedImage(
                          imageUrl: video.userAvatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.white24,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white24,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  creatorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canFollow) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: isLoadingFollow ? null : onFollowTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isFollowing
                          ? Colors.white.withValues(alpha: 0.16)
                          : const Color(0xFFFF2F63),
                      shape: BoxShape.circle,
                    ),
                    child: isLoadingFollow
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            isFollowing
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
              if (video.cost > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${video.cost} coins',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (video.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              video.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.32,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _MetaChip(
                icon: Icons.play_arrow_rounded,
                label: video.formattedViewCount,
              ),
              if (durationLabel.isNotEmpty)
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: durationLabel,
                ),
              if (isLibrarySource)
                _MetaChip(
                  icon: Icons.folder_outlined,
                  label: _shortFeedSectionLabel(
                    _libraryShortSection(video) ?? video.category ?? 'Library',
                  ),
                ),
              if (video.category != null && video.category!.isNotEmpty)
                _MetaChip(
                  icon: Icons.category_outlined,
                  label: video.category!,
                ),
              ...tags.take(1).map((tag) => _MetaChip(label: '#$tag')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomSeekBar extends StatelessWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _BottomSeekBar({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
        thumbColor: Colors.white,
      ),
      child: Slider(
        min: 0,
        max: max,
        value: value.clamp(0.0, max),
        onChanged: max > 1 ? onChanged : null,
        onChangeEnd: max > 1 ? onChangeEnd : null,
      ),
    );
  }
}

class _ActionBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;

  const _ActionBubble({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _MetaChip({
    this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 11),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPillLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopPillLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

String _labelForSort(String sortBy) {
  switch (sortBy) {
    case 'trending':
      return 'Trending';
    case 'topRated':
      return 'Top Rated';
    case 'mostViewed':
      return 'Most Viewed';
    case 'random':
      return 'Random';
    default:
      return 'Newest';
  }
}
