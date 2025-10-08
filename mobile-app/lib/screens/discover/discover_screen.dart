import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../models/category_model.dart';
import '../../models/video_model.dart';
import '../../widgets/common/presigned_image.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final ScrollController _trendingScrollController = ScrollController();

  List<VideoModel> _trendingVideos = [];
  List<CategoryModel> _categories = [];
  bool _isLoadingTrending = false;
  bool _isLoadingMoreTrending = false;
  bool _isLoadingCategories = false;
  int _trendingPage = 1;
  bool _hasMoreTrending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrendingVideos();
    _loadCategories();
    _trendingScrollController.addListener(_onTrendingScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _trendingScrollController.dispose();
    super.dispose();
  }

  void _onTrendingScroll() {
    if (_trendingScrollController.position.pixels >=
            _trendingScrollController.position.maxScrollExtent - 500 &&
        !_isLoadingMoreTrending &&
        _hasMoreTrending) {
      _loadMoreTrendingVideos();
    }
  }

  Future<void> _loadTrendingVideos() async {
    setState(() {
      _isLoadingTrending = true;
      _trendingPage = 1;
      _trendingVideos = [];
      _hasMoreTrending = true;
    });

    try {
      print('🔍 Loading trending videos page $_trendingPage...');
      final videos =
          await _apiService.getTrendingVideos(page: _trendingPage, limit: 20);
      print('✅ Received ${videos.length} trending videos');
      setState(() {
        _trendingVideos =
            videos.map((json) => VideoModel.fromJson(json)).toList();
        _hasMoreTrending = videos.length >= 20;
      });
      print('✅ Parsed ${_trendingVideos.length} video models');
    } catch (e) {
      print('❌ Error loading trending videos: $e');
    } finally {
      setState(() {
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _loadMoreTrendingVideos() async {
    if (_isLoadingMoreTrending || !_hasMoreTrending) return;

    setState(() {
      _isLoadingMoreTrending = true;
      _trendingPage++;
    });

    try {
      final videos =
          await _apiService.getTrendingVideos(page: _trendingPage, limit: 20);
      setState(() {
        _trendingVideos
            .addAll(videos.map((json) => VideoModel.fromJson(json)).toList());
        _hasMoreTrending = videos.length >= 20;
      });
    } catch (e) {
      print('Error loading more trending videos: $e');
      setState(() {
        _trendingPage--; // Revert page increment on error
      });
    } finally {
      setState(() {
        _isLoadingMoreTrending = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories =
            categories.map((json) => CategoryModel.fromJson(json)).toList();
      });
    } catch (e) {
      print('Error loading categories: $e');
    } finally {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Navigate to search screen
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Trending'),
            Tab(text: 'Categories'),
            Tab(text: 'Live'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTrendingTab(), _buildCategoriesTab(), _buildLiveTab()],
      ),
    );
  }

  Widget _buildTrendingTab() {
    if (_isLoadingTrending) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trendingVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No trending videos yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _trendingScrollController,
      padding: const EdgeInsets.all(16),
            itemCount: _trendingVideos.length,
      itemBuilder: (context, index) {
              final video = _trendingVideos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        if (video.calculatedThumbnailUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: PresignedImage(
                              imageUrl: video.calculatedThumbnailUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF757575),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  title: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${video.formattedViewCount} • ${video.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: const Icon(Icons.trending_up, color: Colors.orange),
            onTap: () {
                    context.push('/main/video/${video.id}/player');
            },
          ),
        );
      },
          ),
        ),
        if (_isLoadingMoreTrending)
          Container(
            padding: const EdgeInsets.all(16),
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Icon mapping for categories
    final iconMap = {
      'Members': Icons.people,
      'Music': Icons.music_note,
      'Gaming': Icons.games,
      'Sports': Icons.sports_soccer,
      'Education': Icons.school,
      'Comedy': Icons.emoji_emotions,
      'Technology': Icons.computer,
    };

    final colorMap = {
      'Members': Colors.deepOrange,
      'Music': Colors.purple,
      'Gaming': Colors.green,
      'Sports': Colors.blue,
      'Education': Colors.orange,
      'Comedy': Colors.yellow,
      'Technology': Colors.cyan,
    };

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final icon = iconMap[category.categoryName] ?? Icons.category;
        final color = colorMap[category.categoryName] ?? Colors.grey;

        return Card(
          child: InkWell(
            onTap: () {
              context.push('/main/category/${category.id}', extra: category);
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Category thumbnail or icon
                if (category.categoryThumb != null)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PresignedImage(
                        imageUrl: category.categoryThumb!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: Icon(icon, size: 48, color: color),
                      ),
                    ),
                  )
                else
                  Icon(icon, size: 48, color: color),
                const SizedBox(height: 12),
                Text(
                  category.categoryName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (category.videoCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${category.videoCount} videos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
                // Show subcategories count if any
                if (category.children.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${category.children.length} subcategories',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
              children: [
          Icon(Icons.live_tv, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Live Streaming',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Coming Soon',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Watch and broadcast live streams with your audience in real-time',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}
