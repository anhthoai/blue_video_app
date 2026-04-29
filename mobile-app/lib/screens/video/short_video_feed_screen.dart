import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/file_url_service.dart';
import '../../core/services/video_service.dart';
import '../../models/video_model.dart';
import '../../utils/media_kit_low_latency.dart';
import '../../widgets/common/presigned_image.dart';

enum ShortVideoFeedScope { forYou, following }

class ShortVideoFeedQuery {
  final String? categoryId;
  final String sortBy;
  final ShortVideoFeedScope scope;
  final int limit;

  const ShortVideoFeedQuery({
    this.categoryId,
    this.sortBy = 'newest',
    this.scope = ShortVideoFeedScope.forYou,
    this.limit = 60,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ShortVideoFeedQuery &&
        other.categoryId == categoryId &&
        other.sortBy == sortBy &&
        other.scope == scope &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    return Object.hash(categoryId, sortBy, scope, limit);
  }
}

final shortVideoFeedProvider =
    FutureProvider.family<List<VideoModel>, ShortVideoFeedQuery>(
  (ref, query) async {
    final videoService = ref.watch(videoServiceProvider);
    final videos = await videoService.getVideos(
      limit: query.limit,
      category: query.categoryId,
      sortBy: query.sortBy,
    );

    if (query.scope == ShortVideoFeedScope.forYou) {
      return videos;
    }

    final apiService = ApiService();
    final userIds =
        videos.map((video) => video.userId).toSet().toList(growable: false);
    final followEntries = await Future.wait(
      userIds.map((userId) async {
        try {
          final response = await apiService.getUserProfile(userId);
          final data = response['data'];
          final isFollowing = response['success'] == true &&
              data is Map<String, dynamic> &&
              data['isFollowing'] == true;
          return MapEntry(userId, isFollowing);
        } catch (_) {
          return MapEntry(userId, false);
        }
      }),
    );

    final followedUserIds = <String>{
      for (final entry in followEntries)
        if (entry.value) entry.key,
    };

    return videos
        .where((video) => followedUserIds.contains(video.userId))
        .toList(growable: false);
  },
);

class ShortVideoFeedScreen extends StatelessWidget {
  final String? categoryId;
  final String sortBy;
  final ShortVideoFeedScope scope;

  const ShortVideoFeedScreen({
    super.key,
    this.categoryId,
    this.sortBy = 'newest',
    this.scope = ShortVideoFeedScope.forYou,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ShortVideoFeedView(
        query: ShortVideoFeedQuery(
          categoryId: categoryId,
          sortBy: sortBy,
          scope: scope,
        ),
        immersiveMode: true,
        showHeader: true,
        showBackButton: true,
      ),
    );
  }
}

class ShortVideoFeedView extends ConsumerStatefulWidget {
  final ShortVideoFeedQuery query;
  final bool immersiveMode;
  final bool showHeader;
  final bool showBackButton;

  const ShortVideoFeedView({
    super.key,
    required this.query,
    this.immersiveMode = false,
    this.showHeader = false,
    this.showBackButton = false,
  });

