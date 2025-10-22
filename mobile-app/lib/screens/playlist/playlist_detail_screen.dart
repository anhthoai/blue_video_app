import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../models/video_model.dart';
import '../../widgets/video_card.dart';
import '../../widgets/common/presigned_image.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String playlistName;
  final String? playlistDescription;
  final String? playlistThumbnail;
  final bool isPublic;
  final int videoCount;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
    this.playlistDescription,
    this.playlistThumbnail,
    this.isPublic = true,
    this.videoCount = 0,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final ApiService _apiService = ApiService();
  List<VideoModel> _playlistVideos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylistVideos();
  }

  Future<void> _loadPlaylistVideos() async {
    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getPlaylistVideos(
        playlistId: widget.playlistId,
        page: _page,
        limit: 20,
      );

      if (response['success'] == true && response['data'] != null) {
        final videos = (response['data'] as List<dynamic>)
            .map((v) => VideoModel.fromJson(v as Map<String, dynamic>))
            .toList();

        // Update playlist info if available (including auto-generated thumbnail)
        if (response['playlistInfo'] != null && _page == 1) {
          final playlistInfo = response['playlistInfo'] as Map<String, dynamic>;
          // Update the widget's thumbnail if it's different from the auto-generated one
          if (playlistInfo['thumbnailUrl'] != null &&
              playlistInfo['thumbnailUrl'] != widget.playlistThumbnail) {
            // Note: We can't directly update the widget's thumbnail here,
            // but the backend will return the correct thumbnail in future calls
          }
        }

        setState(() {
          if (_page == 1) {
            _playlistVideos = videos;
          } else {
            _playlistVideos.addAll(videos);
          }
          _hasMore = videos.length == 20;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading playlist videos: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _page++;
    });

    await _loadPlaylistVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share playlist
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share playlist coming soon')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  // TODO: Implement edit playlist
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit playlist coming soon')),
                  );
                  break;
                case 'delete':
                  _showDeletePlaylistDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Playlist'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Playlist',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlistVideos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    _page = 1;
                    _hasMore = true;
                    await _loadPlaylistVideos();
                  },
                  child: CustomScrollView(
                    slivers: [
                      // Playlist Header
                      SliverToBoxAdapter(
                        child: _buildPlaylistHeader(),
                      ),

                      // Videos List
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < _playlistVideos.length) {
                              final video = _playlistVideos[index];
                              return VideoCard(
                                videoId: video.id,
                                title: video.title,
                                thumbnailUrl: video.calculatedThumbnailUrl,
                                duration: video.formattedDuration,
                                viewCount: video.viewCount,
                                likeCount: video.likeCount,
                                authorName: video.displayName,
                                authorAvatar: video.userAvatarUrl,
                                authorId: video.userId,
                                currentUserId:
                                    'current_user_id', // TODO: Get from auth
                                currentUsername:
                                    'current_username', // TODO: Get from auth
                                currentUserAvatar:
                                    'current_avatar', // TODO: Get from auth
                                isLiked: video.isLiked,
                                commentCount: video.commentCount,
                                shareCount: video.shareCount,
                                onTap: () {
                                  context
                                      .push('/main/video/${video.id}/player');
                                },
                              );
                            } else if (_hasMore) {
                              _loadMoreVideos();
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return null;
                          },
                          childCount:
                              _playlistVideos.length + (_hasMore ? 1 : 0),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPlaylistHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Playlist Thumbnail
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
                child: _getPlaylistThumbnail(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlistName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (widget.playlistDescription != null) ...[
                      Text(
                        widget.playlistDescription!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(
                          widget.isPublic ? Icons.public : Icons.lock,
                          size: 16,
                          color: widget.isPublic ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isPublic ? 'Public' : 'Private',
                          style: TextStyle(
                            color:
                                widget.isPublic ? Colors.green : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${_playlistVideos.length} videos',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No videos in this playlist',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add videos to this playlist to see them here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.pop();
              },
              icon: const Icon(Icons.explore),
              label: const Text('Discover Videos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getPlaylistThumbnail() {
    // Use custom thumbnail if available
    if (widget.playlistThumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PresignedImage(
          imageUrl: widget.playlistThumbnail!,
          fit: BoxFit.cover,
          errorWidget: _buildDefaultThumbnail(),
        ),
      );
    }

    // Use first video's thumbnail if available
    if (_playlistVideos.isNotEmpty &&
        _playlistVideos.first.calculatedThumbnailUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PresignedImage(
          imageUrl: _playlistVideos.first.calculatedThumbnailUrl!,
          fit: BoxFit.cover,
          errorWidget: _buildDefaultThumbnail(),
        ),
      );
    }

    // Default thumbnail
    return _buildDefaultThumbnail();
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.playlist_play,
        size: 40,
        color: Colors.grey,
      ),
    );
  }

  void _showDeletePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text(
            'Are you sure you want to delete "${widget.playlistName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete playlist
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete playlist coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
