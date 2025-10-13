import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/community_service.dart';
import '../../models/community_post.dart';
import '../social/comments_section.dart';
import 'post_content_widget.dart';

class CommunityPostWidget extends ConsumerStatefulWidget {
  final CommunityPost post;
  final String? currentUserId;
  final String? currentUsername;
  final String? currentUserAvatar;
  final VoidCallback? onTap;
  final VoidCallback? onUserTap;

  const CommunityPostWidget({
    super.key,
    required this.post,
    this.currentUserId,
    this.currentUsername,
    this.currentUserAvatar,
    this.onTap,
    this.onUserTap,
  });

  @override
  ConsumerState<CommunityPostWidget> createState() =>
      _CommunityPostWidgetState();
}

class _CommunityPostWidgetState extends ConsumerState<CommunityPostWidget> {
  bool _isExpanded = false;
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _isBookmarked = widget.post.isBookmarked;

    // Track view when post is first displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackView();
    });
  }

  void _trackView() {
    // Increment view count
    ref
        .read(communityServiceStateProvider.notifier)
        .incrementViews(widget.post.id);
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
    });

    try {
      await ref
          .read(communityServiceStateProvider.notifier)
          .likePost(widget.post.id);
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like post: $e')),
      );
    }
  }

  void _toggleBookmark() async {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    try {
      await ref
          .read(communityServiceStateProvider.notifier)
          .bookmarkPost(widget.post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_isBookmarked ? 'Post bookmarked' : 'Post unbookmarked')),
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _isBookmarked = !_isBookmarked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to bookmark post: $e')),
      );
    }
  }

  void _toggleFollow() async {
    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      await ref
          .read(communityServiceStateProvider.notifier)
          .followUser(widget.post.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isFollowing
                ? 'Following ${widget.post.username}'
                : 'Unfollowed ${widget.post.username}')),
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _isFollowing = !_isFollowing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to follow user: $e')),
      );
    }
  }

  void _togglePin() async {
    try {
      await ref
          .read(communityServiceStateProvider.notifier)
          .pinPost(widget.post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(widget.post.isPinned ? 'Post unpinned' : 'Post pinned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pin post: $e')),
      );
    }
  }

  void _showReportDialog() {
    String selectedReason = 'spam';
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              value: selectedReason,
              items: const [
                DropdownMenuItem(value: 'spam', child: Text('Spam')),
                DropdownMenuItem(
                    value: 'inappropriate',
                    child: Text('Inappropriate Content')),
                DropdownMenuItem(
                    value: 'harassment', child: Text('Harassment')),
                DropdownMenuItem(
                    value: 'fake', child: Text('Fake Information')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                selectedReason = value ?? 'spam';
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              _reportPost(selectedReason, descriptionController.text);
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _reportPost(String reason, String description) async {
    try {
      await ref
          .read(communityServiceStateProvider.notifier)
          .reportPost(widget.post.id, reason, description);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post reported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report post: $e')),
      );
    }
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }

  void _onTagTap(String tag) {
    // Navigate to posts filtered by tag
    context.push('/main/tag/$tag');
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging
    print('Build - Current user ID: ${widget.currentUserId}');
    print('Build - Post user ID: ${widget.post.userId}');
    print(
        'Build - Should show follow: ${widget.currentUserId != null && widget.currentUserId != widget.post.userId}');
    print(
        'Build - Should show pin: ${widget.currentUserId != null && widget.currentUserId == widget.post.userId}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildContent(),
              const SizedBox(height: 12),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onUserTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: widget.post.userAvatar.isNotEmpty
                ? CachedNetworkImageProvider(widget.post.userAvatar)
                : null,
            child: widget.post.userAvatar.isEmpty
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${widget.post.firstName ?? ''} ${widget.post.lastName ?? ''}'
                            .trim()
                            .isNotEmpty
                        ? '${widget.post.firstName ?? ''} ${widget.post.lastName ?? ''}'
                            .trim()
                        : widget.post.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.post.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ],
                  if (widget.post.isPinned) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ],
                  if (widget.post.isFeatured) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Text(
                    widget.post.formattedTime,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (widget.post.category != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.post.category!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (widget.currentUserId != null &&
            widget.currentUserId != widget.post.userId)
          GestureDetector(
            onTap: _toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isFollowing
                    ? Colors.grey[300]
                    : Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).primaryColor),
              ),
              child: Text(
                _isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  color: _isFollowing ? Colors.grey[700] : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'bookmark':
                _toggleBookmark();
                break;
              case 'report':
                _showReportDialog();
                break;
              case 'pin':
                _togglePin();
                break;
              case 'share':
                _sharePost();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'bookmark',
              child: Row(
                children: [
                  Icon(
                    widget.post.isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.post.isBookmarked ? 'Unbookmark' : 'Bookmark'),
                ],
              ),
            ),
            if (widget.currentUserId != null &&
                widget.currentUserId == widget.post.userId)
              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(
                      widget.post.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.post.isPinned ? 'Unpin Post' : 'Pin Post'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 16),
                  SizedBox(width: 8),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Report', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.post.title?.isNotEmpty == true) ...[
          Text(
            widget.post.title!,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          widget.post.content,
          style: const TextStyle(fontSize: 14),
          maxLines: _isExpanded ? null : 3,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
        if (widget.post.content.length > 100) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'Show less' : 'Show more',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (widget.post.imageUrls.isNotEmpty ||
            widget.post.videos.isNotEmpty ||
            widget.post.videoUrl != null ||
            widget.post.linkUrl != null) ...[
          const SizedBox(height: 12),
          PostContentWidget(post: widget.post),
        ],
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.post.tags.map((tag) {
              return GestureDetector(
                onTap: () => _onTagTap(tag),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Flexible(
          child: _buildActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatCount(widget.post.likes),
            color: _isLiked ? Colors.red : null,
            onTap: _toggleLike,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: GestureDetector(
            onTap: () {
              if (widget.currentUserId != null &&
                  widget.currentUsername != null &&
                  widget.currentUserAvatar != null) {
                _showCommentsSection();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.comment_outlined, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(widget.post.comments),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: _buildActionButton(
            icon: Icons.share_outlined,
            label: _formatCount(widget.post.shares),
            onTap: _sharePost,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: _buildActionButton(
            icon: Icons.visibility_outlined,
            label: _formatCount(widget.post.views),
            onTap: () {
              // Views are automatically tracked when post is viewed
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color ?? Colors.grey[600],
            ),
            const SizedBox(width: 4),
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
      ),
    );
  }

  void _sharePost() {
    if (widget.currentUserId == null) return;

    // Create custom URL scheme for sharing
    final shareUrl = 'bluevideoapp://post/${widget.post.id}';

    // Use Flutter's share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share URL copied: $shareUrl'),
        duration: const Duration(seconds: 2),
      ),
    );

    // You can also implement actual sharing with share_plus package
    // Share.share(shareText, subject: widget.post.title ?? 'Community Post');
  }

  void _showCommentsSection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsSection(
        videoId: widget.post.id, // Using post ID as video ID for comments
        currentUserId: widget.currentUserId!,
        currentUsername: widget.currentUsername!,
        currentUserAvatar: widget.currentUserAvatar!,
      ),
    );
  }
}
