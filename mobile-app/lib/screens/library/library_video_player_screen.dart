import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../core/models/library_navigation.dart';
import '../../core/models/library_item_model.dart';
import '../../utils/subtitle_parser.dart';

class LibraryVideoPlayerScreen extends StatefulWidget {
  const LibraryVideoPlayerScreen({super.key, required this.args});

  final LibraryVideoPlayerArgs args;

  @override
  State<LibraryVideoPlayerScreen> createState() =>
      _LibraryVideoPlayerScreenState();
}

class _LibraryVideoPlayerScreenState extends State<LibraryVideoPlayerScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final HtmlUnescape _htmlUnescape = HtmlUnescape();
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _showControls = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isVideoInitialized = false;
  bool _isFullscreen = false;
  bool _isInitializing = false;
  bool _isMuted = false;
  bool _hasPlayedNext = false;

  int _currentIndex = 0;
  LibraryItemModel? _currentVideo;

  // Subtitle state
  LibraryItemModel? _selectedSubtitle;
  List<SubtitleItem>? _subtitleItems;
  String _currentSubtitleText = '';

  List<LibraryItemModel> get videos => widget.args.videos;
  List<LibraryItemModel> get subtitles => widget.args.subtitles;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _currentIndex =
        widget.args.initialIndex.clamp(0, videos.length - 1).toInt();
    // Auto-load will happen in build
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _videoController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _videoController?.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _onScroll() {
    // Auto-pause video when scrolling down
    if (_scrollController.offset > 50 && _isPlaying) {
      _videoController?.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _loadVideo(LibraryItemModel video) async {
    if (_isInitializing) return;

    print('🎬 Loading video: ${video.displayTitle}');

    setState(() {
      _isInitializing = true;
      _currentVideo = video;
      _currentIndex = videos.indexWhere((v) => v.id == video.id);
    });

    try {
      // Dispose previous controller
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }

      setState(() {
        _isVideoInitialized = false;
        _isPlaying = false;
      });

      final streamUrl = video.streamUrl ?? video.fileUrl;

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No stream URL available');
      }

      print('🔗 Stream URL: $streamUrl');

      // Initialize video player
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
      );

      // Add listener for position updates, subtitles, and auto-play next
      _videoController!.addListener(() {
        if (mounted && _videoController != null) {
          setState(() {
            _currentPosition = _videoController!.value.position;
            _totalDuration = _videoController!.value.duration;
          });

          // Update subtitle text based on current position
          _updateSubtitleText();

          // Check if video has finished and auto-play next
          if (!_hasPlayedNext &&
              _videoController!.value.position >=
                  _videoController!.value.duration &&
              _videoController!.value.duration.inSeconds > 0) {
            _hasPlayedNext = true;
            _playNextVideo();
          }
        }
      });

      await _videoController!.initialize();

      print('✅ Video player initialized successfully');

      setState(() {
        _isVideoInitialized = true;
        _isInitializing = false;
        _isPlaying = true;
        _totalDuration = _videoController!.value.duration;
        _hasPlayedNext = false;
      });

      _videoController!.play();

      // Auto-load English subtitle if available
      _autoLoadEnglishSubtitle(video);

      // Auto-hide controls
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    } catch (e) {
      print('❌ Error loading video: ${e.toString()}');

      setState(() {
        _isInitializing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _playNextVideo() {
    if (_currentIndex + 1 < videos.length) {
      final nextVideo = videos[_currentIndex + 1];
      print('▶️ Auto-playing next video: ${nextVideo.displayTitle}');
      _loadVideo(nextVideo);
    } else {
      print('✅ Reached end of video list');
      setState(() {
        _showControls = true;
      });
    }
  }

  void _updateSubtitleText() {
    if (_subtitleItems == null || _videoController == null) {
      return;
    }

    final position = _videoController!.value.position;
    final currentMillis = position.inMilliseconds;

    // Find subtitle for current time
    for (final item in _subtitleItems!) {
      if (currentMillis >= item.startTime && currentMillis <= item.endTime) {
        if (_currentSubtitleText != item.text) {
          setState(() {
            _currentSubtitleText = item.text;
          });
        }
        return;
      }
    }

    // No subtitle for current time
    if (_currentSubtitleText.isNotEmpty) {
      setState(() {
        _currentSubtitleText = '';
      });
    }
  }

  void _showSubtitleSelector() {
    if (subtitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitles available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Subtitle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Off option
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('Off'),
                    selected: _selectedSubtitle == null,
                    selectedColor: Colors.blue,
                    onTap: () {
                      setState(() {
                        _selectedSubtitle = null;
                        _subtitleItems = null;
                        _currentSubtitleText = '';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  // Subtitle options
                  Flexible(
                    child: ListView(
                      controller: scrollController,
                      shrinkWrap: true,
                      children: subtitles.map((sub) {
                        return ListTile(
                          leading: Text(
                            sub.flagEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(sub.languageLabel),
                          subtitle: Text(
                            sub.languageCode,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: _selectedSubtitle?.id == sub.id
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          selected: _selectedSubtitle?.id == sub.id,
                          selectedColor: Colors.blue,
                          onTap: () {
                            _loadSubtitle(sub);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadSubtitle(LibraryItemModel subtitle,
      {bool isDefault = false}) async {
    try {
      print('📝 Loading subtitle: ${subtitle.displayTitle}');

      final streamUrl = subtitle.streamUrl ?? subtitle.fileUrl;

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No stream URL available for subtitle');
      }

      print('🔗 Downloading subtitle from: $streamUrl');

      // Download subtitle file from stream URL
      final response = await http.get(Uri.parse(streamUrl));

      if (response.statusCode == 200) {
        print(
            '✅ Subtitle file downloaded (${response.bodyBytes.length} bytes)');

        final decodedContent =
            _decodeSubtitleContent(response.bodyBytes, response.headers);

        // Parse subtitle file
        final parser = SubtitleParser();
        final extension = subtitle.extension ??
            subtitle.filePath?.split('.').last ??
            subtitle.fileUrl?.split('.').last;
        final rawItems = parser.parse(decodedContent, extension);

        final sanitizedItems = rawItems
            .map<SubtitleItem?>((item) {
              final cleanText = _sanitizeSubtitleSegment(item.text);
              if (cleanText.isEmpty) {
                return null;
              }
              return SubtitleItem(
                startTime: item.startTime,
                endTime: item.endTime,
                text: cleanText,
              );
            })
            .whereType<SubtitleItem>()
            .toList();

        if (sanitizedItems.isEmpty) {
          throw Exception('Subtitle file has no readable dialogue');
        }

        setState(() {
          _selectedSubtitle = subtitle;
          _subtitleItems = sanitizedItems;
          _currentSubtitleText = '';
        });

        print('✅ Loaded ${sanitizedItems.length} subtitle items');

        if (mounted && !isDefault) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${subtitle.languageLabel} subtitle'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to download subtitle: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading subtitle: $e');

      if (mounted && !isDefault) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subtitle: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _autoLoadEnglishSubtitle(LibraryItemModel video) {
    if (subtitles.isEmpty) {
      print('   No subtitles available for auto-load');
      return;
    }

    // Get video filename without extension
    final videoName =
        _getBaseName(video.filePath ?? video.fileUrl ?? video.displayTitle);

    // Find matching English subtitle
    LibraryItemModel? englishSubtitle;

    // First try: exact filename match with English language
    for (final sub in subtitles) {
      final subName =
          _getBaseName(sub.filePath ?? sub.fileUrl ?? sub.displayTitle);

      if (subName.toLowerCase() == videoName.toLowerCase() &&
          sub.languageLabel.toLowerCase() == 'english') {
        englishSubtitle = sub;
        print('   ✓ Found exact match English subtitle: ${sub.displayTitle}');
        break;
      }
    }

    // Second try: any English subtitle (use the languageLabel getter)
    if (englishSubtitle == null) {
      for (final sub in subtitles) {
        if (sub.languageLabel.toLowerCase() == 'english') {
          englishSubtitle = sub;
          print('   ✓ Found English subtitle: ${sub.displayTitle}');
          break;
        }
      }
    }

    // Third try: check filename patterns directly as fallback
    if (englishSubtitle == null) {
      for (final sub in subtitles) {
        final subFullName =
            (sub.filePath ?? sub.fileUrl ?? sub.displayTitle).toLowerCase();
        final lang = sub.metadata['language']?.toString().toLowerCase();

        if (subFullName.contains('.eng.') ||
            subFullName.endsWith('.eng.srt') ||
            subFullName.endsWith('.eng.vtt') ||
            subFullName.contains('_eng.') ||
            subFullName.contains('.english.') ||
            lang == 'eng' ||
            lang == 'en') {
          englishSubtitle = sub;
          print('   ✓ Found English subtitle by pattern: ${sub.displayTitle}');
          break;
        }
      }
    }

    // Fallback: first subtitle
    if (englishSubtitle == null && subtitles.isNotEmpty) {
      englishSubtitle = subtitles.first;
      print(
          '   ⚠ No English found, using first subtitle: ${englishSubtitle.displayTitle}');
    }

    if (englishSubtitle != null) {
      print('   🌐 Auto-loading subtitle: ${englishSubtitle.languageLabel}');
      _loadSubtitle(englishSubtitle, isDefault: true);
    }
  }

  String _getBaseName(String path) {
    final fileName = path.split('/').last;
    final parts = fileName.split('.');
    if (parts.length > 1) {
      // Remove extension
      return parts.sublist(0, parts.length - 1).join('.');
    }
    return fileName;
  }

  String _decodeSubtitleContent(
    List<int> bytes,
    Map<String, String> headers,
  ) {
    final attempts = <Encoding>[
      utf8,
    ];

    final contentType = headers['content-type'] ?? headers['Content-Type'];
    if (contentType != null) {
      final match =
          RegExp(r'charset=([\w\-]+)', caseSensitive: false).firstMatch(
        contentType,
      );
      if (match != null) {
        final charsetName = match.group(1)!.toLowerCase();
        switch (charsetName) {
          case 'utf-8':
          case 'utf8':
            attempts.insert(0, utf8);
            break;
          case 'latin1':
          case 'iso-8859-1':
          case 'iso8859-1':
            attempts.add(latin1);
            break;
          case 'ascii':
            attempts.add(ascii);
            break;
        }
      }
    }

    // Always include common fallbacks
    if (!attempts.contains(latin1)) {
      attempts.add(latin1);
    }
    if (!attempts.contains(ascii)) {
      attempts.add(ascii);
    }

    for (final encoding in attempts) {
      try {
        return encoding.decode(bytes);
      } catch (_) {
        // Try next encoding
      }
    }

    // Fallback: attempt UTF-8 with malformed allowed, then direct char codes
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  String _sanitizeSubtitleSegment(String raw) {
    if (raw.isEmpty) return '';

    var sanitized = raw
        .replaceAll(RegExp(r'\r'), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Remove common formatting tags but preserve line breaks
    sanitized = sanitized.replaceAll(
      RegExp(r'</?(i|b|u|font|span|c|color)[^>]*>', caseSensitive: false),
      '',
    );

    sanitized = sanitized.replaceAll(RegExp(r'<[^>]+>'), '');
    sanitized = sanitized.replaceAll('&nbsp;', ' ');
    sanitized = _htmlUnescape.convert(sanitized);

    sanitized = sanitized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');

    return sanitized.trim();
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      if (_isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
        _showControls = true;
      } else {
        _videoController!.play();
        _isPlaying = true;
        _showControls = true;

        // Auto-hide controls
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isPlaying) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls && _isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-load video on first build (only once)
    if (!_isVideoInitialized &&
        !_isInitializing &&
        _currentVideo == null &&
        videos.isNotEmpty) {
      print('🎬 Auto-loading video...');
      final videoToLoad = videos[_currentIndex];
      print('   Loading: ${videoToLoad.displayTitle}');

      // Trigger load immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('   🚀 Calling _loadVideo...');
          _loadVideo(videoToLoad);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isFullscreen
          ? _buildVideoPlayer()
          : Column(
              children: [
                _buildVideoPlayer(),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentVideo != null) _buildVideoInfo(),
                          _buildVideosList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVideoPlayer() {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;
    final bool controlsVisible = _showControls && !_isInitializing;
    final bool subtitleActive =
        _isVideoInitialized && _currentSubtitleText.isNotEmpty;
    final double baseSubtitleBottom = _isFullscreen ? 20 : 16;
    final double controlOffset =
        controlsVisible ? (_isFullscreen ? 75 : 60) : 0;
    final double subtitleBottom = baseSubtitleBottom + controlOffset;

    return GestureDetector(
      onTap: _toggleControls,
      child: SizedBox(
        height: _isFullscreen
            ? screenSize.height
            : isLandscape
                ? screenSize.height
                : screenSize.width * 9 / 16,
        width: double.infinity,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Player or Thumbnail
              if (_isVideoInitialized && _videoController != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                )
              else if (_isInitializing)
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading video...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(
                  child: Icon(
                    Icons.movie,
                    size: 64,
                    color: Colors.white54,
                  ),
                ),

              // Controls overlay
              if (_showControls && !_isInitializing) ...[
                // Gradient background
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            if (_isFullscreen) {
                              _toggleFullscreen();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            widget.args.folderTitle ?? 'Video Player',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center play/pause
                if (_isVideoInitialized)
                  Positioned.fill(
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          size: 64,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                  ),

                // Bottom controls
                if (_isVideoInitialized && _videoController != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          VideoProgressIndicator(
                            _videoController!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.red,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 0),
                          ),

                          const SizedBox(height: 4),

                          // Time and controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: Icon(
                                      _isMuted
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isMuted = !_isMuted;
                                        _videoController
                                            ?.setVolume(_isMuted ? 0.0 : 1.0);
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: Icon(
                                      Icons.closed_caption,
                                      color: _selectedSubtitle != null
                                          ? Colors.yellow
                                          : Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: _showSubtitleSelector,
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: Icon(
                                      _isFullscreen
                                          ? Icons.fullscreen_exit
                                          : Icons.fullscreen,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: _toggleFullscreen,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              // Subtitle display overlay
              Positioned(
                left: 16,
                right: 16,
                bottom: subtitleBottom,
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeInOut,
                    opacity: subtitleActive ? 1.0 : 0.0,
                    child: subtitleActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currentSubtitleText,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: null,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 6,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentVideo?.displayTitle ?? 'Video',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVideosList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Videos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...videos.map((video) {
            final isCurrentVideo = video.id == _currentVideo?.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              color: isCurrentVideo ? Colors.red[50] : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isCurrentVideo
                    ? const BorderSide(color: Colors.red, width: 1.2)
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isCurrentVideo ? null : () => _loadVideo(video),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 90,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (video.thumbnailUrl != null)
                                Image.network(
                                  video.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.movie,
                                      color: Colors.grey),
                                )
                              else
                                const Icon(Icons.movie, color: Colors.grey),
                              if (isCurrentVideo)
                                Container(
                                  color: Colors.black26,
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.displayTitle,
                              style: TextStyle(
                                fontWeight: isCurrentVideo
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 13,
                                color: isCurrentVideo ? Colors.red : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (video.duration != null && video.duration! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatDuration(
                                      Duration(seconds: video.duration!)),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isCurrentVideo
                                        ? Colors.red[700]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
