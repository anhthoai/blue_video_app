import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

// Media item class to hold both images and videos
class MediaItem {
  final String url;
  final bool isVideo;

  const MediaItem({
    required this.url,
    required this.isVideo,
  });
}

// Fullscreen Media Gallery (Images and Videos mixed with swipe)
class FullscreenMediaGallery extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;

  const FullscreenMediaGallery({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<FullscreenMediaGallery> createState() => _FullscreenMediaGalleryState();
}

class _FullscreenMediaGalleryState extends State<FullscreenMediaGallery> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, bool> _videoInitialized = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Initialize first video if it's a video
    if (widget.mediaItems[_currentIndex].isVideo) {
      _initializeVideo(_currentIndex);
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (_videoControllers.containsKey(index)) return;
    if (!widget.mediaItems[index].isVideo) return;

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaItems[index].url),
      );
      _videoControllers[index] = controller;

      await controller.initialize();

      if (mounted) {
        setState(() {
          _videoInitialized[index] = true;
        });

        if (index == _currentIndex) {
          controller.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoInitialized[index] = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Pause all videos
    _videoControllers.forEach((key, controller) {
      if (key != index) {
        controller.pause();
      }
    });

    // If current item is a video, initialize and play it
    if (widget.mediaItems[index].isVideo) {
      if (!_videoControllers.containsKey(index)) {
        _initializeVideo(index);
      } else {
        _videoControllers[index]?.play();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoControllers.forEach((_, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.mediaItems.length,
            itemBuilder: (context, index) {
              final mediaItem = widget.mediaItems[index];
              if (mediaItem.isVideo) {
                return _buildVideoPage(index);
              } else {
                return _buildImagePage(index);
              }
            },
          ),

          // Back button (top-left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Page indicator (top-right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.mediaItems.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Media type indicator (top-center)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.mediaItems[_currentIndex].isVideo
                          ? Icons.videocam
                          : Icons.image,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.mediaItems[_currentIndex].isVideo
                          ? 'Video'
                          : 'Image',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePage(int index) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: widget.mediaItems[index].url,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.error, size: 48, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPage(int index) {
    final controller = _videoControllers[index];
    final isInitialized = _videoInitialized[index] == true;
    final hasError = _videoInitialized[index] == false;

    return Stack(
      children: [
        // Video player
        Center(
          child: hasError
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 48, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load video',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                )
              : isInitialized && controller != null
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
        ),

        // Video controls
        if (isInitialized && controller != null && !hasError)
          _buildVideoControls(controller),
      ],
    );
  }

  Widget _buildVideoControls(VideoPlayerController controller) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 12),
            // Control buttons
            Row(
              children: [
                // Play/Pause button
                IconButton(
                  icon: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      if (controller.value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                // Time display
                Text(
                  '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Fullscreen button
                IconButton(
                  icon: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    // Toggle fullscreen (landscape/portrait)
                    // This is a placeholder - you can implement actual fullscreen logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Video is already in fullscreen mode'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