  @override
  ConsumerState<ShortVideoFeedView> createState() => _ShortVideoFeedViewState();
}

class _ShortVideoFeedViewState extends ConsumerState<ShortVideoFeedView> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.immersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (widget.immersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(shortVideoFeedProvider(widget.query));

    return ColoredBox(
      color: Colors.black,
      child: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return _buildEmptyState();
          }

          final safeIndex = _currentIndex.clamp(0, videos.length - 1);

          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                dragStartBehavior: DragStartBehavior.down,
                itemCount: videos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return _ShortVideoPage(
                    key: ValueKey('${video.id}-$index'),
                    video: video,
                    isActive: index == _currentIndex,
                    shouldPreload: index == _currentIndex + 1,
                    immersiveMode: widget.immersiveMode,
                  );
                },
              ),
              if (widget.showHeader)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        if (widget.showBackButton)
                          IconButton(
                            onPressed: () => context.pop(),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.28),
                            ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                        if (widget.showBackButton) const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.query.scope == ShortVideoFeedScope.forYou
                                    ? 'For You'
                                    : 'Following',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${safeIndex + 1}/${videos.length}  •  ${_labelForSort(widget.query.sortBy)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const _TopPillLabel(
                          icon: Icons.swipe_vertical_rounded,
                          label: 'Swipe up or down',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, stackTrace) {
          return _buildErrorState(error.toString());
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFollowing = widget.query.scope == ShortVideoFeedScope.following;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_collection_outlined,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                isFollowing
                    ? 'No videos from creators you follow yet.'
                    : 'No videos available for short mode yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isFollowing
                    ? 'Follow more creators or switch to For You.'
                    : 'Try again later or switch to Explore.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              if (widget.showBackButton) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back to Home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Short mode could not load videos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  ref.invalidate(shortVideoFeedProvider(widget.query));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortVideoPage extends ConsumerStatefulWidget {
  final VideoModel video;
  final bool isActive;
  final bool shouldPreload;
  final bool immersiveMode;

  const _ShortVideoPage({
    super.key,
    required this.video,
    required this.isActive,
    required this.shouldPreload,
    required this.immersiveMode,
  });

  @override
  ConsumerState<_ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends ConsumerState<_ShortVideoPage> {
  final ApiService _apiService = ApiService();
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  Timer? _likeBurstTimer;
  bool _isInitializing = false;
  bool _isReady = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _hasTrackedView = false;
  bool _showLikeBurst = false;
  bool _isScrubbing = false;
  bool _isFollowingCreator = false;
  bool _isLoadingFollow = false;
  Offset? _likeBurstOffset;
  Offset? _lastDoubleTapPosition;
  double? _scrubPositionMilliseconds;
  String? _followStatusLoadedForUserId;
  String? _errorMessage;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late int _likeCount;
  late int _shareCount;
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.likeCount;
    _shareCount = widget.video.shareCount;
    _isLiked = widget.video.isLiked;

    if ((widget.isActive || widget.shouldPreload) && !_isLockedVideo) {
      unawaited(_ensureVideoReady(autoPlay: widget.isActive));
    }

    unawaited(_loadCreatorFollowStatus());
  }

  @override
  void didUpdateWidget(covariant _ShortVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.video.id != widget.video.id) {
      _resetState();
      _likeCount = widget.video.likeCount;
      _shareCount = widget.video.shareCount;
      _isLiked = widget.video.isLiked;
      if ((widget.isActive || widget.shouldPreload) && !_isLockedVideo) {
        unawaited(_ensureVideoReady(autoPlay: widget.isActive));
      }
      unawaited(_loadCreatorFollowStatus());
      return;
    }

    if (!oldWidget.shouldPreload && widget.shouldPreload && !_isLockedVideo) {
      unawaited(_ensureVideoReady(autoPlay: false));
    }

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive && !_isLockedVideo) {
        if (_videoController == null) {
          unawaited(_ensureVideoReady(autoPlay: true));
        } else {
          unawaited(_player?.play());
          if (!_hasTrackedView) {
            unawaited(_incrementViewCount());
          }
        }
      } else {
        unawaited(_player?.pause());
      }
    }
  }

  @override
  void dispose() {
    _likeBurstTimer?.cancel();
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }

  bool get _isLockedVideo {
    final currentUser = ref.read(authServiceProvider).currentUser;
    final isUserVip = currentUser?.isVip ?? false;
    final needsVip =
        widget.video.requiresVIP && !isUserVip && !widget.video.isPaid;
    final needsPayment = widget.video.hasCost && !widget.video.isPaid;
    return needsVip || needsPayment;
  }

  bool get _canFollowCreator {
    final currentUserId = ref.read(authServiceProvider).currentUser?.id;
    return currentUserId != null && currentUserId != widget.video.userId;
  }

  Future<void> _loadCreatorFollowStatus() async {
    final creatorId = widget.video.userId;
    if (!_canFollowCreator || _followStatusLoadedForUserId == creatorId) {
      return;
    }

    try {
      final response = await _apiService.getUserProfile(creatorId);
      if (!mounted) {
        return;
      }

      final data = response['data'];
      if (response['success'] == true && data is Map<String, dynamic>) {
        setState(() {
          _isFollowingCreator = data['isFollowing'] == true;
          _followStatusLoadedForUserId = creatorId;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleCreatorFollow() async {
    if (!_canFollowCreator || _isLoadingFollow) {
      return;
    }

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      final response = _isFollowingCreator
          ? await _apiService.unfollowUser(widget.video.userId)
          : await _apiService.followUser(widget.video.userId);

      if (!mounted) {
        return;
      }

      if (response['success'] == true) {
        setState(() {
          _isFollowingCreator = !_isFollowingCreator;
          _followStatusLoadedForUserId = widget.video.userId;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  Future<void> _ensureVideoReady({required bool autoPlay}) async {
    if (_isInitializing || _videoController != null) {
      return;
    }

    if (widget.video.embedCode != null && widget.video.embedCode!.isNotEmpty) {
      setState(() {
        _errorMessage = 'Open this video in the full player.';
      });
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final playbackUrl = await _resolvePlaybackUrl(widget.video);
      if (!mounted) {
        return;
      }
      if (playbackUrl == null || playbackUrl.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Playback URL is not available for this video.';
        });
        return;
      }

      final player = Player();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          androidAttachSurfaceAfterVideoParameters: false,
        ),
      );
      _player = player;
      _videoController = controller;

      await _configurePlayback(player, playbackUrl);

      _playingSubscription = player.stream.playing.listen((playing) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPlaying = playing;
        });
      });

      _positionSubscription = player.stream.position.listen((position) {
        if (!mounted || _isScrubbing) {
          return;
        }
        setState(() {
          _currentPosition = position;
        });
      });

      _durationSubscription = player.stream.duration.listen((duration) {
        if (!mounted) {
          return;
        }
        setState(() {
          _totalDuration = duration;
        });
      });

      await player.open(Media(playbackUrl), play: autoPlay && widget.isActive);
      await player.setVolume(_isMuted ? 0 : 100);

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _isReady = true;
      });

      if (widget.isActive) {
        await _incrementViewCount();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Unable to start this video right now.';
      });
    }
  }

  Future<void> _configurePlayback(Player player, String playbackUrl) async {
    final preferLowLatency = shouldUseLowLatencyProfile(playbackUrl);

    try {
      final platform = player.platform;

      await applyMediaKitLowLatency(player, sourceUrl: playbackUrl);
      await (platform as dynamic).setProperty('ao', 'audiotrack,opensles');
      await (platform as dynamic).setProperty(
        'audio-normalize-downmix',
        'yes',
      );
      await (platform as dynamic).setProperty('audio-channels', 'stereo');
      await (platform as dynamic).setProperty(
        'cache',
        preferLowLatency ? 'no' : 'yes',
      );
      await (platform as dynamic).setProperty('cache-on-disk', 'no');
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
  }

  Future<String?> _resolvePlaybackUrl(VideoModel video) async {
    if (video.remotePlayUrl != null && video.remotePlayUrl!.isNotEmpty) {
      return video.remotePlayUrl;
    }

    if (video.fileName != null && video.fileDirectory != null) {
      final objectKey = 'videos/${video.fileDirectory}/${video.fileName}';
      return FileUrlService().getAccessibleUrl(objectKey);
    }

    if (video.videoUrl.isNotEmpty) {
      return video.videoUrl;
    }

    return null;
  }

  Future<void> _incrementViewCount() async {
    if (_hasTrackedView) {
      return;
    }

    try {
      final response = await _apiService.incrementVideoView(widget.video.id);
      if (response['success'] == true) {
        _hasTrackedView = true;
      }
    } catch (_) {
      _hasTrackedView = true;
    }
  }

  Future<void> _toggleLike({bool preferLikeOnly = false}) async {
    if (preferLikeOnly && _isLiked) {
      return;
    }

    try {
      final response = await _apiService.toggleVideoLike(widget.video.id);
      if (!mounted) {
        return;
      }

      final data = response['data'];
      if (response['success'] == true && data is Map<String, dynamic>) {
        setState(() {
          _likeCount = data['likes'] as int? ?? _likeCount;
          _isLiked = data['isLiked'] as bool? ?? !_isLiked;
        });
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (preferLikeOnly) {
        if (!_isLiked) {
          _isLiked = true;
          _likeCount += 1;
        }
        return;
      }

      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      if (_likeCount < 0) {
        _likeCount = 0;
      }
    });
  }

  Future<void> _handleDoubleTap() async {
    _triggerLikeBurst(_lastDoubleTapPosition);
    await _toggleLike(preferLikeOnly: true);
  }

  void _triggerLikeBurst(Offset? position) {
    _likeBurstTimer?.cancel();
    setState(() {
      _showLikeBurst = true;
      _likeBurstOffset = position;
    });

    _likeBurstTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showLikeBurst = false;
      });
    });
  }

  Future<void> _shareVideo() async {
    await SharePlus.instance.share(
      ShareParams(text: 'Check out "${widget.video.title}" on Blue Video'),
    );

    try {
      final response = await _apiService.incrementVideoShare(
        widget.video.id,
        platform: 'short_mode',
      );
      if (!mounted) {
        return;
      }
      final data = response['data'];
      if (response['success'] == true && data is Map<String, dynamic>) {
        setState(() {
          _shareCount = data['shares'] as int? ?? _shareCount;
        });
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _shareCount += 1;
    });
  }

  Future<void> _toggleMute() async {
    final player = _player;
    if (player == null) {
      return;
    }

    if (_isMuted) {
      await player.setVolume(100);
    } else {
      await player.setVolume(0);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _handleSeekChanged(double value) {
    if (_totalDuration.inMilliseconds <= 0) {
      return;
    }

    final clamped = value.clamp(0.0, _totalDuration.inMilliseconds.toDouble());
    setState(() {
      _isScrubbing = true;
      _scrubPositionMilliseconds = clamped;
      _currentPosition = Duration(milliseconds: clamped.round());
    });
  }

  Future<void> _handleSeekEnd(double value) async {
    final player = _player;
    final clamped = _totalDuration.inMilliseconds > 0
        ? value.clamp(0.0, _totalDuration.inMilliseconds.toDouble())
        : 0.0;
    final nextPosition = Duration(milliseconds: clamped.round());

    if (player != null) {
      await player.seek(nextPosition);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isScrubbing = false;
      _scrubPositionMilliseconds = null;
      _currentPosition = nextPosition;
    });
  }

  Future<void> _openFullPlayer() async {
    if (_player != null) {
      await _player!.pause();
    }
    if (widget.immersiveMode) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (!mounted) {
      return;
    }
    await context.push('/main/video/${widget.video.id}/player');
    if (!mounted || !widget.immersiveMode) {
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
  }

  void _resetState() {
    _likeBurstTimer?.cancel();
    _playingSubscription?.cancel();
    _playingSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription?.cancel();
    _durationSubscription = null;
    _player?.dispose();
    _player = null;
    _videoController = null;
    _errorMessage = null;
    _isInitializing = false;
    _isReady = false;
    _isPlaying = false;
    _isMuted = false;
    _hasTrackedView = false;
    _showLikeBurst = false;
    _likeBurstOffset = null;
    _isScrubbing = false;
    _isFollowingCreator = false;
    _isLoadingFollow = false;
    _scrubPositionMilliseconds = null;
    _followStatusLoadedForUserId = null;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final likeOffset = _likeBurstOffset ??
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2.2);
        final captionMaxWidth = constraints.maxWidth * 0.78;

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaSurface(),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.58),
                      ],
                      stops: const [0.0, 0.18, 0.56, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (_showLikeBurst)
              Positioned(
                left: (likeOffset.dx - 48).clamp(20.0, constraints.maxWidth - 96.0),
                top: (likeOffset.dy - 48).clamp(60.0, constraints.maxHeight - 180.0),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showLikeBurst ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedScale(
                      scale: _showLikeBurst ? 1.0 : 0.6,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 96,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              bottom: 10,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionBubble(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      label: _formatCount(_likeCount),
                      color: _isLiked ? const Color(0xFFFF5C83) : Colors.white,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 6),
                    _ActionBubble(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: _formatCount(widget.video.commentCount),
                      color: Colors.white,
                      onTap: _openFullPlayer,
                    ),
                    const SizedBox(height: 6),
                    _ActionBubble(
                      icon: Icons.share_outlined,
                      label: _formatCount(_shareCount),
                      color: Colors.white,
                      onTap: _shareVideo,
                    ),
                    const SizedBox(height: 6),
                    _ActionBubble(
                      icon: _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      label: _isMuted ? 'Muted' : 'Sound',
                      color: Colors.white,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(height: 6),
                    _ActionBubble(
                      icon: Icons.open_in_new_rounded,
                      label: 'Open',
                      color: Colors.white,
                      onTap: _openFullPlayer,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 8,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 6),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: captionMaxWidth),
                  child: _BottomVideoCaption(
                    video: widget.video,
                    canFollow: _canFollowCreator,
                    isFollowing: _isFollowingCreator,
                    isLoadingFollow: _isLoadingFollow,
                    onFollowTap: _toggleCreatorFollow,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 4),
                child: _BottomSeekBar(
                  value: _seekPositionMilliseconds,
                  max: _maxSeekMilliseconds,
                  onChanged: _handleSeekChanged,
                  onChangeEnd: _handleSeekEnd,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double get _maxSeekMilliseconds {
    if (_totalDuration.inMilliseconds <= 0) {
      return 1;
    }
    return _totalDuration.inMilliseconds.toDouble();
  }

  double get _seekPositionMilliseconds {
    final current = _isScrubbing
        ? (_scrubPositionMilliseconds ?? _currentPosition.inMilliseconds.toDouble())
        : _currentPosition.inMilliseconds.toDouble();
    return current.clamp(0.0, _maxSeekMilliseconds);
  }

  Widget _buildMediaSurface() {
    if (_isLockedVideo) {
      return _buildFallbackSurface(
        title: widget.video.hasCost ? 'Unlock to watch' : 'VIP only',
        subtitle: widget.video.hasCost
            ? '${widget.video.cost} coins required for full playback.'
            : 'Open the full player to preview or unlock this video.',
      );
    }

    if (_isReady && _videoController != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (details) {
          _lastDoubleTapPosition = details.localPosition;
        },
        onDoubleTap: _handleDoubleTap,
        onTap: () async {
          final player = _player;
          if (player == null) {
            return;
          }
          if (_isPlaying) {
            await player.pause();
          } else {
            await player.play();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Video(
                  controller: _videoController!,
                  controls: AdaptiveVideoControls,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (!_isPlaying)
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_isInitializing) {
      return _buildLoadingSurface();
    }

    if (_errorMessage != null) {
      return _buildFallbackSurface(
        title: 'Open in full player',
        subtitle: _errorMessage!,
      );
    }

    return _buildLoadingSurface();
  }

  Widget _buildLoadingSurface() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailBackdrop(),
        const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildFallbackSurface({
    required String title,
    required String subtitle,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailBackdrop(),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.44),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _openFullPlayer,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Full Player'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailBackdrop() {
    final thumbnailUrl = widget.video.calculatedThumbnailUrl;
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Icon(
            Icons.video_library_rounded,
            color: Colors.white54,
            size: 62,
          ),
        ),
      );
    }

    return PresignedImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorWidget: Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 48,
          ),
        ),
      ),
    );
  }
}

