import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/video_model.dart';
import '../../core/services/video_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/file_url_service.dart';
import '../../core/utils/subtitle_utils.dart';
import '../../core/utils/language_utils.dart';
import '../../widgets/social/comments_section.dart';
import '../../widgets/common/presigned_image.dart';

// Provider to fetch video by ID
final videoByIdProvider =
    FutureProvider.family<VideoModel?, String>((ref, videoId) async {
  final videoService = ref.watch(videoServiceProvider);
  return await videoService.getVideoById(videoId);
});

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  VideoPlayerController? _videoController;
  WebViewController? _webViewController;
  bool _isPlaying = false;
  bool _showControls = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 10);
  bool _isVideoInitialized = false;
  bool _isFullscreen = false;
  bool _isDescriptionExpanded = false;
  bool _isEmbedVideo = false;
  bool _isPreviewMode = false;
  bool _hasShownPreviewWarning = false;

  // Follow functionality
  final ApiService _apiService = ApiService();
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  String? _followStatusLoadedForUserId;
  String? _authorAvatarUrl;
  String? _authorAvatarLoadedForUserId;

  // Video stats
  int _currentViews = 0;
  int _currentLikes = 0;
  int _currentShares = 0;
  int _currentDownloads = 0;
  bool _isLiked = false;
  bool _hasIncrementedView = false;

  // Subtitle functionality
  List<String> _availableSubtitles = [];
  String? _currentSubtitleCode;
  bool _subtitlesEnabled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    // Refresh data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshVideoData();
    });
  }

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If videoId changed, reset video player and invalidate cache
    if (oldWidget.videoId != widget.videoId) {
      print(
          '🎥 Video ID changed from ${oldWidget.videoId} to ${widget.videoId}');
      _resetVideoPlayer();
      // Reset all stats for new video
      _currentViews = 0;
      _currentLikes = 0;
      _currentShares = 0;
      _currentDownloads = 0;
      _isLiked = false;
      // Invalidate the provider cache to fetch fresh data
      ref.invalidate(videoByIdProvider(widget.videoId));
    }
  }

  void _resetVideoPlayer() {
    print('🎥 Resetting video player for new video');

    // Set initializing flag to prevent re-entry
    _isInitializing = true;

    // Dispose current video controller
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
    }

    // Reset video state
    setState(() {
      _isVideoInitialized = false;
      _isInitializing = false;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = const Duration(minutes: 10);
      _hasIncrementedView = false; // Reset view increment flag
    });

    // Reset current video URL
    _currentVideoUrl = null;
  }

  // Increment view count when video starts playing
  Future<void> _incrementViewCount(String videoId) async {
    if (_hasIncrementedView) return;

    try {
      final response = await _apiService.incrementVideoView(videoId);
      if (response['success'] == true && response['data'] != null) {
        _hasIncrementedView = true;
        if (mounted) {
          setState(() {
            _currentViews = response['data']['views'] ?? _currentViews;
          });
        }
      }
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  // Toggle like
  Future<void> _toggleLike(String videoId) async {
    try {
      final response = await _apiService.toggleVideoLike(videoId);
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _currentLikes = response['data']['likes'] ?? _currentLikes;
            _isLiked = response['data']['isLiked'] ?? !_isLiked;
          });
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
      if (e.toString().contains('Authentication required')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to like videos'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  // Increment share count
  Future<void> _incrementShareCount(String videoId, {String? platform}) async {
    try {
      final response =
          await _apiService.incrementVideoShare(videoId, platform: platform);
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _currentShares = response['data']['shares'] ?? _currentShares;
          });
        }
      }
    } catch (e) {
      print('Error incrementing share count: $e');
    }
  }

  // Increment download count
  Future<void> _incrementDownloadCount(String videoId) async {
    try {
      final response = await _apiService.incrementVideoDownload(videoId);
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _currentDownloads =
                response['data']['downloads'] ?? _currentDownloads;
          });
        }
      }
    } catch (e) {
      print('Error incrementing download count: $e');
    }
  }

  // Load user's follow status
  Future<void> _loadUserFollowStatus(String userId) async {
    if (_followStatusLoadedForUserId == userId) return;
    try {
      final response = await _apiService.getUserProfile(userId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _isFollowing = response['data']['isFollowing'] ?? false;
          _followStatusLoadedForUserId = userId;
        });
      }
    } catch (e) {
      print('Error loading follow status: $e');
    }
  }

  // Fallback: fetch author avatar from user profile once
  Future<void> _loadAuthorAvatar(String userId) async {
    try {
      final response = await _apiService.getUserProfile(userId);
      if (response['success'] == true && response['data'] != null) {
        final url = response['data']['avatarUrl'] as String?;
        if (mounted && url != null && url.isNotEmpty) {
          setState(() {
            _authorAvatarUrl = url;
          });
        }
      }
    } catch (e) {
      print('Error loading author avatar: $e');
    }
  }

  // Toggle follow status
  Future<void> _toggleFollow(String userId) async {
    setState(() {
      _isLoadingFollow = true;
    });

    try {
      Map<String, dynamic> response;
      if (_isFollowing) {
        response = await _apiService.unfollowUser(userId);
      } else {
        response = await _apiService.followUser(userId);
      }

      if (response['success'] == true) {
        setState(() {
          _isFollowing = !_isFollowing;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(_isFollowing ? 'Following user' : 'Unfollowed user'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(response['message'] ?? 'Failed to update follow status'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error toggling follow: $e');

      // Check if it's a 401 authentication error
      if (e.toString().contains('Authentication required')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your session has expired. Please sign in again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          // Wait a moment for the message to show, then redirect
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.pushReplacement('/auth/login');
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update follow status'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app becomes active (user returns to the app), refresh video data
    if (state == AppLifecycleState.resumed) {
      _refreshVideoData();
    }
  }

  // Refresh video data from server
  Future<void> _refreshVideoData() async {
    try {
      final response = await _apiService.getVideoById(widget.videoId);
      if (response['success'] == true && response['data'] != null) {
        final videoData = response['data'];
        if (mounted) {
          setState(() {
            _currentViews = videoData['views'] ?? _currentViews;
            _currentLikes = videoData['likes'] ?? _currentLikes;
            _currentShares = videoData['shares'] ?? _currentShares;
            _currentDownloads = videoData['downloads'] ?? _currentDownloads;
            _isLiked = videoData['isLiked'] ?? _isLiked;

            // Load available subtitles
            final subtitles = videoData['subtitles'];
            if (subtitles != null && subtitles is List) {
              _availableSubtitles = List<String>.from(subtitles);
            }
          });
        }
      }
    } catch (e) {
      print('Error refreshing video data: $e');
    }
  }

  // Current video data cache
  String? _currentVideoFileDirectory;
  String? _currentVideoFileName;

  // Load subtitle for the video
  Future<void> _loadSubtitle(String languageCode,
      {bool showNotification = true}) async {
    if (_videoController == null) return;
    if (_currentVideoFileDirectory == null || _currentVideoFileName == null) {
      print('⚠️  Video file info not available yet');
      return;
    }

    try {
      print('📝 Loading subtitle: $languageCode');

      final subtitleFile = await SubtitleUtils.loadSubtitle(
        _currentVideoFileDirectory,
        _currentVideoFileName,
        languageCode,
      );

      if (subtitleFile != null) {
        // setClosedCaptionFile expects Future<ClosedCaptionFile>, so wrap it
        _videoController!.setClosedCaptionFile(Future.value(subtitleFile));
        if (mounted) {
          setState(() {
            _currentSubtitleCode = languageCode;
            _subtitlesEnabled = true;
          });
        }
        print('✅ Subtitle loaded: $languageCode');

        if (mounted && showNotification) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Subtitle: ${LanguageUtils.getLanguageName(languageCode)}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('⚠️  Subtitle not available: $languageCode');
        if (mounted && showNotification) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Subtitle not available for ${LanguageUtils.getLanguageName(languageCode)}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading subtitle: $e');
      if (mounted && showNotification) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load subtitle'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Show subtitle selector dialog
  void _showSubtitleSelector() {
    if (_availableSubtitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitles available for this video'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Subtitle',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  controller: scrollController,
                  shrinkWrap: true,
                  children: [
                    // Language options
                    ...SubtitleUtils.getAvailableSubtitles(_availableSubtitles)
                        .map((subtitle) => ListTile(
                              leading: Icon(
                                _currentSubtitleCode == subtitle.code
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: _currentSubtitleCode == subtitle.code
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              title: Text(subtitle.displayName),
                              subtitle: Text(subtitle.code.toUpperCase()),
                              onTap: () {
                                Navigator.pop(context);
                                _loadSubtitle(subtitle.code);
                              },
                            )),
                    const Divider(),
                    // Off option
                    ListTile(
                      leading: Icon(
                        !_subtitlesEnabled
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: !_subtitlesEnabled ? Colors.blue : Colors.grey,
                      ),
                      title: const Text('Off'),
                      subtitle: const Text('Disable subtitles'),
                      onTap: () {
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() {
                            _subtitlesEnabled = false;
                            _currentSubtitleCode = null;
                          });
                        }
                        _videoController?.setClosedCaptionFile(null);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Subtitles disabled'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for adaptive layout
  double _getSubtitleBottomPosition() {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    // Position subtitle very close to the bottom, just above video controls
    // Controls take up approximately 80-100px (padding + buttons + progress bar)
    if (_isFullscreen) {
      return isLandscape
          ? 95
          : 85; // Just above fullscreen controls (90-100px from bottom)
    } else {
      return isLandscape
          ? 80
          : 70; // Just above normal controls (75-85px from bottom)
    }
  }

  double _getControlPadding() {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (_isFullscreen) {
      return isLandscape ? 24 : 20; // More padding in fullscreen
    } else {
      return isLandscape ? 20 : 16; // More padding in landscape
    }
  }

  double _getControlVerticalPadding() {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (_isFullscreen) {
      return isLandscape ? 16 : 14; // More padding in fullscreen
    } else {
      return isLandscape ? 12 : 8; // More padding in landscape
    }
  }

  double _getBottomControlPadding() {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    // More padding since subtitles are now positioned much lower, close to controls
    if (_isFullscreen) {
      return isLandscape ? 40 : 36; // Extra padding in fullscreen
    } else {
      return isLandscape ? 34 : 28; // Extra padding in normal mode
    }
  }

  double _getSubtitleFontSize() {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (_isFullscreen) {
      return isLandscape ? 28 : 26; // Larger in fullscreen
    } else {
      return isLandscape ? 22 : 20; // Larger in landscape
    }
  }

  double _getButtonSize({bool small = false}) {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (_isFullscreen) {
      return small ? (isLandscape ? 32 : 30) : (isLandscape ? 40 : 38);
    } else {
      return small ? (isLandscape ? 26 : 24) : (isLandscape ? 32 : 28);
    }
  }

  double _getButtonSpacing() {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (_isFullscreen) {
      return isLandscape ? 28 : 26; // More spacing in fullscreen
    } else {
      return isLandscape ? 22 : 16; // More spacing in landscape
    }
  }

  // Load default English subtitle if available
  void _loadDefaultSubtitle() {
    print('📝 Checking for default subtitle...');
    if (_availableSubtitles.isEmpty) {
      print('  No subtitles available');
      return;
    }

    // Try to find English subtitle (eng, en, or english)
    String? englishCode;
    for (final code in _availableSubtitles) {
      final normalized = code.toLowerCase();
      if (normalized == 'eng' ||
          normalized == 'en' ||
          normalized == 'english') {
        englishCode = code;
        break;
      }
    }

    if (englishCode != null) {
      print('  Found English subtitle: $englishCode');
      // Load without notification to avoid spam
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadSubtitle(englishCode!, showNotification: false);
      });
    } else {
      print('  No English subtitle found in: $_availableSubtitles');
    }
  }

  String? _currentVideoUrl;

  bool _isInitializing = false;

  Future<void> _initializeVideo(VideoModel video) async {
    print('🎥 _initializeVideo called for video: ${video.title}');
    print('  - embedCode: ${video.embedCode != null}');
    print('  - remotePlayUrl: ${video.remotePlayUrl}');
    print(
        '  - fileName/fileDirectory: ${video.fileName}/${video.fileDirectory}');
    print('  - requiresVIP: ${video.requiresVIP}');
    print('  - cost: ${video.cost}');

    // Check VIP access
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.currentUser;
    final isUserVIP = currentUser?.isVip ?? false;
    final isUserPaid = video.isPaid; // Check if user has paid for this video

    // Determine if preview mode
    final needsVIPAccess = video.requiresVIP && !isUserVIP && !isUserPaid;
    final needsPayment = video.hasCost && !isUserPaid;

    setState(() {
      _isPreviewMode = needsVIPAccess || needsPayment;
    });

    // Prevent reinitializing if already initializing
    if (_isInitializing) {
      print('🎥 Video already initializing');
      return;
    }

    print('🎥 Actually initializing video');
    _isInitializing = true;

    // Dispose current controller if it exists
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
    }

    // Priority 1: Embed Code
    if (video.embedCode != null && video.embedCode!.isNotEmpty) {
      print('🎥 Using embed code');
      setState(() {
        _isEmbedVideo = true;
        _isVideoInitialized = true;
        _isInitializing = false;
      });
      _initializeEmbedVideo(video.embedCode!);
      return;
    }

    // Priority 2: Remote Play URL
    String? playbackUrl;
    if (video.remotePlayUrl != null && video.remotePlayUrl!.isNotEmpty) {
      print('🎥 Using remote play URL');
      playbackUrl = video.remotePlayUrl;
    }
    // Priority 3: Presigned URL from fileName/fileDirectory
    else if (video.fileName != null && video.fileDirectory != null) {
      print('🎥 Getting presigned URL from fileName/fileDirectory');
      final objectKey = 'videos/${video.fileDirectory}/${video.fileName}';
      playbackUrl = await FileUrlService().getAccessibleUrl(objectKey);
    }
    // Fallback: videoUrl for backward compatibility
    else if (video.videoUrl.isNotEmpty) {
      print('🎥 Using legacy videoUrl');
      playbackUrl = video.videoUrl;
    }

    if (playbackUrl == null || playbackUrl.isEmpty) {
      print('❌ No playback URL available');
      setState(() {
        _isInitializing = false;
      });
      return;
    }

    _initializeVideoPlayer(playbackUrl, video);
  }

  void _initializeEmbedVideo(String embedCode) {
    print('🎥 Initializing embed video');
    // For embed code, we'll use WebView
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              body { margin: 0; padding: 0; background: #000; }
              iframe { width: 100vw; height: 100vh; border: none; }
            </style>
          </head>
          <body>
            $embedCode
          </body>
        </html>
      ''');
  }

  void _initializeVideoPlayer(String videoUrl, VideoModel video) {
    print('🎥 Initializing video player with URL: $videoUrl');

    // Cache video file info for subtitle loading
    _currentVideoFileDirectory = video.fileDirectory;
    _currentVideoFileName = video.fileName;
    print(
        '📁 Cached video file info: $_currentVideoFileDirectory/$_currentVideoFileName');

    _currentVideoUrl = videoUrl;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        print('✅ Video initialized successfully');
        _isInitializing = false;
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _isEmbedVideo = false;
            _totalDuration = _videoController!.value.duration;
          });

          // Setup preview mode if needed
          if (_isPreviewMode) {
            _setupPreviewMode();
          }

          // Auto-play
          _videoController!.play();
          setState(() {
            _isPlaying = true;
          });

          // Load default English subtitle if available
          _loadDefaultSubtitle();

          // Increment view count when video is ready
          _incrementViewCount(widget.videoId);
        }
      }).catchError((error) {
        print('❌ Video initialization error: $error');
        _isInitializing = false;
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
            _currentVideoUrl = null;
          });
        }
      })
      ..addListener(() {
        if (mounted && _videoController != null) {
          setState(() {
            _currentPosition = _videoController!.value.position;
          });

          // Check preview limit (15 seconds for free users)
          if (_isPreviewMode &&
              !_hasShownPreviewWarning &&
              _currentPosition.inSeconds >= 10) {
            _hasShownPreviewWarning = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '5 seconds remaining! Upgrade to VIP for full access.'),
                duration: Duration(seconds: 2),
              ),
            );
          }

          if (_isPreviewMode && _currentPosition.inSeconds >= 15) {
            _handlePreviewLimitReached();
          }
        }
      });
  }

  void _setupPreviewMode() {
    print('⏱️ Setting up 15-second preview mode');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isPreviewMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview mode: Only 15 seconds available'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _handlePreviewLimitReached() {
    if (_videoController != null && _isPlaying) {
      _videoController!.pause();
      setState(() {
        _isPlaying = false;
      });
      _showUpgradeDialog();
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Preview Limit Reached'),
        content: const Text(
          'You\'ve watched 15 seconds. Upgrade to VIP or purchase this video to watch the full content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to upgrade/purchase screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Upgrade feature coming soon!')),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.offset > 100) {
      if (_showControls) {
        setState(() {
          _showControls = false;
        });
      }
    } else {
      if (!_showControls) {
        setState(() {
          _showControls = true;
        });
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    // Hide controls after 3 seconds
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoByIdProvider(widget.videoId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: videoAsync.when(
        data: (video) {
          if (video == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Video not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          // Initialize video player when video data is loaded (only if not already initialized or initializing)
          if (!_isVideoInitialized &&
              !_isInitializing &&
              _videoController == null &&
              _currentVideoUrl != video.videoUrl) {
            print(
                '🎥 Build method triggering initialization for URL: ${video.videoUrl}');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeVideo(video);
            });
          }

          // Load follow status exactly once per userId to avoid loops
          if (_followStatusLoadedForUserId != video.userId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadUserFollowStatus(video.userId);
            });
          }

          // Fallback: ensure author avatar is loaded once
          if (_authorAvatarLoadedForUserId != video.userId) {
            _authorAvatarLoadedForUserId = video.userId;
            _authorAvatarUrl =
                (video.userAvatarUrl != null && video.userAvatarUrl!.isNotEmpty)
                    ? video.userAvatarUrl
                    : null;
            if (_authorAvatarUrl == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadAuthorAvatar(video.userId);
              });
            }
          }

          // Initialize video stats from server data only if not already set
          // This preserves real-time updates while ensuring fresh data on video load
          if (_currentViews == 0) {
            _currentViews = video.viewCount;
          }
          if (_currentLikes == 0) {
            _currentLikes = video.likeCount;
            _isLiked = video.isLiked;
          }
          if (_currentShares == 0) {
            _currentShares = video.shareCount;
          }
          if (_currentDownloads == 0) {
            _currentDownloads = video.downloadCount;
          }

          return _isFullscreen
              ? _buildVideoPlayer(video) // Only video player in fullscreen
              : Column(
                  children: [
                    _buildVideoPlayer(video),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildUserInfo(video),
                              _buildVideoInfo(video),
                              _buildActionButtons(video),
                              _buildAdsBanner(),
                              _buildRecommendedVideos(),
                              _buildCommentsSection(),
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
                'Error loading video',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(VideoModel video) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final orientation = mediaQuery.orientation;
    final isLandscape = orientation == Orientation.landscape;

    // For embed videos, show WebView
    if (_isEmbedVideo && _webViewController != null) {
      return Container(
        height: _isFullscreen
            ? screenSize.height
            : isLandscape
                ? screenSize.height
                : screenSize.width * 9 / 16,
        width: double.infinity,
        color: Colors.black,
        child: WebViewWidget(controller: _webViewController!),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_isVideoInitialized && _videoController != null) {
          if (_isPlaying) {
            // If playing, just toggle controls
            _toggleControls();
          } else {
            // If paused, play the video
            setState(() {
              _isPlaying = true;
              _videoController!.play();
              _showControls = true;
            });
            // Hide controls after 3 seconds
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _isPlaying) {
                setState(() {
                  _showControls = false;
                });
              }
            });
          }
        }
      },
      child: Container(
        height: _isFullscreen
            ? screenSize.height
            : isLandscape
                ? screenSize.height
                : screenSize.width * 9 / 16,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Video Player or Thumbnail
            if (_isVideoInitialized && _videoController != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video Player
                        VideoPlayer(_videoController!),
                        // Subtitle Display
                        if (_subtitlesEnabled &&
                            _videoController!.value.caption.text.isNotEmpty)
                          Positioned(
                            bottom:
                                _getSubtitleBottomPosition(), // Position calculated by helper method
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(
                                      0.6), // More transparent background
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _videoController!.value.caption.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize:
                                        _getSubtitleFontSize(), // Adaptive to orientation and fullscreen
                                    fontWeight: FontWeight.w500,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(
                                            0.3), // Even more transparent shadow
                                        offset: const Offset(1, 1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: double.infinity,
                child: video.calculatedThumbnailUrl != null
                    ? PresignedImage(
                        imageUrl: video.calculatedThumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                        errorWidget: Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.error,
                                color: Colors.white, size: 50),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.video_library,
                              color: Colors.white, size: 50),
                        ),
                      ),
              ),
            // Play/Pause Button or Loading indicator
            if (!_isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: _isVideoInitialized
                      ? const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 60,
                        )
                      : const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                ),
              ),
            Positioned(
              top: _isFullscreen
                  ? MediaQuery.of(context).padding.top
                  : 0, // Account for status bar in fullscreen
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _getControlPadding(),
                  vertical: _getControlVerticalPadding(),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () {
                        _showVideoOptions();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(
                      _getBottomControlPadding()), // Adaptive padding
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
                      // Progress Bar Row
                      Row(
                        children: [
                          // Current Time
                          Text(
                            _formatDuration(_currentPosition),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          // Progress Bar
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.red,
                                inactiveTrackColor:
                                    Colors.white.withOpacity(0.3),
                                thumbColor: Colors.red,
                                overlayColor: Colors.red.withOpacity(0.2),
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: _currentPosition.inSeconds
                                    .toDouble()
                                    .clamp(0.0,
                                        _totalDuration.inSeconds.toDouble()),
                                max: _totalDuration.inSeconds.toDouble() > 0
                                    ? _totalDuration.inSeconds.toDouble()
                                    : 1.0,
                                onChanged: (value) {
                                  if (_videoController != null) {
                                    final position =
                                        Duration(seconds: value.toInt());
                                    _videoController!.seekTo(position);
                                    setState(() {
                                      _currentPosition = position;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Total Time
                          Text(
                            _formatDuration(_totalDuration),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Control Buttons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Play/Pause Button
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size:
                                  _getButtonSize(), // Adaptive to orientation and fullscreen
                            ),
                            onPressed: () {
                              if (_videoController != null) {
                                setState(() {
                                  if (_isPlaying) {
                                    _isPlaying = false;
                                    _videoController!.pause();
                                  } else {
                                    _isPlaying = true;
                                    _videoController!.play();
                                  }
                                });
                              }
                            },
                          ),
                          SizedBox(
                              width: _getButtonSpacing()), // Adaptive spacing
                          // Volume Button
                          IconButton(
                            icon: Icon(
                              _videoController?.value.volume == 0
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: Colors.white,
                              size: _getButtonSize(
                                  small:
                                      true), // Adaptive to orientation and fullscreen
                            ),
                            onPressed: () {
                              if (_videoController != null) {
                                setState(() {
                                  if (_videoController!.value.volume == 0) {
                                    _videoController!.setVolume(1.0);
                                  } else {
                                    _videoController!.setVolume(0.0);
                                  }
                                });
                              }
                            },
                          ),
                          SizedBox(
                              width: _getButtonSpacing()), // Adaptive spacing
                          // Subtitle Button
                          if (_availableSubtitles.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                _subtitlesEnabled
                                    ? Icons.subtitles
                                    : Icons.subtitles_outlined,
                                color: _subtitlesEnabled
                                    ? Colors.blue
                                    : Colors.white,
                                size: _isFullscreen
                                    ? 28
                                    : 24, // Larger in fullscreen
                              ),
                              onPressed: _showSubtitleSelector,
                              tooltip: 'Subtitles',
                            ),
                          if (_availableSubtitles.isNotEmpty)
                            SizedBox(
                                width: _getButtonSpacing()), // Adaptive spacing
                          // Fullscreen Button
                          IconButton(
                            icon: Icon(
                              _isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                              size: _getButtonSize(
                                  small:
                                      true), // Adaptive to orientation and fullscreen
                            ),
                            onPressed: () {
                              setState(() {
                                _isFullscreen = !_isFullscreen;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(VideoModel video) {
    // Load follow status when video loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserFollowStatus(video.userId);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              context.go('/main/profile/${video.userId}');
            },
            child: SizedBox(
              key: ValueKey(
                  ((_authorAvatarUrl != null && _authorAvatarUrl!.isNotEmpty)
                              ? _authorAvatarUrl!
                              : (video.userAvatarUrl ?? ''))
                          .isNotEmpty
                      ? (_authorAvatarUrl ?? video.userAvatarUrl)!
                      : 'no-avatar-${video.userId}'),
              width: 50,
              height: 50,
              child: ((_authorAvatarUrl != null && _authorAvatarUrl!.isNotEmpty)
                          ? _authorAvatarUrl
                          : video.userAvatarUrl) !=
                      null
                  ? ClipOval(
                      child: PresignedImage(
                        imageUrl: (_authorAvatarUrl ?? video.userAvatarUrl)!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorWidget: const CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey,
                          child:
                              Icon(Icons.person, size: 30, color: Colors.white),
                        ),
                      ),
                    )
                  : const CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 30, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        video.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (video.isUserVerified == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: Colors.blue),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '173 followers', // TODO: Get real follower count from API
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed:
                _isLoadingFollow ? null : () => _toggleFollow(video.userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFollowing ? Colors.grey : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: _isLoadingFollow
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(_isFollowing ? 'Following' : 'Follow'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo(VideoModel video) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (video.description != null && video.description!.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              child: Text(
                video.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: _isDescriptionExpanded ? null : 3,
                overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
          if (video.tags != null && video.tags!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: video.tags!.map((tag) => _buildTag('#$tag')).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons(VideoModel video) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionItem(
            icon: Icons.visibility,
            count: _formatCount(_currentViews),
            label: 'views',
          ),
          _buildLikeActionItem(),
          _buildShareActionItem(),
          _buildActionItem(
            icon: Icons.download,
            count: _formatCount(_currentDownloads),
            label: 'downloads',
            onTap: () {
              _showDownloadOptions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLikeActionItem() {
    return GestureDetector(
      onTap: () => _toggleLike(widget.videoId),
      child: Column(
        children: [
          Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            size: 28,
            color: _isLiked ? Colors.red : Colors.grey[700],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCount(_currentLikes),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _isLiked ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareActionItem() {
    return GestureDetector(
      onTap: () => _showShareOptions(widget.videoId),
      child: Column(
        children: [
          Icon(
            Icons.share,
            size: 28,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCount(_currentShares),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  Widget _buildActionItem({
    required IconData icon,
    required String count,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.ads_click,
              size: 32,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              'Advertisement',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Tap to learn more',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedVideos() {
    final videosAsync = ref.watch(videoListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Recommended for you',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  context.go('/main');
                },
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        videosAsync.when(
          data: (videos) {
            // Filter out current video
            final recommendedVideos =
                videos.where((v) => v.id != widget.videoId).take(10).toList();

            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recommendedVideos.length,
                itemBuilder: (context, index) {
                  final video = recommendedVideos[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    child: _buildCompactVideoCard(video),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCompactVideoCard(VideoModel video) {
    return GestureDetector(
      onTap: () {
        context.go('/main/video/${video.id}/player');
      },
      child: Container(
        height: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: video.calculatedThumbnailUrl != null
                          ? PresignedImage(
                              imageUrl: video.calculatedThumbnailUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.video_library,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.video_library,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    // Play button
                    Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    // Duration
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              video.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Author info
            Row(
              children: [
                SizedBox(
                  key: ValueKey(
                      video.userAvatarUrl ?? 'no-avatar-${video.userId}'),
                  width: 16,
                  height: 16,
                  child: video.userAvatarUrl != null
                      ? ClipOval(
                          child: PresignedImage(
                            imageUrl: video.userAvatarUrl!,
                            width: 16,
                            height: 16,
                            fit: BoxFit.cover,
                            errorWidget: CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.grey[300],
                              child: Icon(Icons.person,
                                  size: 10, color: Colors.grey[600]),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.grey[300],
                          child: Icon(Icons.person,
                              size: 10, color: Colors.grey[600]),
                        ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    video.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return CommentsSection(
      videoId: widget.videoId,
      currentUserId: currentUser.id,
      currentUsername:
          currentUser.firstName != null && currentUser.lastName != null
              ? '${currentUser.firstName} ${currentUser.lastName}'
              : currentUser.username,
      currentUserAvatar: currentUser.avatarUrl ?? '',
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Video'),
              onTap: () {
                Navigator.pop(context);
                _showShareOptions(widget.videoId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download Video'),
              onTap: () {
                Navigator.pop(context);
                _showDownloadOptions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report Video'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(String videoId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share to',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOptionItem(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () => _shareToPlatform(videoId, 'facebook'),
                ),
                _buildShareOptionItem(
                  icon: Icons.alternate_email,
                  label: 'Twitter',
                  color: const Color(0xFF1DA1F2),
                  onTap: () => _shareToPlatform(videoId, 'twitter'),
                ),
                _buildShareOptionItem(
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  color: const Color(0xFFE4405F),
                  onTap: () => _shareToPlatform(videoId, 'instagram'),
                ),
                _buildShareOptionItem(
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareToPlatform(videoId, 'whatsapp'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOptionItem(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: Colors.grey[600]!,
                  onTap: () => _copyLink(videoId),
                ),
                _buildShareOptionItem(
                  icon: Icons.more_horiz,
                  label: 'More',
                  color: Colors.grey[600]!,
                  onTap: () => _shareToMore(videoId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOptionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToPlatform(String videoId, String platform) async {
    Navigator.pop(context);
    await _incrementShareCount(videoId, platform: platform);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shared to ${platform.toUpperCase()}!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyLink(String videoId) async {
    Navigator.pop(context);
    await _incrementShareCount(videoId, platform: 'copy');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareToMore(String videoId) async {
    Navigator.pop(context);
    await _incrementShareCount(videoId, platform: 'other');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening system share sheet...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDownloadOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Options'),
        content: const Text('Choose download quality:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadVideo('720p');
            },
            child: const Text('HD (720p)'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadVideo('480p');
            },
            child: const Text('SD (480p)'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVideo(String quality) async {
    // Increment download count
    await _incrementDownloadCount(widget.videoId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading video in $quality...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddToPlaylistDialog() async {
    try {
      // Fetch user's playlists
      final response = await _apiService.getUserPlaylists(page: 1, limit: 100);

      if (response['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(response['message'] ?? 'Failed to load playlists')),
          );
        }
        return;
      }

      final playlists = response['data'] as List<dynamic>;

      if (!mounted) return;

      if (playlists.isEmpty) {
        // Show dialog to create a new playlist
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Playlists Found'),
            content: const Text(
                'You don\'t have any playlists yet. Would you like to create one?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showCreatePlaylistDialog();
                },
                child: const Text('Create Playlist'),
              ),
            ],
          ),
        );
        return;
      }

      // Show playlist selection dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add to Playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length + 1,
              itemBuilder: (context, index) {
                if (index == playlists.length) {
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Create New Playlist'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog();
                    },
                  );
                }

                final playlist = playlists[index] as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist['name'] ?? 'Untitled'),
                  subtitle: Text('${playlist['videoCount'] ?? 0} videos'),
                  trailing: playlist['isPublic'] == false
                      ? const Icon(Icons.lock, size: 16)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await _addVideoToPlaylist(playlist['id'], playlist['name']);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading playlists: $e')),
        );
      }
    }
  }

  Future<void> _addVideoToPlaylist(
      String playlistId, String playlistName) async {
    try {
      final response = await _apiService.addVideoToPlaylist(
        playlistId: playlistId,
        videoId: widget.videoId,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added to "$playlistName"')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(response['message'] ?? 'Failed to add video')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Playlist Name',
                  hintText: 'Enter playlist name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter playlist description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isPublic,
                    onChanged: (value) {
                      setState(() {
                        isPublic = value ?? true;
                      });
                    },
                  ),
                  const Text('Public playlist'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a playlist name')),
                  );
                  return;
                }

                try {
                  final response = await _apiService.createPlaylist(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    isPublic: isPublic,
                  );

                  if (response['success'] == true) {
                    Navigator.pop(context);

                    // Ask if user wants to add the video to this new playlist
                    if (mounted) {
                      final shouldAdd = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Playlist Created'),
                          content: Text(
                              'Add this video to "${nameController.text.trim()}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );

                      if (shouldAdd == true && mounted) {
                        await _addVideoToPlaylist(
                          response['data']['id'],
                          nameController.text.trim(),
                        );
                      }
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(response['message'] ??
                                'Failed to create playlist')),
                      );
                    }
                  }
                } catch (e) {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating playlist: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
