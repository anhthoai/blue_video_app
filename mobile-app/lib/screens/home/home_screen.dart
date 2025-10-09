import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/video_card.dart';
import '../../widgets/story_list.dart';
import '../../widgets/trending_videos.dart';
import '../../core/services/video_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

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
    final videosAsync = ref.watch(videoListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Blue Video'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Navigate to search screen
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(videoListProvider);
        },
        child: videosAsync.when(
          data: (videos) => CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Story List
              const SliverToBoxAdapter(child: StoryList()),

              // Trending Videos Section
              const SliverToBoxAdapter(child: TrendingVideos()),

              // Video Feed
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < videos.length) {
                      final video = videos[index];
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
                        currentUserId: 'mock_user_1',
                        currentUsername: 'Test User',
                        currentUserAvatar: 'https://i.pravatar.cc/150?img=1',
                        onTap: () {
                          context.go('/main/video/${video.id}/player');
                        },
                        onAuthorTap: () {
                          context.go('/main/profile/${video.userId}');
                        },
                      );
                    }
                    return null;
                  },
                  childCount: videos.length,
                ),
              ),

              // Loading indicator
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading videos: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(videoListProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
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
}
