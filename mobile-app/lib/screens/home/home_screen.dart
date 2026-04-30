import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/video_card.dart';
import '../../widgets/common/presigned_image.dart';
import '../../core/services/video_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/library_service.dart';
import '../../core/models/library_item_model.dart';
import '../../core/models/library_navigation.dart';
import '../../models/category_model.dart';
import '../../models/video_model.dart';
import '../../l10n/app_localizations.dart';
import '../video/short_video_feed_screen.dart';

final homeFeedTabIndexProvider = StateProvider<int>((ref) => 0);

const String _libraryCategoryId = '__home_library__';
const int _homeLibraryPageSize = 120;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final TabController _homeTabController;
  final bool _isLoading = false;
  bool _isLoadingLibraryVideos = false;
  bool _isLoadingMoreLibraryVideos = false;
  bool _hasMoreLibraryVideos = true;
  int _libraryPage = 0;
  int _libraryRequestVersion = 0;
  String? _libraryLoadError;
  List<LibraryItemModel> _libraryVideos = const <LibraryItemModel>[];

  // Category and filter state
  String? _selectedCategoryId;
  String _selectedFilter = 'newest'; // Default filter

  // Filter options
  final List<Map<String, String>> _filterOptions = [
    {'id': 'newest', 'name': 'Newest'},
    {'id': 'trending', 'name': 'Trending'},
    {'id': 'topRated', 'name': 'Top Rated'},
    {'id': 'mostViewed', 'name': 'Most Viewed'},
    {'id': 'random', 'name': 'Random'},
  ];

  @override
  void initState() {
    super.initState();
    _homeTabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    ref.read(homeFeedTabIndexProvider.notifier).state = 0;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _homeTabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    ref.read(homeFeedTabIndexProvider.notifier).state = _homeTabController.index;
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      unawaited(_loadMoreVideos());
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_selectedCategoryId == _libraryCategoryId) {
      await _loadLibraryVideos();
    }
  }

  Future<void> _refreshLibraryVideos() async {
    await _loadLibraryVideos(reset: true);
  }

  Future<void> _loadLibraryVideos({bool reset = false}) async {
    if (_selectedCategoryId != _libraryCategoryId) {
      return;
    }

    if (reset) {
      _libraryRequestVersion += 1;
    } else if (_isLoadingLibraryVideos ||
        _isLoadingMoreLibraryVideos ||
        !_hasMoreLibraryVideos) {
      return;
    }

    final requestVersion = _libraryRequestVersion;
    final nextPage = reset ? 1 : _libraryPage + 1;

    setState(() {
      _libraryLoadError = null;
      if (reset) {
        _isLoadingLibraryVideos = true;
        _isLoadingMoreLibraryVideos = false;
        _hasMoreLibraryVideos = true;
        _libraryPage = 0;
        _libraryVideos = const <LibraryItemModel>[];
      } else {
        _isLoadingLibraryVideos = false;
        _isLoadingMoreLibraryVideos = true;
      }
    });

    try {
      final fetchedVideos = await LibraryService().fetchVideoFeed(
        LibraryVideoFeedRequest(
          page: nextPage,
          limit: _homeLibraryPageSize,
          sortBy: _selectedFilter,
        ),
      );
      final filteredVideos = fetchedVideos
          .where(_isHomeLibraryVideo)
          .toList(growable: false);

      if (!mounted || requestVersion != _libraryRequestVersion) {
        return;
      }

      setState(() {
        _libraryVideos = reset
            ? filteredVideos
            : _mergeHomeLibraryVideos(_libraryVideos, filteredVideos);
        _libraryPage = nextPage;
        _hasMoreLibraryVideos = fetchedVideos.length >= _homeLibraryPageSize;
      });
    } catch (error) {
      if (!mounted || requestVersion != _libraryRequestVersion) {
        return;
      }

      setState(() {
        _libraryLoadError = error.toString();
      });
    } finally {
      if (mounted && requestVersion == _libraryRequestVersion) {
        setState(() {
          _isLoadingLibraryVideos = false;
          _isLoadingMoreLibraryVideos = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLibrarySelected = _selectedCategoryId == _libraryCategoryId;
    final categoriesAsync = ref.watch(categoriesProvider);
    final videosAsync = isLibrarySelected
        ? const AsyncValue<List<VideoModel>>.data(<VideoModel>[])
        : ref.watch(videoListProvider(VideoFilterParams(
            categoryId: _selectedCategoryId,
            sortBy: _selectedFilter,
          )));
    final isExploreTab = _homeTabController.index == 0;
    final appBarBackground = isExploreTab
        ? Theme.of(context).colorScheme.surface
        : Colors.black;
    final appBarForeground =
        isExploreTab ? Theme.of(context).colorScheme.onSurface : Colors.white;

    return Scaffold(
      backgroundColor:
          isExploreTab ? Theme.of(context).colorScheme.surface : Colors.black,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TabBar(
          controller: _homeTabController,
          isScrollable: true,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor:
              isExploreTab ? Theme.of(context).colorScheme.primary : Colors.white,
          indicatorWeight: 2.5,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          labelColor: appBarForeground,
          unselectedLabelColor: isExploreTab
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.56)
              : Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Explore'),
            Tab(text: 'Following'),
            Tab(text: 'For You'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.push('/main/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications screen
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _homeTabController,
        children: [
          _buildExploreTab(
            l10n,
            categoriesAsync,
            videosAsync,
          ),
          const ShortVideoFeedView(
            query: ShortVideoFeedQuery(
              scope: ShortVideoFeedScope.following,
              sortBy: 'newest',
            ),
          ),
          const ShortVideoFeedView(
            query: ShortVideoFeedQuery(
              scope: ShortVideoFeedScope.forYou,
              sortBy: 'trending',
              includeLibraryVideos: true,
            ),
          ),
        ],
      ),
      floatingActionButton: isExploreTab
          ? FloatingActionButton(
              onPressed: () {
                context.go('/main/upload');
              },
              heroTag: 'home_upload',
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildExploreTab(
    AppLocalizations l10n,
    AsyncValue<List<CategoryModel>> categoriesAsync,
    AsyncValue<List<VideoModel>> videosAsync,
  ) {
    return Column(
      children: [
        categoriesAsync.when(
          data: (categories) => _buildCategoriesBar(categories, l10n),
          loading: () => const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        ),
        _buildFilterChips(l10n),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesProvider);
              if (_selectedCategoryId == _libraryCategoryId) {
                await _refreshLibraryVideos();
                return;
              }
              ref.invalidate(videoListProvider(VideoFilterParams(
                categoryId: _selectedCategoryId,
                sortBy: _selectedFilter,
              )));
            },
            child: _selectedCategoryId == _libraryCategoryId
              ? _buildLibrarySection(l10n)
                : videosAsync.when(
                    data: (videos) => _buildVideoContent(videos, l10n),
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('${l10n.errorLoadingData}: $error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref.invalidate(videoListProvider(VideoFilterParams(
                                categoryId: _selectedCategoryId,
                                sortBy: _selectedFilter,
                              )));
                            },
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesBar(
      List<CategoryModel> categories, AppLocalizations l10n) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildCategoryChip(
            id: null,
            name: l10n.all,
            isSelected: _selectedCategoryId == null,
          ),
          _buildCategoryChip(
            id: _libraryCategoryId,
            name: l10n.library,
            isSelected: _selectedCategoryId == _libraryCategoryId,
          ),
          ...categories.map((category) => _buildCategoryChip(
                id: category.id,
                name: category.categoryName,
                isSelected: _selectedCategoryId == category.id,
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String? id,
    required String name,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategoryId = id;
          });
          if (id == _libraryCategoryId) {
            unawaited(_refreshLibraryVideos());
          }
        },
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    // Map filter IDs to localized names
    final filterNames = {
      'newest': l10n.newest,
      'trending': l10n.trending,
      'topRated': l10n.topRated,
      'mostViewed': l10n.mostViewed,
      'random': l10n.random,
    };

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: _filterOptions.map((filter) {
          final filterId = filter['id']!;
          final isSelected = _selectedFilter == filterId;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilterChip(
              label: Text(filterNames[filterId] ?? filter['name']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filterId;
                });
                if (_selectedCategoryId == _libraryCategoryId) {
                  unawaited(_refreshLibraryVideos());
                }
              },
              selectedColor: Theme.of(context).colorScheme.secondary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVideoContent(List<VideoModel> videos, AppLocalizations l10n) {
    if (videos.isEmpty) {
      return Center(
        child: Text(l10n.noVideosYet),
      );
    }

    // Use 2-column grid for non-All categories, single column for All
    final isGridView = _selectedCategoryId != null;

    if (isGridView) {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: videos.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= videos.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final video = videos[index];
          return _buildGridVideoCard(video);
        },
      );
    } else {
      return ListView.builder(
        controller: _scrollController,
        itemCount: videos.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= videos.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final video = videos[index];
          return _buildListVideoCard(video);
        },
      );
    }
  }

  Widget _buildLibrarySection(
    AppLocalizations l10n,
  ) {
    if (_isLoadingLibraryVideos && _libraryVideos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_libraryLoadError != null && _libraryVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('${l10n.errorLoadingData}: ${_libraryLoadError!}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                unawaited(_refreshLibraryVideos());
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    return _buildLibraryContent(_libraryVideos, l10n);
  }

  Widget _buildLibraryContent(
    List<LibraryItemModel> videos,
    AppLocalizations l10n,
  ) {
    if (videos.isEmpty) {
      return Center(
        child: Text(l10n.noVideosYet),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.63,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videos.length + (_isLoadingMoreLibraryVideos ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= videos.length) {
          return const Card(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final video = videos[index];
        return _buildLibraryVideoCard(video);
      },
    );
  }

  Widget _buildListVideoCard(VideoModel video) {
    return VideoCard(
      videoId: video.id,
      title: video.title,
      thumbnailUrl: video.calculatedThumbnailUrl,
      duration: video.formattedDuration,
      viewCount: video.viewCount,
      likeCount: video.likeCount,
      commentCount: video.commentCount,
      shareCount: video.shareCount,
      authorName: video.displayName,
      authorAvatar: video.userAvatarUrl,
      currentUserId:
          ref.watch(authServiceProvider).currentUser?.id ?? 'mock_user_1',
      currentUsername:
          ref.watch(authServiceProvider).currentUser?.username ?? 'Test User',
      currentUserAvatar:
          ref.watch(authServiceProvider).currentUser?.avatarUrl ??
              'https://i.pravatar.cc/150?img=1',
      onTap: () {
        context.go('/main/video/${video.id}/player');
      },
      onAuthorTap: () {
        context.go('/main/profile/${video.userId}');
      },
    );
  }

  Widget _buildGridVideoCard(VideoModel video) {
    return GestureDetector(
      onTap: () {
        context.go('/main/video/${video.id}/player');
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    child: PresignedImage(
                      imageUrl: video.calculatedThumbnailUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.video_library,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  // Duration badge
                  if (video.formattedDuration.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Video info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.viewCount} views',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
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

  Widget _buildLibraryVideoCard(LibraryItemModel video) {
    final previewUrl = video.imageUrl;
    final viewCount = _libraryMetricInt(
      video,
      const ['viewCount', 'views', 'watchCount'],
    );
    final subtitleParts = <String>[
      _formatLibrarySectionLabel(video.section),
      if (video.formattedDuration.isNotEmpty) video.formattedDuration,
      if (video.formattedFileSize.isNotEmpty) video.formattedFileSize,
    ];

    return GestureDetector(
      onTap: () async {
        await _openLibraryVideo(video);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (previewUrl != null && previewUrl.isNotEmpty)
                    Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.video_library, size: 48),
                        );
                      },
                    )
                  else
                    Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.video_library, size: 48),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _formatLibrarySectionLabel(video.section),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (video.formattedDuration.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              video.formattedDuration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    viewCount > 0
                        ? '$viewCount views'
                        : (video.filePath ?? video.fileUrl ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
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

  Future<void> _openLibraryVideo(LibraryItemModel video) async {
    try {
      final detailedVideo =
          await LibraryService().fetchItemById(video.id, includeStreams: true) ??
              video;
      if (!mounted) {
        return;
      }

      context.push(
        '/main/library/section/${Uri.encodeComponent(detailedVideo.section)}/video-player',
        extra: LibraryVideoPlayerArgs(
          section: detailedVideo.section,
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
        SnackBar(
          content: Text('Failed to open video: $error'),
        ),
      );
    }
  }
}

List<LibraryItemModel> _mergeHomeLibraryVideos(
  List<LibraryItemModel> existingVideos,
  List<LibraryItemModel> incomingVideos,
) {
  final mergedVideos = List<LibraryItemModel>.from(existingVideos);
  final seenIds = existingVideos.map((video) => video.id).toSet();

  for (final video in incomingVideos) {
    if (seenIds.add(video.id)) {
      mergedVideos.add(video);
    }
  }

  return mergedVideos;
}

bool _isHomeLibraryVideo(LibraryItemModel item) {
  if (item.isFolder) {
    return false;
  }

  final content = item.contentType.toLowerCase();
  final mime = item.mimeType?.toLowerCase() ?? '';
  final path = (item.filePath ?? item.fileUrl ?? '').toLowerCase();

  return content == 'video' ||
      mime.startsWith('video/') ||
      ['.mp4', '.m4v', '.mkv', '.mov', '.webm', '.avi']
          .any((ext) => path.endsWith(ext));
}

int _libraryMetricInt(LibraryItemModel item, List<String> keys) {
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

String _formatLibrarySectionLabel(String section) {
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
