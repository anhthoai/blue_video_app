import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/community_post.dart';
import '../../screens/community/_fullscreen_media_gallery.dart';
import 'nsfw_blur_wrapper.dart';
import 'coin_vip_indicator.dart';
import '../dialogs/coin_payment_dialog.dart';
import '../../core/providers/unlocked_posts_provider.dart';
import '../../core/services/auth_service.dart';

class PostContentWidget extends ConsumerWidget {
  final CommunityPost post;

  const PostContentWidget({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🎯 PostContentWidget building for post: ${post.id}');
    print('   Type: ${post.type}');
    print('   Image URLs: ${post.imageUrls.length}');
    print('   Video URLs: ${post.videoUrls.length}');
    print('   Duration: ${post.duration}');
    print('   💰 Cost: ${post.cost}, VIP: ${post.requiresVip}');
    if (post.cost > 0 || post.requiresVip) {
      print('   🚨 THIS IS A COIN/VIP POST!');
    }

    try {
      switch (post.type) {
        case PostType.media:
          return _buildMediaContent(context, ref);
        case PostType.link:
          return _buildLinkContent();
        case PostType.poll:
          return _buildPollContent();
        case PostType.text:
          return const SizedBox.shrink();
      }
    } catch (e, stackTrace) {
      print('❌ Error in PostContentWidget.build: $e');
      print('Stack trace: $stackTrace');
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading post content: $e'),
      );
    }
  }

