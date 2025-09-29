import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/video_model.dart';

class VideoCard extends StatelessWidget {
  final String videoId;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onComment;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  const VideoCard({
    super.key,
    required this.videoId,
    this.onTap,
    this.onLike,
    this.onShare,
    this.onComment,
    this.isLiked = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            _buildVideoThumbnail(context),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Sample Video Title',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // User Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[300],
                        child: const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Username'),
                      const Spacer(),
                      Text(
                        '2h ago',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      _buildActionButton(
                        context,
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        label: _formatCount(likeCount),
                        onTap: onLike,
                        color: isLiked ? Colors.red : null,
                      ),
                      const SizedBox(width: 24),
                      _buildActionButton(
                        context,
                        icon: Icons.comment_outlined,
                        label: _formatCount(commentCount),
                        onTap: onComment,
                      ),
                      const SizedBox(width: 24),
                      _buildActionButton(
                        context,
                        icon: Icons.share_outlined,
                        label: _formatCount(shareCount),
                        onTap: onShare,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          _showMoreOptions(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // Thumbnail Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: 'https://picsum.photos/400/225?random=$videoId',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.video_library,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
            ),
          ),

          // Play Button Overlay
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // Duration Badge
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '2:30',
                style: TextStyle(
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

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
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

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text('Save'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle save
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Download'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle download
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle report
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle share
                  },
                ),
              ],
            ),
          ),
    );
  }
}
