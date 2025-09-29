import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/community_service.dart';
import '../../models/community_post.dart';
import '../../models/like_model.dart';
import '../social/like_button.dart';
import '../social/share_button.dart';
import '../social/follow_button.dart';
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

  @override
  Widget build(BuildContext context) {
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
                    widget.post.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
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
          FollowButton(
            targetUserId: widget.post.userId,
            currentUserId: widget.currentUserId!,
            height: 28,
            borderRadius: 14,
          ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'bookmark':
                _toggleBookmark();
                break;
              case 'report':
                _showReportDialog();
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
                  Text(widget.post.isBookmarked
                      ? 'Remove Bookmark'
                      : 'Bookmark'),
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
        if (widget.post.title.isNotEmpty) ...[
          Text(
            widget.post.title,
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
        if (widget.post.images.isNotEmpty ||
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
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
        if (widget.currentUserId != null)
          LikeButton(
            targetId: widget.post.id,
            type: LikeType.video, // Using video type for posts
            userId: widget.currentUserId!,
            initialLikeCount: widget.post.likes,
            initialIsLiked: widget.post.isLiked,
            size: 20,
            showCount: true,
          )
        else
          _buildActionButton(
            icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
            label: widget.post.formattedLikes,
            color: widget.post.isLiked ? Colors.red : null,
            onTap: () {
              // Handle like
            },
          ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () {
            if (widget.currentUserId != null &&
                widget.currentUsername != null &&
                widget.currentUserAvatar != null) {
              _showCommentsSection();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.comment_outlined, size: 20),
              const SizedBox(width: 4),
              Text(widget.post.formattedComments),
            ],
          ),
        ),
        const SizedBox(width: 24),
        if (widget.currentUserId != null)
          ShareButton(
            contentId: widget.post.id,
            contentType: 'post',
            userId: widget.currentUserId!,
            shareCount: widget.post.shares,
            size: 20,
            showCount: true,
          )
        else
          _buildActionButton(
            icon: Icons.share_outlined,
            label: widget.post.formattedShares,
            onTap: _sharePost,
          ),
        const Spacer(),
        Row(
          children: [
            Icon(
              Icons.visibility,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              widget.post.formattedViews,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
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
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBookmark() {
    if (widget.currentUserId == null) return;

    if (widget.post.isBookmarked) {
      ref.read(communityServiceStateProvider.notifier).removeBookmark(
            widget.post.id,
            widget.currentUserId!,
          );
    } else {
      ref.read(communityServiceStateProvider.notifier).bookmarkPost(
            widget.post.id,
            widget.currentUserId!,
          );
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            ...['Spam', 'Inappropriate', 'Harassment', 'Violence', 'Other']
                .map((reason) {
              return ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(reason);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _reportPost(String reason) {
    if (widget.currentUserId == null) return;

    ref.read(communityServiceStateProvider.notifier).reportPost(
          postId: widget.post.id,
          userId: widget.currentUserId!,
          reason: reason,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post reported successfully')),
    );
  }

  void _sharePost() {
    if (widget.currentUserId == null) return;

    // Share functionality is handled by ShareButton
    print('Sharing post: ${widget.post.id}');
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
