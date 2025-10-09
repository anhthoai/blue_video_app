import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../models/community_post.dart';

class PostContentWidget extends StatelessWidget {
  final CommunityPost post;

  const PostContentWidget({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    switch (post.type) {
      case PostType.media:
        return _buildMediaContent(context);
      case PostType.link:
        return _buildLinkContent();
      case PostType.poll:
        return _buildPollContent();
      case PostType.text:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMediaContent(BuildContext context) {
    if (post.imageUrls.isEmpty && post.videoUrls.isEmpty)
      return const SizedBox.shrink();

    // Combine all media items
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
        'index': i,
      });
    }

    if (allMedia.isEmpty) return const SizedBox.shrink();

    return _buildMediaGrid(context, allMedia);
  }

  Widget _buildMediaGrid(
      BuildContext context, List<Map<String, dynamic>> allMedia) {
    if (allMedia.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        _showFullscreenMediaViewer(context, allMedia);
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
      return _buildMultipleMedia(context, allMedia);
    }
  }

  Widget _buildSingleMedia(BuildContext context, Map<String, dynamic> media) {
    if (media['type'] == 'image') {
      return CachedNetworkImage(
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
      );
    } else {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.play_circle_outline,
                  color: Colors.white, size: 48),
            ),
          ),
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
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
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

  Widget _buildMultipleMedia(
      BuildContext context, List<Map<String, dynamic>> allMedia) {
    return Column(
      children: [
        // First row - up to 2 items
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildMediaItem(context, allMedia[0]),
              ),
              if (allMedia.length > 1) ...[
                const SizedBox(width: 2),
                Expanded(
                  child: _buildMediaItem(context, allMedia[1]),
                ),
              ],
            ],
          ),
        ),
        if (allMedia.length > 2) ...[
          const SizedBox(height: 2),
          // Second row - remaining items
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildMediaItem(context, allMedia[2]),
                ),
                if (allMedia.length > 3) ...[
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildOverflowItem(context, allMedia.length - 3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMediaItem(BuildContext context, Map<String, dynamic> media) {
    if (media['type'] == 'image') {
      return CachedNetworkImage(
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
      );
    } else {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.play_circle_outline,
                  color: Colors.white, size: 24),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(media['index'] + 1) * 2}:${(media['index'] * 15) % 60}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildOverflowItem(BuildContext context, int remainingCount) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Text(
              '+$remainingCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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

  void _showFullscreenMediaViewer(
      BuildContext context, List<Map<String, dynamic>> allMedia) {
    if (allMedia.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenMediaViewer(
          allMedia: allMedia,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

class _FullscreenMediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> allMedia;

  const _FullscreenMediaViewer({required this.allMedia});

  @override
  State<_FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<_FullscreenMediaViewer> {
  late PageController _pageController;
  late ValueNotifier<int> _currentPage;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, ChewieController?> _chewieControllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _currentPage = ValueNotifier<int>(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPage.dispose();

    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller?.dispose();
    }
    for (var controller in _chewieControllers.values) {
      controller?.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView for swiping through media
            PageView.builder(
              controller: _pageController,
              itemCount: widget.allMedia.length,
              onPageChanged: (index) {
                _currentPage.value = index;
              },
              itemBuilder: (context, index) {
                final media = widget.allMedia[index];
                if (media['type'] == 'image') {
                  return _buildFullscreenImage(media['url']);
                } else {
                  return _buildFullscreenVideo(media['url'], index);
                }
              },
            ),
            // Close button with safe area
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Media counter (e.g., "2 / 5") with safe area
            if (widget.allMedia.length > 1)
              Positioned(
                top: 16,
                left: 16,
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentPage,
                  builder: (context, page, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${page + 1} / ${widget.allMedia.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenImage(String imageUrl) {
    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.error, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenVideo(String videoUrl, int index) {
    return FutureBuilder<VideoPlayerController?>(
      future: _getVideoController(videoUrl, index),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.error, color: Colors.white, size: 50),
              ),
            );
          }

          final videoController = snapshot.data;
          if (videoController == null) {
            return Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.error, color: Colors.white, size: 50),
              ),
            );
          }

          final chewieController = _getChewieController(videoController, index);

          return Container(
            constraints: const BoxConstraints.expand(),
            child: AspectRatio(
              aspectRatio: 16 / 9, // Standard video aspect ratio
              child: Chewie(controller: chewieController),
            ),
          );
        } else {
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
      },
    );
  }

  Future<VideoPlayerController?> _getVideoController(
      String videoUrl, int index) async {
    if (_videoControllers[index] != null) {
      return _videoControllers[index];
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      _videoControllers[index] = controller;
      return controller;
    } catch (e) {
      print('Error initializing video controller: $e');
      return null;
    }
  }

  ChewieController _getChewieController(
      VideoPlayerController videoController, int index) {
    if (_chewieControllers[index] != null) {
      return _chewieControllers[index]!;
    }

    final chewieController = ChewieController(
      videoPlayerController: videoController,
      autoPlay: true,
      looping: false,
      showControls: true,
      allowFullScreen: false, // Disable fullscreen to prevent layout issues
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.white,
        handleColor: Colors.white,
        backgroundColor: Colors.grey.withOpacity(0.3),
        bufferedColor: Colors.white.withOpacity(0.2),
      ),
      // Control styling for better layout
      allowPlaybackSpeedChanging: false,
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.error, color: Colors.white, size: 50),
          ),
        );
      },
      // Custom options for better control layout
      optionsTranslation: null, // Use default controls
      showOptions: false, // Disable options menu to prevent overlap
      customControls: null, // Use default material controls
    );

    _chewieControllers[index] = chewieController;
    return chewieController;
  }
}
