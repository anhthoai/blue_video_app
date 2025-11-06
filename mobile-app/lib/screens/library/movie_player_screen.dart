import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie_model.dart';
import '../../core/services/movie_service.dart';
import '../../l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
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

      // Add listener for position updates and auto-play next episode
      _videoController!.addListener(() {
        if (mounted && _videoController != null) {
          setState(() {
            _currentPosition = _videoController!.value.position;
            _totalDuration = _videoController!.value.duration;
          });

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
                    child: SafeArea(
                      top: false,
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
                                vertical: 4, horizontal: 12),
                          ),

                          // Time and controls
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
                            child: Row(
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
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Container(
                  width: 90,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                    border: isCurrentEpisode
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                  ),
                  child: episode.thumbnailUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                episode.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.movie,
                                  color: Colors.grey,
                                ),
                              ),
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
                        )
                      : const Icon(Icons.movie, color: Colors.grey),
                ),
                title: Text(
                  episode.title ?? 'Episode ${episode.episodeNumber}',
                  style: TextStyle(
                    fontWeight:
                        isCurrentEpisode ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12,
                    color: isCurrentEpisode ? Colors.red : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: episode.duration != null
                    ? Text(
                        episode.formattedDuration,
                        style: TextStyle(
                          fontSize: 11,
                          color: isCurrentEpisode
                              ? Colors.red[700]
                              : Colors.grey[600],
                        ),
                      )
                    : null,
                onTap: isCurrentEpisode ? null : () => _loadEpisode(episode),
              ),
            );
          }),
        ],
      ),
    );
  }
}
