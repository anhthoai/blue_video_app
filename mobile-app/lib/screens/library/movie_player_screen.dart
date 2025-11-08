import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../models/movie_model.dart';
import '../../core/services/movie_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/subtitle_parser.dart';

class _DownloadProgress {
  const _DownloadProgress({required this.received, required this.total});

  final int received;
  final int total;

  double? get percent => total <= 0 ? null : received / total;

  static const zero = _DownloadProgress(received: 0, total: 0);
}

class MoviePlayerScreen extends ConsumerStatefulWidget {
  final String movieId;
  final String? initialEpisodeId;

  const MoviePlayerScreen({
    super.key,
    required this.movieId,
    this.initialEpisodeId,
  });

  @override
  ConsumerState<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends ConsumerState<MoviePlayerScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final Dio _dio = Dio();
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
  bool _hasPlayedNext = false; // Flag to prevent multiple auto-play triggers

  String? _currentEpisodeId;
  MovieEpisode? _currentEpisode;

  // Subtitle state
  Subtitle? _selectedSubtitle;
  List<SubtitleItem>? _subtitleItems;
  String _currentSubtitleText = '';

  @override
  void initState() {
    super.initState();
    _dio.options
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(minutes: 10)
      ..followRedirects = true
      ..validateStatus = (status) => status != null && status < 500;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    // Don't set _currentEpisodeId here - let it trigger auto-load
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

  Future<void> _loadEpisode(MovieEpisode episode) async {
    if (_isInitializing) return;

    print('🎬 Loading episode: ${episode.title}');
    print('   Episode ID: ${episode.id}');

    setState(() {
      _isInitializing = true;
      _currentEpisodeId = episode.id;
      _currentEpisode = episode;
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

      print('📡 Fetching stream URL from backend...');

      // Get stream URL from backend
      final movieService = ref.read(movieServiceProvider);
      final streamUrl = await movieService
          .getEpisodeStreamUrl(
        widget.movieId,
        episode.id,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ Timeout waiting for stream URL');
          throw Exception('Request timed out');
        },
      );

      print('🔗 Stream URL received: ${streamUrl ?? "NULL"}');

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No stream URL returned from backend');
      }

      print('🎥 Initializing video player...');

      // Initialize video player
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
      );

      // Add listener for position updates, subtitles, and auto-play next episode
      _videoController!.addListener(() {
        if (mounted && _videoController != null) {
          setState(() {
            _currentPosition = _videoController!.value.position;
            _totalDuration = _videoController!.value.duration;
          });

          // Update subtitle text based on current position
          _updateSubtitleText();

          // Check if video has finished and auto-play next episode
          if (!_hasPlayedNext &&
              _videoController!.value.position >=
                  _videoController!.value.duration &&
              _videoController!.value.duration.inSeconds > 0) {
            _hasPlayedNext = true; // Set flag to prevent multiple calls
            _playNextEpisode();
          }
        }
      });

      await _videoController!.initialize();

      print('✅ Video player initialized successfully');
      print('   Duration: ${_videoController!.value.duration}');
      print('   Size: ${_videoController!.value.size}');

      setState(() {
        _isVideoInitialized = true;
        _isInitializing = false;
        _isPlaying = true;
        _totalDuration = _videoController!.value.duration;
        _hasPlayedNext = false; // Reset flag for next video
      });

      _videoController!.play();

      // Auto-load English subtitle if available
      _autoLoadEnglishSubtitle(episode);

      // Auto-hide controls
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    } catch (e) {
      print('❌ Error loading episode: ${e.toString()}');

      setState(() {
        _isInitializing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadEpisode(episode),
            ),
          ),
        );
      }
    }
  }

  void _playNextEpisode() {
    // Get the movie data to find episodes list
    final movieAsync = ref.read(movieDetailProvider(widget.movieId));

    movieAsync.whenData((movie) {
      if (movie == null || movie.episodes == null || movie.episodes!.isEmpty) {
        print('❌ No episodes available for auto-play');
        return;
      }

      // Find current episode index
      final currentIndex = movie.episodes!.indexWhere(
        (ep) => ep.id == _currentEpisodeId,
      );

      if (currentIndex == -1) {
        print('❌ Current episode not found in list');
        return;
      }

      // Check if there's a next episode
      if (currentIndex + 1 < movie.episodes!.length) {
        final nextEpisode = movie.episodes![currentIndex + 1];
        print('▶️ Auto-playing next episode: ${nextEpisode.title}');

        // Load next episode
        _loadEpisode(nextEpisode);
      } else {
        print('✅ Reached end of episode list');
        // Show controls when there's no next episode
        setState(() {
          _showControls = true;
        });
      }
    });
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
    final episode = _currentEpisode;
    if (episode == null ||
        episode.subtitles == null ||
        episode.subtitles!.isEmpty) {
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
                      children: episode.subtitles!.map((sub) {
                        return ListTile(
                          leading: Text(
                            sub.flagEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(sub.label),
                          subtitle: Text(sub.language.toUpperCase(),
                              style: const TextStyle(fontSize: 11)),
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

  Future<void> _loadSubtitle(Subtitle subtitle,
      {bool isDefault = false}) async {
    try {
      print('📝 Loading subtitle: ${subtitle.label}');

      // Get stream URL from backend
      final movieService = ref.read(movieServiceProvider);
      final streamUrl = await movieService.getSubtitleStreamUrl(
        widget.movieId,
        _currentEpisode!.id,
        subtitle.id,
      );

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No stream URL returned from backend');
      }

      print('🔗 Downloading subtitle from: $streamUrl');

      // Download subtitle file from stream URL
      final response = await http.get(Uri.parse(streamUrl));

      if (response.statusCode == 200) {
        print(
            '✅ Subtitle file downloaded (${response.bodyBytes.length} bytes)');

        final decodedContent =
            _decodeSubtitleContent(response.bodyBytes, response.headers);

        // Parse SRT file
        final parser = SubtitleParser();
        final rawItems = parser.parseSrt(decodedContent);

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
              content: Text('Loaded ${subtitle.label} subtitle'),
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

  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return;

    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return;
    }

    if (manageStatus.isPermanentlyDenied) {
      throw Exception(
        'Storage permission denied. Please enable "Allow access to all files" in system settings.',
      );
    }

    var requestedStatus = await Permission.manageExternalStorage.request();
    if (requestedStatus.isGranted) {
      return;
    }

    var legacyStatus = await Permission.storage.status;
    if (legacyStatus.isGranted) {
      return;
    }

    if (!legacyStatus.isPermanentlyDenied) {
      legacyStatus = await Permission.storage.request();
      if (legacyStatus.isGranted) {
        return;
      }
    }

    throw Exception(
      'Storage permission denied. Please enable storage access in system settings.',
    );
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      await _ensureStoragePermission();

      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (await publicDownloads.exists()) {
        return publicDownloads;
      }

      final downloadsDirs =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (downloadsDirs != null && downloadsDirs.isNotEmpty) {
        return downloadsDirs.first;
      }

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return externalDir;
      }
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      return downloadsDir;
    }

    return await getApplicationDocumentsDirectory();
  }

  String _sanitizeFileName(String name, {String fallback = 'file'}) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return fallback;
    }
    return sanitized;
  }

  Future<String> _uniqueFilePath(Directory directory, String fileName) async {
    final baseName = p.basenameWithoutExtension(fileName);
    final extension =
        p.extension(fileName).isEmpty ? '.dat' : p.extension(fileName);

    var candidate = p.join(directory.path, '$baseName$extension');
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(directory.path, '$baseName($counter)$extension');
      counter++;
    }
    return candidate;
  }

  Future<String> _downloadFileToDevice(
    String url,
    String desiredFileName, {
    required CancelToken cancelToken,
    required ValueNotifier<_DownloadProgress> progressNotifier,
  }) async {
    final downloadsDir = await _resolveDownloadDirectory();
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final sanitizedName = _sanitizeFileName(desiredFileName);
    final targetPath = await _uniqueFilePath(downloadsDir, sanitizedName);

    print('⬇️ Downloading file to: $targetPath');

    await _dio.download(
      url,
      targetPath,
      options: Options(
        followRedirects: true,
        responseType: ResponseType.bytes,
        headers: {
          'User-Agent': 'BlueVideoApp/1.0',
        },
      ),
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        progressNotifier.value =
            _DownloadProgress(received: received, total: total);
      },
    );

    return targetPath;
  }

  String _buildEpisodeDownloadName(MovieEpisode episode) {
    final ext = (episode.extension != null && episode.extension!.isNotEmpty)
        ? (episode.extension!.startsWith('.')
            ? episode.extension!
            : '.${episode.extension}')
        : '.mp4';

    final rawName = episode.title?.isNotEmpty == true
        ? episode.title!
        : episode.slug ??
            'episode_${episode.seasonNumber}_${episode.episodeNumber}';

    final sanitized = _sanitizeFileName(rawName, fallback: 'episode');
    if (sanitized.toLowerCase().endsWith(ext.toLowerCase())) {
      return sanitized;
    }
    return '$sanitized$ext';
  }

  String _buildSubtitleDownloadName(
    MovieEpisode episode,
    Subtitle subtitle,
  ) {
    final baseName = episode.title?.isNotEmpty == true
        ? episode.title!
        : 'episode_${episode.seasonNumber}_${episode.episodeNumber}';

    final withLanguage = '${baseName}_${subtitle.language.toLowerCase()}';
    final sanitized = _sanitizeFileName(withLanguage, fallback: 'subtitle');
    if (sanitized.toLowerCase().endsWith('.srt')) {
      return sanitized;
    }
    return '$sanitized.srt';
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

  Future<void> _downloadEpisode(MovieEpisode episode) async {
    final messenger = ScaffoldMessenger.of(context);
    final progressNotifier =
        ValueNotifier<_DownloadProgress>(_DownloadProgress.zero);
    final cancelToken = CancelToken();
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snackController;

    try {
      if (!mounted) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Preparing episode download...'),
          duration: Duration(seconds: 2),
        ),
      );

      snackController = _showDownloadSnackBar(
        'Downloading episode...',
        progressNotifier,
        cancelToken,
      );

      final movieService = ref.read(movieServiceProvider);
      final streamUrl = await movieService.getEpisodeStreamUrl(
        widget.movieId,
        episode.id,
      );

      final resolvedUrl = streamUrl ?? episode.streamUrl ?? episode.fileUrl;

      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        throw Exception('Download URL not available.');
      }

      final fileName = _buildEpisodeDownloadName(episode);
      final savedPath = await _downloadFileToDevice(
        resolvedUrl,
        fileName,
        cancelToken: cancelToken,
        progressNotifier: progressNotifier,
      );

      if (!mounted) return;
      _closeSnack(snackController);
      snackController = null;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${p.basename(savedPath)} to device storage',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      progressNotifier.value = _DownloadProgress.zero;

      _closeSnack(snackController);
      snackController = null;

      if (e.type == DioExceptionType.cancel) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Episode download cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading episode: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _closeSnack(snackController);
      snackController = null;
      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading episode: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      progressNotifier.dispose();
      _closeSnack(snackController);
    }
  }

  Future<void> _downloadSubtitleFile(
    MovieEpisode episode,
    Subtitle subtitle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final progressNotifier =
        ValueNotifier<_DownloadProgress>(_DownloadProgress.zero);
    final cancelToken = CancelToken();
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snackController;

    try {
      if (!mounted) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Preparing ${subtitle.label} subtitle download...'),
          duration: const Duration(seconds: 2),
        ),
      );

      snackController = _showDownloadSnackBar(
        'Downloading ${subtitle.label} subtitle...',
        progressNotifier,
        cancelToken,
      );

      final movieService = ref.read(movieServiceProvider);
      final streamUrl = await movieService.getSubtitleStreamUrl(
        widget.movieId,
        episode.id,
        subtitle.id,
      );

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Subtitle download URL not available.');
      }

      final fileName = _buildSubtitleDownloadName(episode, subtitle);
      final savedPath = await _downloadFileToDevice(
        streamUrl,
        fileName,
        cancelToken: cancelToken,
        progressNotifier: progressNotifier,
      );

      if (!mounted) return;
      _closeSnack(snackController);
      snackController = null;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${p.basename(savedPath)} to device storage',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      progressNotifier.value = _DownloadProgress.zero;

      _closeSnack(snackController);
      snackController = null;

      if (e.type == DioExceptionType.cancel) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Subtitle download cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading subtitle: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _closeSnack(snackController);
      snackController = null;
      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading subtitle: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      progressNotifier.dispose();
      _closeSnack(snackController);
    }
  }

  void _autoLoadEnglishSubtitle(MovieEpisode episode) {
    if (episode.subtitles == null || episode.subtitles!.isEmpty) {
      print('   No subtitles available for auto-load');
      return;
    }

    // Find English subtitle (eng)
    final englishSubtitle = episode.subtitles!.firstWhere(
      (sub) => sub.language.toLowerCase() == 'eng',
      orElse: () => episode.subtitles!.first, // Fallback to first subtitle
    );

    print('   🌐 Auto-loading subtitle: ${englishSubtitle.label}');

    // Load subtitle in background (don't show SnackBar)
    _loadSubtitle(englishSubtitle, isDefault: true);
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
      _showDownloadSnackBar(
    String title,
    ValueNotifier<_DownloadProgress> progressNotifier,
    CancelToken cancelToken,
  ) {
    final messenger = ScaffoldMessenger.of(context);

    return messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        behavior: SnackBarBehavior.floating,
        content: DownloadSnackBarContent(
          title: title,
          progressNotifier: progressNotifier,
          formatBytes: _formatBytes,
        ),
        action: SnackBarAction(
          label: 'Cancel',
          textColor: Colors.yellowAccent,
          onPressed: () {
            if (!cancelToken.isCancelled) {
              cancelToken.cancel('Cancelled by user');
            }
          },
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    final formatted =
        suffixIndex == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$formatted ${suffixes[suffixIndex]}';
  }

  void _closeSnack(
      ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller) {
    controller?.close();
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
    final l10n = AppLocalizations.of(context);
    final movieAsync = ref.watch(movieDetailProvider(widget.movieId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: movieAsync.when(
        data: (movie) {
          if (movie == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  const Text(
                    'Movie not found',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          // Auto-load episode on first build (only once)
          if (!_isVideoInitialized &&
              !_isInitializing &&
              _currentEpisode == null &&
              movie.episodes != null &&
              movie.episodes!.isNotEmpty) {
            print('🎬 Auto-loading episode...');
            print('   Initial episode ID: ${widget.initialEpisodeId}');
            print('   Total episodes: ${movie.episodes!.length}');

            MovieEpisode? episodeToLoad;

            if (widget.initialEpisodeId != null) {
              // Load specific episode if provided
              episodeToLoad = movie.episodes!.firstWhere(
                (ep) => ep.id == widget.initialEpisodeId,
                orElse: () => movie.episodes!.first,
              );
              print('   Found episode: ${episodeToLoad.title}');
            } else {
              // Load first episode
              episodeToLoad = movie.episodes!.first;
              print('   Loading first episode: ${episodeToLoad.title}');
            }

            // Trigger load immediately, not in post-frame callback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                print('   🚀 Calling _loadEpisode...');
                _loadEpisode(episodeToLoad!);
              }
            });
          }

          final isMovieType =
              movie.contentType == 'MOVIE' || movie.contentType == 'SHORT';

          return _isFullscreen
              ? _buildVideoPlayer(movie)
              : Column(
                  children: [
                    _buildVideoPlayer(movie),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMovieInfo(movie),
                              if (movie.episodes != null &&
                                  movie.episodes!.isNotEmpty)
                                _buildEpisodesList(movie, isMovieType, l10n),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading movie',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(MovieModel movie) {
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
                // Loading state - single loading indicator
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
                // Show movie poster as placeholder
                Center(
                  child: movie.posterUrl != null
                      ? Image.network(
                          movie.posterUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.movie,
                            size: 64,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(
                          Icons.movie,
                          size: 64,
                          color: Colors.white54,
                        ),
                ),

              // Controls overlay - use Positioned to avoid overflow
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
                              context.pop();
                            }
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                movie.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_currentEpisode != null)
                                Text(
                                  _currentEpisode!.title ??
                                      'Episode ${_currentEpisode!.episodeNumber}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
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

  Widget _buildMovieInfo(MovieModel movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            movie.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (movie.voteAverage != null) ...[
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${movie.voteAverage!.toStringAsFixed(1)}/10',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  '${movie.releaseYear}${movie.runtime != null ? ' • ${movie.formattedRuntime}' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesList(
      MovieModel movie, bool isMovieType, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMovieType ? 'Files' : l10n.episodes,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...movie.episodes!.map((episode) {
            final isCurrentEpisode = episode.id == _currentEpisodeId;

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              color: isCurrentEpisode ? Colors.red[50] : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isCurrentEpisode
                    ? const BorderSide(color: Colors.red, width: 1.2)
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isCurrentEpisode ? null : () => _loadEpisode(episode),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                  if (episode.thumbnailUrl != null)
                                    Image.network(
                                      episode.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.movie,
                                          color: Colors.grey),
                                    )
                                  else
                                    const Icon(Icons.movie, color: Colors.grey),
                                  if (isCurrentEpisode)
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
                                  episode.title ??
                                      'Episode ${episode.episodeNumber}',
                                  style: TextStyle(
                                    fontWeight: isCurrentEpisode
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 13,
                                    color: isCurrentEpisode ? Colors.red : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (episode.duration != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      episode.formattedDuration,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isCurrentEpisode
                                            ? Colors.red[700]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download),
                            color: isCurrentEpisode
                                ? Colors.red
                                : Colors.grey[700],
                            tooltip: 'Download episode',
                            onPressed: (episode.fileUrl != null &&
                                    episode.fileUrl!.isNotEmpty)
                                ? () => _downloadEpisode(episode)
                                : null,
                          ),
                        ],
                      ),
                      if (episode.subtitles != null &&
                          episode.subtitles!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: episode.subtitles!.map((sub) {
                              return InkWell(
                                onTap: () =>
                                    _downloadSubtitleFile(episode, sub),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.grey[400]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        sub.flagEmoji,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.download,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
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

class DownloadSnackBarContent extends StatelessWidget {
  const DownloadSnackBarContent({
    super.key,
    required this.title,
    required this.progressNotifier,
    required this.formatBytes,
  });

  final String title;
  final ValueNotifier<_DownloadProgress> progressNotifier;
  final String Function(int bytes) formatBytes;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_DownloadProgress>(
      valueListenable: progressNotifier,
      builder: (_, progress, __) {
        final percent = progress.percent;
        final clampedPercent = percent != null ? percent.clamp(0.0, 1.0) : null;
        final downloadedLabel = progress.total > 0
            ? '${formatBytes(progress.received)} / ${formatBytes(progress.total)}'
            : '${formatBytes(progress.received)} downloaded';
        final percentLabel = percent != null
            ? '${(percent * 100).clamp(0, 100).toStringAsFixed(0)}%'
            : '';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: clampedPercent),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    downloadedLabel,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  percentLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
