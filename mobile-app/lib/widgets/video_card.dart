import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/social/like_button.dart';
import '../widgets/social/share_button.dart';
import '../widgets/social/comments_section.dart';
import '../models/like_model.dart';
import 'common/presigned_image.dart';
import '../core/services/api_service.dart';
import '../l10n/app_localizations.dart';

class VideoCard extends ConsumerWidget {
  final String videoId;
  final String? title;
  final String? thumbnailUrl;
  final String? duration;
  final int? viewCount;
  final int? likeCount;
  final String? authorName;
  final String? authorAvatar;
  final String? authorId;
  final String? currentUserId;
  final String? currentUsername;
  final String? currentUserAvatar;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onComment;
  final bool isLiked;
  final int commentCount;
  final int shareCount;

  const VideoCard({
    super.key,
    required this.videoId,
    this.title,
    this.thumbnailUrl,
    this.duration,
    this.viewCount,
    this.likeCount,
    this.authorName,
    this.authorAvatar,
    this.authorId,
    this.currentUserId,
    this.currentUsername,
    this.currentUserAvatar,
    this.onTap,
    this.onAuthorTap,
    this.onLike,
    this.onShare,
    this.onComment,
    this.isLiked = false,
    this.commentCount = 0,
    this.shareCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            _buildVideoThumbnail(context),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title ?? 'Sample Video Title',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // User Info
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onAuthorTap,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: authorAvatar != null
                              ? ClipOval(
                                  child: PresignedImage(
                                    imageUrl: authorAvatar,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorWidget: const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey,
                                      child: Icon(
                                        Icons.person,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                )
                              : const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey,
                                  child: Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authorName ?? 'Username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatViewCount(viewCount, context),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      if (currentUserId != null)
                        LikeButton(
                          targetId: videoId,
                          type: LikeType.video,
                          userId: currentUserId!,
                          initialLikeCount: likeCount ?? 0,
                          initialIsLiked: isLiked,
                          size: 20,
                          showCount: true,
                        )
                      else
                        _buildActionButton(
                          context,
                          icon:
                              isLiked ? Icons.favorite : Icons.favorite_border,
                          label: _formatCount(likeCount ?? 0),
                          onTap: onLike,
                          color: isLiked ? Colors.red : null,
                        ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () {
                          if (currentUserId != null &&
                              currentUsername != null &&
                              currentUserAvatar != null) {
                            _showCommentsSection(context);
                          } else {
                            onComment?.call();
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.comment_outlined, size: 20),
                            const SizedBox(width: 4),
                            Text(_formatCount(commentCount)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      if (currentUserId != null)
                        ShareButton(
                          contentId: videoId,
                          contentType: 'video',
                          userId: currentUserId!,
                          shareCount: shareCount,
                          size: 20,
                          showCount: true,
                        )
                      else
                        _buildActionButton(
                          context,
                          icon: Icons.share_outlined,
                          label: _formatCount(shareCount),
                          onTap: onShare,
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          _showMoreOptions(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // Thumbnail Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: PresignedImage(
              imageUrl: thumbnailUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.video_library,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          // Duration Overlay (bottom-right corner)
          if (duration != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  duration!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Play Button Overlay
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color ?? Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ],
        ),
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

  String _formatViewCount(int? count, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (count == null || count == 0) return '0 ${l10n.views}';
    final formatted = _formatCount(count);
    return '$formatted ${l10n.views}';
  }

  void _showCommentsSection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsSection(
        videoId: videoId,
        currentUserId: currentUserId!,
        currentUsername: currentUsername!,
        currentUserAvatar: currentUserAvatar!,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Builder(builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentUserId != null)
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: Text(l10n.addToPlaylist),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddToPlaylistDialog(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(l10n.saveVideo),
                onTap: () {
                  Navigator.pop(context);
                  // Handle save
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.download),
                onTap: () {
                  Navigator.pop(context);
                  // Handle download
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: Text(l10n.report),
                onTap: () {
                  Navigator.pop(context);
                  // Handle report
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.share),
                onTap: () {
                  Navigator.pop(context);
                  // Handle share
                },
              ),
            ],
          );
        }),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context) async {
    final apiService = ApiService();

    try {
      // Fetch user's playlists
      final response = await apiService.getUserPlaylists(page: 1, limit: 100);

      if (response['success'] != true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(response['message'] ?? 'Failed to load playlists')),
          );
        }
        return;
      }

      final playlists = response['data'] as List<dynamic>;

      if (!context.mounted) return;

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
                  _showCreatePlaylistDialog(context, apiService);
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
                      _showCreatePlaylistDialog(context, apiService);
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
                    await _addVideoToPlaylist(
                        context, apiService, playlist['id'], playlist['name']);
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading playlists: $e')),
        );
      }
    }
  }

  Future<void> _addVideoToPlaylist(
    BuildContext context,
    ApiService apiService,
    String playlistId,
    String playlistName,
  ) async {
    try {
      final response = await apiService.addVideoToPlaylist(
        playlistId: playlistId,
        videoId: videoId,
      );

      if (context.mounted) {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCreatePlaylistDialog(BuildContext context, ApiService apiService) {
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
                  final response = await apiService.createPlaylist(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    isPublic: isPublic,
                  );

                  if (response['success'] == true) {
                    Navigator.pop(context);

                    // Ask if user wants to add the video to this new playlist
                    if (context.mounted) {
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

                      if (shouldAdd == true && context.mounted) {
                        await _addVideoToPlaylist(
                          context,
                          apiService,
                          response['data']['id'],
                          nameController.text.trim(),
                        );
                      }
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(response['message'] ??
                                'Failed to create playlist')),
                      );
                    }
                  }
                } catch (e) {
                  Navigator.pop(context);
                  if (context.mounted) {
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
