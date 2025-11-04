import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/video_card.dart';
import '../../widgets/common/presigned_image.dart';
import '../../core/services/video_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/category_model.dart';
import '../../models/video_model.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

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
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final videosAsync = ref.watch(videoListProvider(VideoFilterParams(
      categoryId: _selectedCategoryId,
      sortBy: _selectedFilter,
    )));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(l10n.appName),
        centerTitle: true,
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
      body: Column(
        children: [
          // Categories horizontal scroll
          categoriesAsync.when(
            data: (categories) => _buildCategoriesBar(categories, l10n),
            loading: () => const SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const SizedBox.shrink(),
          ),

          // Filter chips
          _buildFilterChips(l10n),

          // Video content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(categoriesProvider);
                ref.invalidate(videoListProvider(VideoFilterParams(
                  categoryId: _selectedCategoryId,
                  sortBy: _selectedFilter,
                )));
              },
              child: videosAsync.when(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/main/upload');
        },
        heroTag: 'home_upload',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoriesBar(
      List<CategoryModel> categories, AppLocalizations l10n) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          // "All" category
          _buildCategoryChip(
            id: null,
            name: l10n.all,
            isSelected: _selectedCategoryId == null,
          ),
          // Other categories
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
        color: Theme.of(context).cardColor.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
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
                          color: Colors.black.withOpacity(0.8),
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
}
