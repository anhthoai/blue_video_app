import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  final Map<int, Player> _players = {};
  final Map<int, VideoController> _videoControllers = {};
  final Map<int, bool> _videoHasError = {};

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
    if (_players.containsKey(index)) return;
    if (!widget.mediaItems[index].isVideo) return;

    try {
      final player = Player();
      final controller = VideoController(player);
      _players[index] = player;
      _videoControllers[index] = controller;
      _videoHasError[index] = false;

      await player.open(
        Media(widget.mediaItems[index].url),
        play: index == _currentIndex,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoHasError[index] = true;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Pause all videos
    _players.forEach((key, player) {
      if (key != index) {
        player.pause();
      }
    });

    // If current item is a video, initialize and play it
    if (widget.mediaItems[index].isVideo) {
      if (!_players.containsKey(index)) {
        _initializeVideo(index);
      } else {
        _players[index]?.play();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _players.forEach((_, player) {
      player.dispose();
    });
    super.dispose();
  }

  Future<void> _enterFullscreenForIndex(int index) async {
    final player = _players[index];
    final width = player?.state.width ?? 0;
    final height = player?.state.height ?? 0;
    final aspectRatio = (width > 0 && height > 0) ? (width / height) : 16 / 9;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (aspectRatio >= 1.0) {
      await SystemChrome.setPreferredOrientations(
        [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    } else {
      await SystemChrome.setPreferredOrientations(
        [
          DeviceOrientation.portraitUp,
        ],
      );
    }
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.portraitUp,
      ],
    );
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
    final hasError = _videoHasError[index] == true;

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
              : controller != null
                  ? Video(
                      controller: controller,
                      onEnterFullscreen: () => _enterFullscreenForIndex(index),
                      onExitFullscreen: _exitFullscreen,
                      controls: AdaptiveVideoControls,
                    )
                  : const CircularProgressIndicator(color: Colors.white),
        ),
      ],
    );
  }
}
