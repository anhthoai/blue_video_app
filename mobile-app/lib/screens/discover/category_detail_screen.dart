import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/category_model.dart';
import '../../models/video_model.dart';
import '../../core/services/api_service.dart';
import '../../widgets/common/presigned_image.dart';

class CategoryDetailScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryDetailScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<VideoModel> _videos = [];
  bool _isLoadingVideos = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreVideos = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_isLoadingMore &&
        _hasMoreVideos) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoadingVideos = true;
      _currentPage = 1;
      _videos = [];
      _hasMoreVideos = true;
    });

    try {
      final videos = await _apiService.getVideosByCategory(
        widget.category.id,
        page: _currentPage,
        limit: 20,
      );
      setState(() {
        _videos = videos.map((json) => VideoModel.fromJson(json)).toList();
        _hasMoreVideos = videos.length >= 20;
      });
    } catch (e) {
      print('Error loading videos: $e');
    } finally {
      setState(() {
        _isLoadingVideos = false;
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final videos = await _apiService.getVideosByCategory(
        widget.category.id,
        page: _currentPage,
        limit: 20,
      );
      setState(() {
        _videos
            .addAll(videos.map((json) => VideoModel.fromJson(json)).toList());
        _hasMoreVideos = videos.length >= 20;
      });
    } catch (e) {
      print('Error loading more videos: $e');
      setState(() {
        _currentPage--; // Revert page increment on error
      });
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Icon mapping for categories
    final iconMap = {
      'Members': Icons.people,
      'Music': Icons.music_note,
      'Gaming': Icons.games,
      'Sports': Icons.sports_soccer,
      'Education': Icons.school,
      'Comedy': Icons.emoji_emotions,
      'Technology': Icons.computer,
      'Pop': Icons.music_note,
      'Rock': Icons.music_note,
      'Action': Icons.sports_esports,
      'Strategy': Icons.psychology,
      'Programming': Icons.code,
      'Science': Icons.science,
    };

    final colorMap = {
      'Members': Colors.deepOrange,
      'Music': Colors.purple,
      'Gaming': Colors.green,
      'Sports': Colors.blue,
      'Education': Colors.orange,
      'Comedy': Colors.yellow,
      'Technology': Colors.cyan,
      'Pop': Colors.pink,
      'Rock': Colors.deepPurple,
      'Action': Colors.red,
      'Strategy': Colors.indigo,
      'Programming': Colors.teal,
      'Science': Colors.lightBlue,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.categoryName),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Category header with description
          if (widget.category.categoryDesc != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category.categoryDesc!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                  if (widget.category.videoCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.category.videoCount} videos available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ],
              ),
            ),

          // Subcategories and videos grid
          Expanded(
            child: _isLoadingVideos
                ? const Center(child: CircularProgressIndicator())
                : _buildContentGrid(context, iconMap, colorMap),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid(
    BuildContext context,
    Map<String, IconData> iconMap,
    Map<String, Color> colorMap,
  ) {
    // Combine subcategories and videos
    final totalItems = widget.category.children.length + _videos.length;

    if (totalItems == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No content available yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Videos and subcategories will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 items per row
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: totalItems,
            itemBuilder: (context, index) {
              // Show subcategories first, then videos
              if (index < widget.category.children.length) {
                final subCategory = widget.category.children[index];
                final icon = iconMap[subCategory.categoryName] ?? Icons.folder;
                final color = colorMap[subCategory.categoryName] ?? Colors.grey;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildCategoryCard(
                      context,
                      subCategory,
                      icon,
                      color,
                      constraints.maxWidth,
                    );
                  },
                );
              } else {
                final videoIndex = index - widget.category.children.length;
                final video = _videos[videoIndex];
                return _buildVideoCard(context, video);
              }
            },
          ),
        ),
        if (_isLoadingMore)
          Container(
            padding: const EdgeInsets.all(16),
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoModel video) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/main/video/${video.id}/player');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.thumbnailUrl != null)
                    Image.network(
                      video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.video_library, size: 48),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.video_library, size: 48),
                    ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.formattedViewCount,
                    style: TextStyle(
                      fontSize: 10,
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

  Widget _buildCategoryCard(
    BuildContext context,
    CategoryModel subCategory,
    IconData icon,
    Color color,
    double maxWidth,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to subcategory detail screen to show its videos
          context.push('/main/category/${subCategory.id}', extra: subCategory);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category thumbnail or icon
              if (subCategory.categoryThumb != null)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PresignedImage(
                      imageUrl: subCategory.categoryThumb!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: Icon(icon, size: 48, color: color),
                    ),
                  ),
                )
              else
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 48, color: color),
                ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  subCategory.categoryName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subCategory.categoryDesc != null) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    subCategory.categoryDesc!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
