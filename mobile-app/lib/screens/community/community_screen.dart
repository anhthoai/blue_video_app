import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/community_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/community_post.dart';
import '../../widgets/community/community_post_widget.dart';
import '../../widgets/community/video_card_widget.dart';
import '../../screens/community/_fullscreen_media_gallery.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Always clear tag posts and load fresh posts when community screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearTagPostsAndLoadPosts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Clear tag posts and load fresh posts
  void _clearTagPostsAndLoadPosts() {
    // Clear any tag posts from previous navigation
    ref.read(communityServiceStateProvider.notifier).clearTagPosts();
    // Load fresh posts, trending posts, and tags
    _loadPosts();
    _loadTrendingPosts();
    _loadTags();
  }

  Future<void> _loadPosts() async {
    try {
      final communityService = ref.read(communityServiceStateProvider.notifier);
      await communityService.loadPosts();
    } catch (e) {
      print('Error loading community posts: $e');
    }
  }

  Future<void> _loadTags() async {
    final communityService = ref.read(communityServiceStateProvider.notifier);
    await communityService.loadTags();
  }

  Future<void> _loadTrendingPosts() async {
    try {
      final communityService = ref.read(communityServiceStateProvider.notifier);
      await communityService.loadTrendingPosts();
    } catch (e) {
      print('Error loading trending posts: $e');
    }
  }

  void _openVideoPlayer(CommunityPost post) {
    if (post.videoUrls.isEmpty) return;

    // Create media items list with only videos from the post
    final List<MediaItem> mediaItems = [];

    // Add only videos (no images)
    for (var videoUrl in post.videoUrls) {
      mediaItems.add(MediaItem(url: videoUrl, isVideo: true));
    }

    if (mediaItems.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullscreenMediaGallery(
            mediaItems: mediaItems,
            initialIndex: 0, // Start with first video
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityState = ref.watch(communityServiceStateProvider);
    final authState = ref.watch(authServiceProvider);

    // Removed auto-loading logic to prevent infinite loop
    // Posts are loaded in initState and when user manually refreshes

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Posts', icon: Icon(Icons.article)),
            Tab(text: 'Trending', icon: Icon(Icons.trending_up)),
            Tab(text: 'Videos', icon: Icon(Icons.video_library)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(communityState, authState),
          _buildTrendingTab(communityState, authState),
          _buildVideosTab(communityState),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPost,
        heroTag: 'community_add_post',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPostsTab(CommunityServiceState state, AuthService authState) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.posts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: 'No posts yet',
        subtitle: 'Be the first to share something with the community!',
        actionText: 'Create Post',
        onAction: _createPost,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.posts.length,
        itemBuilder: (context, index) {
          final post = state.posts[index];
          return CommunityPostWidget(
            post: post,
            currentUserId: authState.currentUser?.id,
            currentUsername: authState.currentUser?.username,
            currentUserAvatar: authState.currentUser?.avatarUrl ?? '',
            onTap: () {
              // Navigate to post detail
              context.push('/main/post/${post.id}');
            },
            onUserTap: () {
              // Navigate to user profile
              context.go('/main/profile/${post.userId}');
            },
          );
        },
      ),
    );
  }

  Widget _buildTrendingTab(CommunityServiceState state, AuthService authState) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use trending posts from state (ordered by views)
    final trendingPosts = state.trendingPosts;

    if (trendingPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: 'No trending posts',
        subtitle: 'Check back later for trending content!',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrendingPosts,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: trendingPosts.length,
        itemBuilder: (context, index) {
          final post = trendingPosts[index];
          return CommunityPostWidget(
            post: post,
            currentUserId: authState.currentUser?.id,
            currentUsername: authState.currentUser?.username,
            currentUserAvatar: authState.currentUser?.avatarUrl ?? '',
            onTap: () {
              // Navigate to post detail
              context.push('/main/post/${post.id}');
            },
            onUserTap: () {
              // Navigate to user profile
              context.go('/main/profile/${post.userId}');
            },
          );
        },
      ),
    );
  }

  Widget _buildVideosTab(CommunityServiceState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use video posts for videos tab
    final videoPosts =
        state.posts.where((post) => post.videoUrls.isNotEmpty).toList();

    if (videoPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.video_library,
        title: 'No videos yet',
        subtitle: 'Be the first to share a video with the community!',
        actionText: 'Create Post',
        onAction: _createPost,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: videoPosts.length,
        itemBuilder: (context, index) {
          final post = videoPosts[index];
          return VideoCardWidget(
            post: post,
            onTap: () => _openVideoPlayer(post),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Community'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search posts, authors, usernames, tags...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
              onSubmitted: (value) {
                Navigator.pop(context);
                _searchPosts();
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Search across:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text('• Post content and titles'),
            const Text('• Author names and usernames'),
            const Text('• Tags and categories'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchPosts();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _searchPosts() {
    if (_searchController.text.trim().isEmpty) return;

    // Navigate to search results screen
    context.push(
        '/main/search/${Uri.encodeComponent(_searchController.text.trim())}');
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter Posts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Category filter
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...['all', 'technology', 'entertainment', 'sports', 'news']
                .map((category) {
              return ListTile(
                title: Text(category.toUpperCase()),
                trailing: _selectedCategory == category
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                  Navigator.pop(context);
                  _loadPosts();
                },
              );
            }),
            const SizedBox(height: 16),
            // Tag filter
            const Text(
              'Filter by Tag',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter tag (e.g., #video, #coin)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.tag),
              ),
              onSubmitted: (tag) {
                if (tag.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _filterByTag(tag.trim());
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _clearFilters();
              },
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _filterByTag(String tag) async {
    // Navigate to tag posts screen
    context.push('/main/tag/$tag');
  }

  void _clearFilters() async {
    setState(() {
      _selectedCategory = 'all';
    });
    await _loadPosts();
  }

  void _createPost() async {
    // Navigate to create post screen and wait for result
    final result = await context.push('/main/create-post');

    // If post was created successfully, refresh the posts
    if (result == true) {
      // Reload posts instead of invalidating to avoid recreation
      await ref.read(communityServiceStateProvider.notifier).loadPosts();
    }
  }
}