  Widget _buildMediaContent(BuildContext context, WidgetRef ref) {
    print('🎬 Building media content...');
    print('   Images: ${post.imageUrls.length}');
    print('   Videos: ${post.videoUrls.length}');

    try {
      if (post.imageUrls.isEmpty && post.videoUrls.isEmpty) {
        print('   No media content to display');
        return const SizedBox.shrink();
      }

      // Combine all media items
      final allMedia = <Map<String, dynamic>>[];

      // Add images
      for (int i = 0; i < post.imageUrls.length; i++) {
        print('   Adding image $i: ${post.imageUrls[i]}');
        allMedia.add({
          'type': 'image',
          'url': post.imageUrls[i],
          'index': i,
        });
      }

      // Add videos
      for (int i = 0; i < post.videoUrls.length; i++) {
        print('   Adding video $i: ${post.videoUrls[i]}');
        allMedia.add({
          'type': 'video',
          'url': post.videoUrls[i],
          'videoIndex': i, // Video index for duration lookup
        });
      }

      if (allMedia.isEmpty) return const SizedBox.shrink();

      return _buildMediaGrid(context, ref, allMedia);
    } catch (e, stackTrace) {
      print('❌ Error in _buildMediaContent: $e');
      print('Stack trace: $stackTrace');
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading media content: $e'),
      );
    }
  }

  Widget _buildMediaGrid(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> allMedia) {
    if (allMedia.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        // Check if it's a coin/VIP post
        if (post.cost > 0 || post.requiresVip) {
          _showPaymentDialog(context, ref);
        } else {
          _showFullscreenMediaViewer(context, allMedia);
        }
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildMediaLayout(context, allMedia),
        ),
      ),
    );
  }

  Widget _buildMediaLayout(
      BuildContext context, List<Map<String, dynamic>> allMedia) {
    if (allMedia.length == 1) {
      return _buildSingleMedia(context, allMedia.first);
    } else if (allMedia.length == 2) {
      return _buildTwoMedia(context, allMedia);
    } else {
      return _buildImprovedMultipleMedia(context, allMedia);
    }
  }

  Widget _buildSingleMedia(BuildContext context, Map<String, dynamic> media) {
    if (media['type'] == 'image') {
      return NsfwBlurWrapper(
        isNsfw: post.isNsfw,
        child: CoinVipThumbnailWrapper(
          isCoinPost: post.cost > 0,
          isVipPost: post.requiresVip,
          coinCost: post.cost,
          child: CachedNetworkImage(
            imageUrl: media['url'],
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.error)),
            ),
          ),
        ),
      );
    } else {
      // For videos, show thumbnail with play icon and duration
      final videoIndex = media['videoIndex'] ?? 0;
      final videoUrl = post.videoUrls[videoIndex];

      // Use the thumbnail URL from the API response
      final thumbnailUrl = videoIndex < post.videoThumbnailUrls.length
          ? post.videoThumbnailUrls[videoIndex]
          : videoUrl.replaceAll(
              RegExp(r'\.mp4'), '.jpg'); // Fallback to URL construction

      final durationStr =
          videoIndex < post.duration.length ? post.duration[videoIndex] : '0';
      final duration = int.tryParse(durationStr) ?? 0;

      // Debug logging
      print('🎬 Video display debug:');
      print('   Video URL: $videoUrl');
      print('   Thumbnail URL: $thumbnailUrl');
      print('   Duration: $durationStr -> $duration');
      print('   Video index: $videoIndex');

      return NsfwBlurWrapper(
        isNsfw: post.isNsfw,
        child: CoinVipThumbnailWrapper(
          isCoinPost: post.cost > 0,
          isVipPost: post.requiresVip,
          coinCost: post.cost,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video thumbnail
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) {
                  print('❌ Failed to load thumbnail: $url');
                  print('   Error: $error');
                  return Container(
                    color: Colors.grey[400],
                    child: const Center(
                      child: Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
              // Play icon overlay
              const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white, size: 48),
              ),
              // Duration overlay
              if (duration > 0)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTwoMedia(
      BuildContext context, List<Map<String, dynamic>> allMedia) {
    return Row(
      children: [
        Expanded(
          child: _buildMediaItem(context, allMedia[0]),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: _buildMediaItem(context, allMedia[1]),
        ),
      ],
    );
  }

  Widget _buildMediaItem(BuildContext context, Map<String, dynamic> media) {
    if (media['type'] == 'image') {
      return NsfwBlurWrapper(
        isNsfw: post.isNsfw,
        child: CoinVipThumbnailWrapper(
          isCoinPost: post.cost > 0,
          isVipPost: post.requiresVip,
          coinCost: post.cost,
          child: CachedNetworkImage(
            imageUrl: media['url'],
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.error)),
            ),
          ),
        ),
      );
    } else {
      // For videos, show thumbnail with play icon and duration
      final videoIndex = media['videoIndex'] ?? 0;
      final videoUrl = post.videoUrls[videoIndex];

      // Use the thumbnail URL from the API response
      final thumbnailUrl = videoIndex < post.videoThumbnailUrls.length
          ? post.videoThumbnailUrls[videoIndex]
          : videoUrl.replaceAll(
              RegExp(r'\.mp4'), '.jpg'); // Fallback to URL construction

      final durationStr =
          videoIndex < post.duration.length ? post.duration[videoIndex] : '0';
      final duration = int.tryParse(durationStr) ?? 0;

      return NsfwBlurWrapper(
        isNsfw: post.isNsfw,
        child: CoinVipThumbnailWrapper(
          isCoinPost: post.cost > 0,
          isVipPost: post.requiresVip,
          coinCost: post.cost,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video thumbnail
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) {
                  print('❌ Failed to load thumbnail: $url');
                  print('   Error: $error');
                  return Container(
                    color: Colors.grey[400],
                    child: const Center(
                      child: Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
              // Play icon overlay
              const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white, size: 32),
              ),
              // Duration overlay
              if (duration > 0)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildImprovedMultipleMedia(
      BuildContext context, List<Map<String, dynamic>> allMedia) {
    // Separate images and videos
    final images = allMedia.where((media) => media['type'] == 'image').toList();
    final videos = allMedia.where((media) => media['type'] == 'video').toList();

    if (images.isNotEmpty) {
      // First image goes to left (2/3 width)
      final firstImage = images.first;
      final remainingImages = images.skip(1).toList();

      // Plan what goes in the right column (2 slots available)
      final rightColumnItems = <Map<String, dynamic>>[];
      int remainingImageCount = 0;

      // Priority 1: Show remaining images first (at top)
      if (remainingImages.isNotEmpty) {
        rightColumnItems.add(remainingImages.first);
        remainingImageCount = remainingImages.length - 1;

        // Priority 2: Show video at bottom if videos exist
        if (videos.isNotEmpty && rightColumnItems.length < 2) {
          rightColumnItems.add(videos.first);
        }
      } else {
        // No remaining images, show video at top
        if (videos.isNotEmpty) {
          rightColumnItems.add(videos.first);
        }
      }

      return Row(
        children: [
          // First image - 2/3 width
          Expanded(
            flex: 4, // 2/3 of 6 = 4
            child: _buildMediaItem(context, firstImage),
          ),

          // Right side - 1/3 width for remaining items
          Expanded(
            flex: 2, // 1/3 of 6 = 2
            child: Column(
              children: [
                // Top item (with overflow indicator for remaining images)
                if (rightColumnItems.isNotEmpty)
                  Expanded(
                    child: _buildMediaItemWithOverflow(
                        context,
                        rightColumnItems[0],
                        remainingImageCount > 0 ? remainingImageCount : null),
                  ),

                // Bottom item (video, no overflow)
                if (rightColumnItems.length > 1)
                  Expanded(
                    child: _buildMediaItem(context, rightColumnItems[1]),
                  ),
              ],
            ),
          ),
        ],
      );
    } else {
      // No images, only videos - show first video in 2/3, others in 1/3
      if (videos.isNotEmpty) {
        final firstVideo = videos.first;
        final remainingVideos = videos.skip(1).toList();

        return Row(
          children: [
            // First video - 2/3 width
            Expanded(
              flex: 4,
              child: _buildMediaItem(context, firstVideo),
            ),

            // Right side - 1/3 width for remaining videos
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  if (remainingVideos.isNotEmpty)
                    Expanded(
                      child: _buildMediaItemWithOverflow(
                          context,
                          remainingVideos[0],
                          remainingVideos.length > 1
                              ? remainingVideos.length - 1
                              : null),
                    ),
                ],
              ),
            ),
          ],
        );
      }
    }

    // Fallback
    return _buildMediaItem(context, allMedia.first);
  }

  Widget _buildMediaItemWithOverflow(
      BuildContext context, Map<String, dynamic> media, int? overflowCount) {
    if (overflowCount != null && overflowCount > 0) {
      // Show the media item with overflow text overlaid on top
      return Stack(
        fit: StackFit.expand,
        children: [
          // The actual media item (image/video) as background
          _buildMediaItem(context, media),
          // The overflow text overlaid on top
          _buildOverflowItem(context, overflowCount),
        ],
      );
    }
    return _buildMediaItem(context, media);
  }

  Widget _buildOverflowItem(BuildContext context, int remainingCount) {
    return Center(
      child: Text(
        '+$remainingCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black,
              offset: Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }

  // Unused method removed to fix compilation errors

  // Unused method removed to fix compilation errors

  Widget _buildLinkContent() {
    if (post.linkUrl == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.linkThumbnail != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: CachedNetworkImage(
                imageUrl: post.linkThumbnail!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.error),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.linkTitle != null)
                  Text(
                    post.linkTitle!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (post.linkDescription != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    post.linkDescription!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  post.linkUrl!,
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollContent() {
    if (post.pollData == null) return const SizedBox.shrink();

    final pollData = post.pollData!;
    final options = pollData['options'] as List<String>? ?? [];
    final votes = pollData['votes'] as Map<String, int>? ?? {};
    final totalVotes = votes.values.fold(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pollData['question'] as String? ?? 'Poll Question',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final voteCount = votes['option_$index'] ?? 0;
            final percentage =
                totalVotes > 0 ? (voteCount / totalVotes * 100) : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            '$totalVotes votes',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    // Check if current user is the author of this post
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser != null && currentUser.id == post.userId) {
      print(
          '✅ User ${currentUser.username} is the author of post ${post.id}, showing media directly');
      _showFullscreenMediaViewer(context, _getAllMedia());
      return;
    }

    // Check if post is already unlocked (from database or memory)
    final isUnlockedInMemory =
        ref.read(unlockedPostsProvider.notifier).isPostUnlocked(post.id);
    if (post.isUnlocked || isUnlockedInMemory) {
      print('✅ Post ${post.id} is already unlocked, showing media directly');
      _showFullscreenMediaViewer(context, _getAllMedia());
      return;
    }

    if (post.requiresVip) {
      VipPaymentDialog.show(
        context,
        onPaymentSuccess: () {
          // After successful VIP payment, show the media
          _showFullscreenMediaViewer(context, _getAllMedia());
        },
      );
    } else {
      CoinPaymentDialog.show(
        context,
        coinCost: post.cost,
        postId: post.id,
        onPaymentSuccess: () {
          // After successful coin payment, show the media
          _showFullscreenMediaViewer(context, _getAllMedia());
        },
      );
    }
  }

  List<Map<String, dynamic>> _getAllMedia() {
    final allMedia = <Map<String, dynamic>>[];

    // Add images
    for (int i = 0; i < post.imageUrls.length; i++) {
      allMedia.add({
        'type': 'image',
        'url': post.imageUrls[i],
        'index': i,
      });
    }

    // Add videos
    for (int i = 0; i < post.videoUrls.length; i++) {
      allMedia.add({
        'type': 'video',
        'url': post.videoUrls[i],
        'videoIndex': i,
        'index': i,
      });
    }

    return allMedia;
  }

  void _showFullscreenMediaViewer(
      BuildContext context, List<Map<String, dynamic>> allMedia) {
    if (allMedia.isEmpty) return;

    // Convert to MediaItem list
    final List<MediaItem> mediaItems = allMedia.map((media) {
      return MediaItem(
        url: media['url'] as String,
        isVideo: media['type'] == 'video',
      );
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenMediaGallery(
          mediaItems: mediaItems,
          initialIndex: 0,
        ),
      ),
    );
  }

  String _formatDuration(int durationSeconds) {
    final minutes = durationSeconds ~/ 60;
    final remainingSeconds = durationSeconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
