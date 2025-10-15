import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_post.dart';
import 'nsfw_blur_wrapper.dart';
import 'coin_vip_indicator.dart';

class VideoCardWidget extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onTap;

  const VideoCardWidget({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    print('🎬 VideoCardWidget building for post: ${post.id}');
    print('   💰 Cost: ${post.cost}, VIP: ${post.requiresVip}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video thumbnail with play button overlay
            _buildVideoThumbnail(),

            // Content section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  _buildUserInfo(),
                  const SizedBox(height: 8),

                  // Post content
                  if (post.content.isNotEmpty) ...[
                    Text(
                      post.content,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Tags
                  if (post.tags.isNotEmpty) _buildTags(),

                  const SizedBox(height: 8),

                  // Engagement stats
                  _buildEngagementStats(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    final thumbnailUrl = post.videoThumbnailUrls.isNotEmpty
        ? post.videoThumbnailUrls.first
        : null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: NsfwBlurWrapper(
        isNsfw: post.isNsfw,
        child: CoinVipThumbnailWrapper(
          isCoinPost: post.cost > 0,
          isVipPost: post.requiresVip,
          coinCost: post.cost,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail background
              if (thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.video_library,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.video_library,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                ),

              // Play button overlay
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),

              // Duration badge
              if (post.duration.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(post.duration.first),
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
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          backgroundImage: post.userAvatar.isNotEmpty
              ? CachedNetworkImageProvider(post.userAvatar)
              : null,
          child: post.userAvatar.isEmpty
              ? const Icon(Icons.person, size: 16)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (post.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ],
                  if (post.isPinned) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
              Text(
                _formatTime(post.createdAt),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: post.tags.take(3).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEngagementStats() {
    return Row(
      children: [
        _buildStatItem(Icons.visibility, _formatCount(post.views)),
        const SizedBox(width: 16),
        _buildStatItem(Icons.favorite, _formatCount(post.likes)),
        const SizedBox(width: 16),
        _buildStatItem(Icons.comment, _formatCount(post.comments)),
        const SizedBox(width: 16),
        _buildStatItem(Icons.share, _formatCount(post.shares)),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  String _formatDuration(String duration) {
    try {
      final seconds = int.parse(duration);
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;

      if (minutes > 0) {
        return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
      } else {
        return '0:${remainingSeconds.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return duration;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
