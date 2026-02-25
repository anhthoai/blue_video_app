import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/models/library_navigation.dart';
import '../../core/models/library_item_model.dart';
import '../../utils/subtitle_parser.dart';
import '../../utils/language_labels.dart' as lang;

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
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<PlayerLog>? _logSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  bool _isPlaying = false;
  bool _showControls = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isVideoInitialized = false;
  bool _isFullscreen = false;
  bool _isInitializing = false;
  bool _isMuted = false;
  bool _hasPlayedNext = false;

  String? _currentStreamUrl;

  int _currentIndex = 0;
  LibraryItemModel? _currentVideo;

  // Subtitle state
  LibraryItemModel? _selectedSubtitle;
  List<SubtitleItem>? _subtitleItems;
  String _currentSubtitleText = '';

  void _ensurePlayerInitialized() {
    if (_player != null && _videoController != null) return;
    _player ??= Player();
    _videoController ??= VideoController(
      _player!,
      configuration: const VideoControllerConfiguration(
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    _attachPlayerListeners();
  }

  void _disposePlayerInternal() {
    _positionSub?.cancel();
    _positionSub = null;
    _durationSub?.cancel();
    _durationSub = null;
    _playingSub?.cancel();
    _playingSub = null;
    _completedSub?.cancel();
    _completedSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _logSub?.cancel();
    _logSub = null;
    _bufferingSub?.cancel();
    _bufferingSub = null;
    _videoParamsSub?.cancel();
    _videoParamsSub = null;

    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      unawaited(player.dispose());
    }
  }

  Future<void> _openWithFallback(String streamUrl) async {
    _ensurePlayerInitialized();

    // mpv (Android):
    // - media_kit defaults `network-timeout=5` which is often too aggressive for CDN/worker URLs.
    // - disk cache may fail on some devices/scoped storage configurations.
    // Tune networking & cache to improve reliability.
    try {
      final platform = _player?.platform;
      // Keep memory cache (helps with flaky networks) but disable disk cache.
      await (platform as dynamic).setProperty('cache', 'yes');
      await (platform as dynamic).setProperty('cache-on-disk', 'no');

      // Increase timeouts & enable reconnect for intermittent networks.
      await (platform as dynamic).setProperty('network-timeout', '30');

      final existing = await (platform as dynamic).getProperty('demuxer-lavf-o');
      final extra = [
        'reconnect=1',
        'reconnect_streamed=1',
        'reconnect_on_network_error=1',
        'reconnect_delay_max=5',
      ].join(',');
      final combined = (existing is String && existing.isNotEmpty)
          ? '$existing,$extra'
          : extra;
      await (platform as dynamic).setProperty('demuxer-lavf-o', combined);
    } catch (_) {}

    // Match media_kit_test behavior: open the direct URL without custom
    // headers / UA / referrer overrides or special retry logic.
    await _player!.open(Media(streamUrl), play: true);
    await _player!.setVolume(_isMuted ? 0 : 200);
  }

  Future<void> _showTracksSheet([BuildContext? sheetContext]) async {
    final player = _player;
    if (player == null) return;

    final ctx = sheetContext ?? context;

    final tracks = player.state.tracks;
    final currentAudio = player.state.track.audio;
    final currentSubtitle = player.state.track.subtitle;

    List<AudioTrack> _dedupeAudio(Iterable<AudioTrack> list) {
      final seen = <String>{};
      final out = <AudioTrack>[];
      for (final t in list) {
        final id = lang.trackId(t.id);
        if (!seen.add(id)) continue;
        out.add(t);
      }
      return out;
    }

    List<SubtitleTrack> _dedupeSubtitle(Iterable<SubtitleTrack> list) {
      final seen = <String>{};
      final out = <SubtitleTrack>[];
      for (final t in list) {
        final id = lang.trackId(t.id);
        if (!seen.add(id)) continue;
        out.add(t);
      }
      return out;
    }

    final audioTracks = _dedupeAudio(
      <AudioTrack>[AudioTrack.auto(), AudioTrack.no(), ...tracks.audio],
    );
    final subtitleTracks = _dedupeSubtitle(
      <SubtitleTrack>[
        SubtitleTrack.auto(),
        SubtitleTrack.no(),
        ...tracks.subtitle,
      ],
    );

    await showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 8),
                const ListTile(
                  title: Text('Tracks'),
                  subtitle: Text('Select audio & subtitle tracks'),
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'Audio',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ...audioTracks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final t = entry.value;
                  final selected =
                      lang.trackId(currentAudio.id) == lang.trackId(t.id);
                  return ListTile(
                    title: Text(lang.audioTrackLabel(t, index: idx)),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () async {
                      await player.setAudioTrack(t);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  );
                }),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'Subtitles',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ...subtitleTracks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final t = entry.value;
                  final selected =
                      lang.trackId(currentSubtitle.id) == lang.trackId(t.id);
                  return ListTile(
                    title: Text(lang.subtitleTrackLabel(t, index: idx)),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () async {
                      // If user selects embedded subtitles, hide external overlay.
                      if (_subtitleItems != null) {
                        setState(() {
                          _selectedSubtitle = null;
                          _subtitleItems = null;
                          _currentSubtitleText = '';
                        });
                      }
                      await player.setSubtitleTrack(t);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  );
                }),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  List<LibraryItemModel> get videos => widget.args.videos;
  List<LibraryItemModel> get subtitles => widget.args.subtitles;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _currentIndex =
        widget.args.initialIndex.clamp(0, videos.length - 1).toInt();
    _ensurePlayerInitialized();
    // Auto-load will happen in build
  }

  @override
  void deactivate() {
    // Navigating away destroys the underlying SurfaceView/Texture.
    // Pausing avoids the player continuing to render to a dead surface.
    _player?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _disposePlayerInternal();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player?.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _onScroll() {
    // Auto-pause video when scrolling down
    if (_scrollController.offset > 50 && _isPlaying) {
      _player?.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _attachPlayerListeners() {
    final player = _player;
    if (player == null) return;

    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _logSub?.cancel();
    _bufferingSub?.cancel();
    _videoParamsSub?.cancel();

    _positionSub = player.stream.position.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _updateSubtitleText();
    });

    _durationSub = player.stream.duration.listen((duration) {
      if (!mounted) return;
      setState(() {
        _totalDuration = duration;
      });
    });

    _playingSub = player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() {
        _isPlaying = playing;
      });
    });

    _completedSub = player.stream.completed.listen((completed) {
      if (!mounted) return;
      if (completed && !_hasPlayedNext) {
        _hasPlayedNext = true;
        _playNextVideo();
      }
    });

    _bufferingSub = player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (buffering) {
        print('⏳ Buffering...');
      }
    });

    _videoParamsSub = player.stream.videoParams.listen((params) {
      // Helps confirm frames are actually arriving.
      print('📐 VideoParams: ${params.w}x${params.h}');
    });

    _errorSub = player.stream.error.listen((message) {
      print('❌ media_kit error: $message');
    });

    _logSub = player.stream.log.listen((log) {
      // Useful for ExoPlayer / backend errors without being too noisy.
      // You can comment this out if it gets chatty.
      print('🧾 media_kit log: ${log.level}: ${log.text}');
    });
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
      // Stop previous media.
      await _player?.stop();

      setState(() {
        _isVideoInitialized = false;
        _isPlaying = false;
      });

      final streamUrl = video.streamUrl ?? video.fileUrl;

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No stream URL available');
      }

      print('🔗 Stream URL: $streamUrl');

      if (mounted) {
        setState(() {
          _currentStreamUrl = streamUrl;
        });
      }

      // Initialize media_kit player
      final openStopwatch = Stopwatch()..start();
      await _openWithFallback(streamUrl);
      openStopwatch.stop();
      print('⏱️ Player open took: ${openStopwatch.elapsedMilliseconds}ms');

      print('✅ media_kit player opened successfully');

      setState(() {
        _isVideoInitialized = true;
        _isInitializing = false;
        _hasPlayedNext = false;
      });

      // Auto-load English subtitle if available
      _autoLoadEnglishSubtitle(video);

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
    if (_subtitleItems == null) {
      return;
    }

    final currentMillis = _currentPosition.inMilliseconds;

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
    final player = _player;
    if (player == null || !_isVideoInitialized) return;
    if (_isPlaying) {
      player.pause();
    } else {
      player.play();
    }
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
    final bool subtitleActive =
        _isVideoInitialized && _currentSubtitleText.isNotEmpty;
    final double subtitleBottom = _isFullscreen ? 20 : 16;

    final bool hasVideoOutput = _player != null && _videoController != null;

    return SizedBox(
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
            if (hasVideoOutput)
              SizedBox.expand(
                child: MaterialVideoControlsTheme(
                  normal: kDefaultMaterialVideoControlsThemeData,
                  fullscreen: kDefaultMaterialVideoControlsThemeDataFullscreen.copyWith(
                    bottomButtonBar: [
                      const MaterialPositionIndicator(),
                      const Spacer(),
                      Builder(
                        builder: (ctx) => MaterialCustomButton(
                          icon: const Icon(Icons.audiotrack),
                          onPressed: () => _showTracksSheet(ctx),
                        ),
                      ),
                      const MaterialFullscreenButton(),
                    ],
                  ),
                  child: Video(
                    key: ValueKey<String>(_currentStreamUrl ?? 'video'),
                    controller: _videoController!,
                    controls: AdaptiveVideoControls,
                  ),
                ),
              ),

            if (_isInitializing)
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
            else if (!_isVideoInitialized)
              const Center(
                child: Icon(
                  Icons.movie,
                  size: 64,
                  color: Colors.white54,
                ),
              ),

            // Tracks selector (explicit).
            if (_isVideoInitialized && _player != null)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: IconButton(
                    icon: const Icon(Icons.audiotrack, color: Colors.white),
                    onPressed: () => _showTracksSheet(context),
                  ),
                ),
              ),

            // Keep external subtitle overlay (if loaded via SubtitleParser).
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