class _BottomVideoCaption extends StatelessWidget {
  final VideoModel video;
  final bool canFollow;
  final bool isFollowing;
  final bool isLoadingFollow;
  final Future<void> Function() onFollowTap;

  const _BottomVideoCaption({
    required this.video,
    required this.canFollow,
    required this.isFollowing,
    required this.isLoadingFollow,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    final tags = video.tags ?? const <String>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: ClipOval(
                  child: video.userAvatarUrl != null &&
                          video.userAvatarUrl!.isNotEmpty
                      ? PresignedImage(
                          imageUrl: video.userAvatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.white24,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white24,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '@${video.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canFollow) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: isLoadingFollow ? null : onFollowTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isFollowing
                          ? Colors.white.withValues(alpha: 0.16)
                          : const Color(0xFFFF2F63),
                      shape: BoxShape.circle,
                    ),
                    child: isLoadingFollow
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            isFollowing
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
              if (video.cost > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${video.cost} coins',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (video.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              video.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.32,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _MetaChip(
                icon: Icons.play_arrow_rounded,
                label: video.formattedViewCount,
              ),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: video.formattedDuration,
              ),
              if (video.category != null && video.category!.isNotEmpty)
                _MetaChip(
                  icon: Icons.category_outlined,
                  label: video.category!,
                ),
              ...tags.take(1).map((tag) => _MetaChip(label: '#$tag')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomSeekBar extends StatelessWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _BottomSeekBar({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
        thumbColor: Colors.white,
      ),
      child: Slider(
        min: 0,
        max: max,
        value: value.clamp(0.0, max),
        onChanged: max > 1 ? onChanged : null,
        onChangeEnd: max > 1 ? onChangeEnd : null,
      ),
    );
  }
}

class _ActionBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;

  const _ActionBubble({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _MetaChip({
    this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 11),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPillLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopPillLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

String _labelForSort(String sortBy) {
  switch (sortBy) {
    case 'trending':
      return 'Trending';
    case 'topRated':
      return 'Top Rated';
    case 'mostViewed':
      return 'Most Viewed';
    case 'random':
      return 'Random';
    default:
      return 'Newest';
  }
}
