import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../core/services/video_service.dart';
import '../../core/services/api_service.dart';
import '../../models/video_model.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String _selectedQuality = '720p';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoService = ref.read(videoServiceProvider);
      final videoDetail =
          await ref.read(videoDetailProvider(widget.videoId).future);

      if (videoDetail != null) {
        _videoPlayerController =
            videoService.getVideoPlayerController(videoDetail.videoUrl);

        if (_videoPlayerController != null) {
          await _videoPlayerController!.initialize();

          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: true,
            looping: false,
            showOptions: true,
            showControlsOnInitialize: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: Theme.of(context).colorScheme.primary,
              handleColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.grey[300]!,
              bufferedColor: Colors.grey[200]!,
            ),
          );

          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video Player'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (quality) {
              setState(() {
                _selectedQuality = quality;
              });
              _changeVideoQuality(quality);
            },
            itemBuilder: (context) {
              return ['360p', '720p', '1080p'].map((quality) {
                return PopupMenuItem<String>(
                  value: quality,
                  child: Row(
                    children: [
                      Text(quality),
                      if (_selectedQuality == quality)
                        const Icon(Icons.check, color: Colors.blue),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _chewieController != null
              ? Chewie(controller: _chewieController!)
              : const Center(
                  child: Text(
                    'Error loading video',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
    );
  }

  void _changeVideoQuality(String quality) {
    // This would typically change the video URL based on quality
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Quality changed to $quality')),
    );
  }
}
