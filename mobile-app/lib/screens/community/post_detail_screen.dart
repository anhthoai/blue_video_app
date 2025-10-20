import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/community_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/social_service.dart';
import '../../models/community_post.dart';
import '../../models/comment_model.dart';
import '../../widgets/community/nsfw_blur_wrapper.dart';
import '../../widgets/dialogs/coin_payment_dialog.dart';
import '../../widgets/community/coin_vip_indicator.dart';
import '../../widgets/community/post_content_widget.dart';
import '../../core/providers/unlocked_posts_provider.dart';
import '_fullscreen_media_gallery.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  CommunityPost? _post;
  bool _isLoading = true;
  String? _error;
  bool _isLoadingComments = false;
  bool _commentsLoaded = false; // Track if comments have been loaded
  List<CommentModel> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final communityState = ref.read(communityServiceStateProvider);

      // First try to find the post in existing posts
      try {
        final existingPost = communityState.posts.firstWhere(
          (post) => post.id == widget.postId,
        );
        setState(() {
          _post = existingPost;
          _isLoading = false;
        });

        // Debug logging
        print('🎯 Post Detail: Loaded post from existing posts');
        print('   Post ID: ${_post!.id}');
        print('   Cost: ${_post!.cost}, VIP: ${_post!.requiresVip}');

        // Load comments for this post after frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadComments();
        });
        return;
      } catch (e) {
        // Post not found in existing posts, try trending posts
        try {
          final existingPost = communityState.trendingPosts.firstWhere(
            (post) => post.id == widget.postId,
          );
          setState(() {
            _post = existingPost;
            _isLoading = false;
          });

          // Debug logging
          print('🎯 Post Detail: Loaded post from trending posts');
          print('   Post ID: ${_post!.id}');
          print('   Cost: ${_post!.cost}, VIP: ${_post!.requiresVip}');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadComments();
          });
          return;
        } catch (e2) {
          // Post not found in trending posts, try tag posts
          try {
            final existingPost = communityState.tagPosts.firstWhere(
              (post) => post.id == widget.postId,
            );
            setState(() {
              _post = existingPost;
              _isLoading = false;
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadComments();
            });
            return;
          } catch (e3) {
            // Post not found in any state
          }
        }
      }

      // If not found, we could implement a single post fetch API
      // For now, we'll show an error
      setState(() {
        _error = 'Post not found';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load post: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    if (_post == null || _commentsLoaded || !mounted) return;

    try {
      if (!mounted) return;
      setState(() {
        _isLoadingComments = true;
      });

      final socialService = ref.read(socialServiceStateProvider.notifier);

      // Force reload comments
      await socialService.loadComments(_post!.id,
          contentType: 'COMMUNITY_POST');

      // Wait for the state to update
      await Future.delayed(const Duration(milliseconds: 200));

      // Get comments from the social service state
      final socialState = ref.read(socialServiceStateProvider);
      final comments = socialState.comments[_post!.id] ?? [];

      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
        _commentsLoaded = true; // Mark as loaded
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingComments = false;
        _commentsLoaded = true; // Mark as loaded even on error
      });
    }
  }

  void _openImageViewer(String imageUrl) {
    // Check if it's a coin/VIP post
    if (_post!.cost > 0 || _post!.requiresVip) {
      _showPaymentDialog();
      return;
    }

    // Combine all media (images and videos)
    final List<MediaItem> allMedia = [];

    // Add images
    for (var img in _post!.imageUrls) {
      allMedia.add(MediaItem(url: img, isVideo: false));
    }

    // Add videos
    for (var video in _post!.videoUrls) {
      allMedia.add(MediaItem(url: video, isVideo: true));
    }

    // Find the initial index of the clicked image
    final initialIndex = _post!.imageUrls.indexOf(imageUrl);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenMediaGallery(
          mediaItems: allMedia,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }

  void _openVideoPlayer(String videoUrl) {
    // Check if it's a coin/VIP post
    if (_post!.cost > 0 || _post!.requiresVip) {
      _showPaymentDialog();
      return;
    }

    // Combine all media (images and videos)
    final List<MediaItem> allMedia = [];

    // Add images
    for (var img in _post!.imageUrls) {
      allMedia.add(MediaItem(url: img, isVideo: false));
    }

    // Add videos
    for (var video in _post!.videoUrls) {
      allMedia.add(MediaItem(url: video, isVideo: true));
    }

    // Find the initial index of the clicked video
    final videoIndex = _post!.videoUrls.indexOf(videoUrl);
    final initialIndex = _post!.imageUrls.length + videoIndex;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenMediaGallery(
          mediaItems: allMedia,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    // Check if current user is the author of this post
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser != null && currentUser.id == _post!.userId) {
      print(
          '✅ User ${currentUser.username} is the author of post ${_post!.id}, opening media directly');
      _openMediaAfterPayment();
      return;
    }

    // Check if post is already unlocked (from database or memory)
    final isUnlockedInMemory =
        ref.read(unlockedPostsProvider.notifier).isPostUnlocked(_post!.id);
    if (_post!.isUnlocked || isUnlockedInMemory) {
      print('✅ Post ${_post!.id} is already unlocked, opening media directly');
      _openMediaAfterPayment();
      return;
    }

    if (_post!.requiresVip) {
      VipPaymentDialog.show(
        context,
        onPaymentSuccess: () {
          // After successful VIP payment, open the media
          _openMediaAfterPayment();
        },
        authorId: _post!.userId,
        authorName: _post!.firstName ?? _post!.username,
        authorAvatar: _post!.userAvatar,
      );
    } else {
      CoinPaymentDialog.show(
        context,
        coinCost: _post!.cost,
        postId: _post!.id,
        onPaymentSuccess: () {
          // After successful coin payment, open the media
          _openMediaAfterPayment();
        },
      );
    }
  }

  void _openMediaAfterPayment() {
    // Combine all media (images and videos)
    final List<MediaItem> allMedia = [];

    // Add images
    for (var img in _post!.imageUrls) {
      allMedia.add(MediaItem(url: img, isVideo: false));
    }

    // Add videos
    for (var video in _post!.videoUrls) {
      allMedia.add(MediaItem(url: video, isVideo: true));
    }

    if (allMedia.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullscreenMediaGallery(
            mediaItems: allMedia,
            initialIndex: 0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_post != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePost,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
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
              'Error',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadPost();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_post == null) {
      return const Center(
        child: Text('Post not found'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          _buildAuthorHeader(),

          // Main content section (text, images, videos)
          _buildMainContentSection(),

          // Engagement metrics
          _buildEngagementMetrics(),

          // Comments section
          _buildCommentsSection(),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader() {
    final authState = ref.watch(authServiceProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Author avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: _post!.userAvatar.isNotEmpty
                ? NetworkImage(_post!.userAvatar)
                : null,
            child: _post!.userAvatar.isEmpty
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
          const SizedBox(width: 12),

          // Author info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_post!.firstName} ${_post!.lastName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (_post!.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _post!.formattedTime,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Follow button (if not own post)
          if (authState.currentUser?.id != _post!.userId)
            Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton(
                onPressed: () => _toggleFollow(),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  _post!.isFollowing ? 'Following' : '+ Follow',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContentSection() {
    // Debug logging
    print('🎯 Post Detail: Building main content section');
    print('   Cost: ${_post!.cost}, VIP: ${_post!.requiresVip}');
    print(
        '   Will use ${(_post!.cost > 0 || _post!.requiresVip) ? 'grid' : 'line-by-line'} layout');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post text content
          if (_post!.content.isNotEmpty) ...[
            Text(
              _post!.content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Media content - use PostContentWidget for coin/VIP posts (same as Posts tab), line-by-line for others
          if (_post!.cost > 0 || _post!.requiresVip) ...[
            PostContentWidget(post: _post!),
          ] else ...[
            // Images - one by one
            if (_post!.imageUrls.isNotEmpty) ...[
              ..._post!.imageUrls.map((imageUrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildImageItem(imageUrl),
                  )),
              const SizedBox(height: 16),
            ],

            // Videos - one by one
            if (_post!.videoUrls.isNotEmpty) ...[
              ..._post!.videoUrls.asMap().entries.map((entry) {
                final index = entry.key;
                final videoUrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildVideoItem(videoUrl, index),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildImageItem(String imageUrl) {
    return GestureDetector(
      onTap: () {
        // Open image viewer
        _openImageViewer(imageUrl);
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: NsfwBlurWrapper(
            isNsfw: _post!.isNsfw,
            child: CoinVipThumbnailWrapper(
              isCoinPost: _post!.cost > 0,
              isVipPost: _post!.requiresVip,
              coinCost: _post!.cost,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.error, size: 48, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoItem(String videoUrl, int index) {
    final hasThumbnail = index < _post!.videoThumbnailUrls.length;
    final thumbnailUrl = hasThumbnail ? _post!.videoThumbnailUrls[index] : null;
    final duration =
        index < _post!.duration.length ? _post!.duration[index] : null;

    return GestureDetector(
      onTap: () {
        // Open video player
        _openVideoPlayer(videoUrl);
      },
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: NsfwBlurWrapper(
          isNsfw: _post!.isNsfw,
          child: CoinVipThumbnailWrapper(
            isCoinPost: _post!.cost > 0,
            isVipPost: _post!.requiresVip,
            coinCost: _post!.cost,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video thumbnail or placeholder
                if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.play_circle_outline,
                              size: 48, color: Colors.white),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.play_circle_outline,
                          size: 48, color: Colors.white),
                    ),
                  ),

                // Play button overlay
                Center(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Duration overlay (bottom right)
                if (duration != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementMetrics() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricButton(
            icon: _post!.isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatCount(_post!.likes),
            color: _post!.isLiked ? Colors.red : Colors.grey[600],
            onTap: _toggleLike,
          ),
          _buildMetricButton(
            icon: Icons.comment_outlined,
            label: _formatCount(_post!.comments),
            onTap: () {
              // Comments section is below
            },
          ),
          _buildMetricButton(
            icon: Icons.share_outlined,
            label: _formatCount(_post!.shares),
            onTap: _sharePost,
          ),
          _buildMetricButton(
            icon: Icons.visibility_outlined,
            label: _formatCount(_post!.views),
            onTap: () {
              // Views are automatically tracked
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: color ?? Colors.grey[600],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final authState = ref.watch(authServiceProvider);
    final socialState = ref.watch(socialServiceStateProvider);

    // Force load comments if not loaded yet
    if (_post != null && _comments.isEmpty && !_isLoadingComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadComments();
      });
    }

    // Update local comments when social state changes
    if (_post != null && socialState.comments.containsKey(_post!.id)) {
      final updatedComments = socialState.comments[_post!.id] ?? [];
      if (updatedComments.length != _comments.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _comments = updatedComments;
          });
        });
      }
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comments header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Comments (${_post!.comments})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.close,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),

          // Real comments display
          if (authState.currentUser != null) ...[
            // Loading indicator for comments
            if (_isLoadingComments)
              Container(
                padding: const EdgeInsets.all(32),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_comments.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No comments yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              // Display real comments
              ..._comments.map((comment) => _buildRealCommentItem(comment)),

            // Add comment input
            _buildCommentInput(),
          ] else
            Container(
              height: 100,
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Please sign in to view comments',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final authState = ref.watch(authServiceProvider);
    final commentController = TextEditingController();

    void _submitComment() {
      final text = commentController.text.trim();
      if (text.isNotEmpty) {
        commentController.clear();
        _addComment(text);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            backgroundImage: authState.currentUser?.avatarUrl != null &&
                    authState.currentUser!.avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(authState.currentUser!.avatarUrl!)
                : null,
            child: authState.currentUser?.avatarUrl == null ||
                    authState.currentUser!.avatarUrl!.isEmpty
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _submitComment,
            icon: const Icon(Icons.send, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildRealCommentItem(CommentModel comment) {
    final authState = ref.watch(authServiceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: comment.userAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(comment.userAvatar)
                      : null,
                  child: comment.userAvatar.isEmpty
                      ? const Icon(Icons.person, size: 16)
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
                            comment.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            comment.formattedTime,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleCommentLike(comment),
                            child: Row(
                              children: [
                                Icon(
                                  comment.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color: comment.isLiked
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  comment.likes.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: comment.isLiked
                                        ? Colors.red
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _showReplyDialog(comment),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (authState.currentUser?.id == comment.userId)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditCommentDialog(comment);
                      } else if (value == 'delete') {
                        _showDeleteCommentDialog(comment);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    child: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),

          // Replies
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 44), // Indent replies
              child: Column(
                children: comment.replies
                    .map((reply) => _buildRealCommentItem(reply))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addComment(String content) async {
    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);
      final authState = ref.read(authServiceProvider);

      await socialService.addComment(
        videoId: _post!.id,
        userId: authState.currentUser!.id,
        username: authState.currentUser!.username,
        userAvatar: authState.currentUser!.avatarUrl ?? '',
        content: content,
        contentType: 'COMMUNITY_POST',
      );

      // Wait for the comment to be added, then reload
      await Future.delayed(const Duration(milliseconds: 300));

      // Reset the flag and reload comments
      setState(() {
        _commentsLoaded = false;
        _post = _post!.copyWith(comments: _post!.comments + 1);
      });

      _loadComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  void _toggleCommentLike(CommentModel comment) async {
    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);
      await socialService.toggleCommentLike(comment.id, _post!.id);

      // Reload comments to show updated like status
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like comment: $e')),
      );
    }
  }

  void _showEditCommentDialog(CommentModel comment) {
    final editController = TextEditingController(text: comment.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                Navigator.pop(context);

                try {
                  final socialService =
                      ref.read(socialServiceStateProvider.notifier);
                  await socialService.editComment(
                      comment.id, _post!.id, editController.text.trim());

                  // Reload comments to show updated comment
                  setState(() {
                    _commentsLoaded = false;
                  });
                  _loadComments();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Comment updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to edit comment: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(CommentModel comment) {
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${comment.username}'),
        content: TextField(
          controller: replyController,
          decoration: const InputDecoration(
            hintText: 'Write your reply...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isNotEmpty) {
                Navigator.pop(context);

                try {
                  final socialService =
                      ref.read(socialServiceStateProvider.notifier);
                  final authState = ref.read(authServiceProvider);

                  await socialService.addComment(
                    videoId: _post!.id,
                    userId: authState.currentUser!.id,
                    username: authState.currentUser!.username,
                    userAvatar: authState.currentUser!.avatarUrl ?? '',
                    content: replyController.text.trim(),
                    parentCommentId: comment.id,
                    contentType: 'COMMUNITY_POST',
                  );

                  // Reload comments to show the new reply
                  setState(() {
                    _commentsLoaded = false;
                  });
                  _loadComments();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add reply: $e')),
                  );
                }
              }
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCommentDialog(CommentModel comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text(
            'Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final socialService =
                    ref.read(socialServiceStateProvider.notifier);
                await socialService.deleteComment(comment.id, _post!.id);

                // Update post comment count and reset flag
                setState(() {
                  _post = _post!.copyWith(comments: _post!.comments - 1);
                  _commentsLoaded = false;
                });

                // Reload comments to show updated list
                _loadComments();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete comment: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _toggleLike() async {
    try {
      await ref
          .read(communityServiceStateProvider.notifier)
          .likePost(_post!.id);

      // Update local state
      setState(() {
        _post = _post!.copyWith(
          isLiked: !_post!.isLiked,
          likes: _post!.isLiked ? _post!.likes - 1 : _post!.likes + 1,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like post: $e')),
        );
      }
    }
  }

  void _toggleFollow() async {
    try {
      await ref
          .read(communityServiceStateProvider.notifier)
          .followUser(_post!.userId);

      // Update local state
      setState(() {
        _post = _post!.copyWith(
          isFollowing: !_post!.isFollowing,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to follow user: $e')),
        );
      }
    }
  }

  void _sharePost() {
    // Create share URL
    final shareUrl = 'bluevideoapp://post/${_post!.id}';

    // Show share dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this post with others:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                shareUrl,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Copy this link to share the post. When users click on it, they will be taken to this post.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }
}
