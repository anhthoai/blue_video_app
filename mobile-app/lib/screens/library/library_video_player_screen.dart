import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/library_navigation.dart';
import '../../core/models/library_item_model.dart';

class LibraryVideoPlayerScreen extends StatefulWidget {
  const LibraryVideoPlayerScreen({super.key, required this.args});

  final LibraryVideoPlayerArgs args;

  @override
  State<LibraryVideoPlayerScreen> createState() =>
      _LibraryVideoPlayerScreenState();
}

class _LibraryVideoPlayerScreenState extends State<LibraryVideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  int _currentIndex = 0;
  bool _isLoading = false;

  List<LibraryItemModel> get videos => widget.args.videos;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.args.initialIndex.clamp(0, videos.length - 1).toInt();
    _loadVideo(_currentIndex);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo(int index) async {
    final video = videos[index];
    final url = video.streamUrl ?? video.fileUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video "${video.displayTitle}" has no URL.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final previousController = _videoController;
    final previousChewie = _chewieController;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();

    final chewie = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
    );

    previousChewie?.dispose();
    await previousController?.dispose();

    if (!mounted) {
      chewie.dispose();
      controller.dispose();
      return;
    }

    setState(() {
      _videoController = controller;
      _chewieController = chewie;
      _currentIndex = index;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentVideo = videos[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentVideo.displayTitle),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
            child: _isLoading || _chewieController == null
                ? const Center(child: CircularProgressIndicator())
                : Chewie(controller: _chewieController!),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final isActive = index == _currentIndex;
                return ListTile(
                  leading: Icon(
                    Icons.play_circle_fill,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    video.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: video.mimeType != null
                      ? Text(video.mimeType!)
                      : null,
                  selected: isActive,
                  onTap: () {
                    if (index != _currentIndex) {
                      _loadVideo(index);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

