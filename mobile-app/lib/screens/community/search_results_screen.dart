import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/community_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/community_post.dart';
import '../../widgets/community/community_post_widget.dart';
import '../../widgets/community/video_card_widget.dart';
import '../community/_fullscreen_media_gallery.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load search results when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (widget.query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final communityService = ref.read(communityServiceStateProvider.notifier);
      await communityService.searchPosts(query: widget.query.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Search: "${widget.query}"'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _performSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.article),
              text: 'All Posts',
            ),
            Tab(
              icon: Icon(Icons.video_library),
              text: 'Videos',
            ),
            Tab(
              icon: Icon(Icons.person),
              text: 'Authors',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllPostsTab(communityState, authState),
          _buildVideosTab(communityState, authState),
          _buildAuthorsTab(communityState, authState),
        ],
      ),
    );
  }

  Widget _buildAllPostsTab(CommunityServiceState state, AuthService authState) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No posts found for "${widget.query}"',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _performSearch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.searchResults.length,
        itemBuilder: (context, index) {
          final post = state.searchResults[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CommunityPostWidget(
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
                context.push('/main/profile/${post.userId}');
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideosTab(CommunityServiceState state, AuthService authState) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter search results to show only videos
    final videoPosts =
        state.searchResults.where((post) => post.videoUrls.isNotEmpty).toList();

    if (videoPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No videos found for "${widget.query}"',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _performSearch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: videoPosts.length,
        itemBuilder: (context, index) {
          final post = videoPosts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: VideoCardWidget(
              post: post,
              onTap: () => _openVideoPlayer(post),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuthorsTab(CommunityServiceState state, AuthService authState) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group posts by author
    final Map<String, List<CommunityPost>> authorPosts = {};
    for (final post in state.searchResults) {
      final authorKey = '${post.firstName} ${post.lastName}'.trim();
      if (authorKey.isNotEmpty) {
        authorPosts.putIfAbsent(authorKey, () => []).add(post);
      }
    }

    final authors = authorPosts.keys.toList()..sort();

    if (authors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No authors found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No authors found for "${widget.query}"',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _performSearch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: authors.length,
        itemBuilder: (context, index) {
          final author = authors[index];
          final posts = authorPosts[author]!;
          final firstPost = posts.first;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: firstPost.userAvatar.isNotEmpty
                            ? NetworkImage(firstPost.userAvatar)
                            : null,
                        child: firstPost.userAvatar.isEmpty
                            ? const Icon(Icons.person, size: 24)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  author,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (firstPost.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '@${firstPost.username}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${posts.length} post${posts.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.push('/main/profile/${firstPost.userId}');
                        },
                        child: const Text('View Profile'),
                      ),
                    ],
                  ),
                ),

                // Author's posts preview
                if (posts.length <= 3)
                  ...posts.map((post) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CommunityPostWidget(
                          post: post,
                          currentUserId: authState.currentUser?.id,
                          currentUsername: authState.currentUser?.username,
                          currentUserAvatar:
                              authState.currentUser?.avatarUrl ?? '',
                          onTap: () {
                            context.push('/main/post/${post.id}');
                          },
                          onUserTap: () {
                            context.push('/main/profile/${post.userId}');
                          },
                        ),
                      ))
                else ...[
                  ...posts.take(2).map((post) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CommunityPostWidget(
                          post: post,
                          currentUserId: authState.currentUser?.id,
                          currentUsername: authState.currentUser?.username,
                          currentUserAvatar:
                              authState.currentUser?.avatarUrl ?? '',
                          onTap: () {
                            context.push('/main/post/${post.id}');
                          },
                          onUserTap: () {
                            context.push('/main/profile/${post.userId}');
                          },
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          context.push('/main/profile/${firstPost.userId}');
                        },
                        child: Text(
                            'View ${posts.length - 2} more posts by $author'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
