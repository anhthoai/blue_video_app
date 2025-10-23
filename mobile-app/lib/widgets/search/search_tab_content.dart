import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/video_card.dart';
import '../../widgets/common/presigned_image.dart';

class SearchTabContent extends ConsumerStatefulWidget {
  final String query;
  final String contentType;

  const SearchTabContent({
    super.key,
    required this.query,
    required this.contentType,
  });

  @override
  ConsumerState<SearchTabContent> createState() => _SearchTabContentState();
}

class _SearchTabContentState extends ConsumerState<SearchTabContent> {
  final ApiService _apiService = ApiService();
  List<dynamic> _results = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(SearchTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.contentType != widget.contentType) {
      _search();
    }
  }

  Future<void> _search() async {
    if (widget.query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<dynamic> results = [];

      switch (widget.contentType) {
        case 'Video':
          results = await _searchVideos();
          break;
        case 'Library':
          results = await _searchLibrary();
          break;
        case 'Posts':
          results = await _searchPosts();
          break;
        case 'User':
          results = await _searchUsers();
          break;
        case 'Comics':
          results = await _searchComics();
          break;
        case 'Gallery':
          results = await _searchGallery();
          break;
        case 'Novel':
          results = await _searchNovels();
          break;
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _searchVideos() async {
    final response = await _apiService.searchVideos(widget.query);
    return response['data'] ?? [];
  }

  Future<List<dynamic>> _searchLibrary() async {
    // For now, return empty - implement when library feature is ready
    return [];
  }

  Future<List<dynamic>> _searchPosts() async {
    final response = await _apiService.searchPosts(widget.query);
    print('🔍 Search posts response: ${response['success']}');
    if (response['data'] != null) {
      final posts = List<dynamic>.from(response['data']);
      print('📝 Found ${posts.length} posts');
      for (int i = 0; i < posts.length; i++) {
        final post = posts[i];
        print('📝 Post $i: ${post['title']} - Images: ${post['imageUrls']}');
      }
    }
    return response['data'] ?? [];
  }

  Future<List<dynamic>> _searchUsers() async {
    final response = await _apiService.searchUsers(widget.query,
        page: _currentPage, limit: 20);
    return response['data'] ?? [];
  }

  Future<List<dynamic>> _searchComics() async {
    // For now, return empty - implement when comics feature is ready
    return [];
  }

  Future<List<dynamic>> _searchGallery() async {
    // For now, return empty - implement when gallery feature is ready
    return [];
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<List<dynamic>> _searchNovels() async {
    // For now, return empty - implement when novels feature is ready
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _search,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.contentType.toLowerCase()} found for "${widget.query}"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return _buildContent();
  }

  Widget _buildContent() {
    switch (widget.contentType) {
      case 'Video':
        return _buildVideoResults();
      case 'Posts':
        return _buildPostResults();
      case 'User':
        return _buildUserResults();
      default:
        return _buildGenericResults();
    }
  }

  Widget _buildVideoResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final video = _results[index];
        return VideoCard(
          videoId: video['id']?.toString() ?? '',
          title: video['title']?.toString() ?? '',
          thumbnailUrl: video['thumbnailUrl']?.toString(),
          duration: video['duration']?.toString() ?? '0:00',
          viewCount: _parseInt(video['views']),
          likeCount: _parseInt(video['likes']),
          commentCount: _parseInt(video['comments']) ?? 0,
          shareCount: _parseInt(video['shares']) ?? 0,
          authorName: video['username']?.toString() ?? '',
          authorAvatar: video['userAvatarUrl']?.toString(),
          currentUserId: ref.watch(authServiceProvider).currentUser?.id ?? '',
          currentUsername:
              ref.watch(authServiceProvider).currentUser?.username ?? '',
          currentUserAvatar:
              ref.watch(authServiceProvider).currentUser?.avatarUrl ?? '',
          onTap: () {
            context.go('/main/video/${video['id']}/player');
          },
          onAuthorTap: () {
            context.go('/main/profile/${video['userId']}');
          },
        );
      },
    );
  }

  Widget _buildPostResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final post = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: post['userAvatarUrl'] != null
                          ? NetworkImage(
                              post['userAvatarUrl']?.toString() ?? '')
                          : null,
                      child: post['userAvatarUrl'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['username'] ?? 'Unknown User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            post['createdAt'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (post['content'] != null &&
                    post['content'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      post['content'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                // Display media in grid layout (like original posts)
                if ((post['imageUrls'] != null &&
                        (post['imageUrls'] as List).isNotEmpty) ||
                    (post['videoUrls'] != null &&
                        (post['videoUrls'] as List).isNotEmpty))
                  _buildMediaGrid(post),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.favorite_border,
                        size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${post['likes'] ?? 0}'),
                    const SizedBox(width: 16),
                    Icon(Icons.comment_outlined,
                        size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${post['comments'] ?? 0}'),
                    const SizedBox(width: 16),
                    Icon(Icons.share_outlined,
                        size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${post['shares'] ?? 0}'),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      context.go('/main/post/${post['id']}');
                    },
                    child: const Text('View Post'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: user['avatarUrl'] != null
                  ? NetworkImage(user['avatarUrl']?.toString() ?? '')
                  : null,
              child:
                  user['avatarUrl'] == null ? const Icon(Icons.person) : null,
            ),
            title: Text(
              user['username'] ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              user['firstName'] != null && user['lastName'] != null
                  ? '${user['firstName']} ${user['lastName']}'
                  : user['bio'] ?? '',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                // Follow user functionality
              },
              child: const Text('Follow'),
            ),
            onTap: () {
              context.go('/main/profile/${user['id']}');
            },
          ),
        );
      },
    );
  }

  Widget _buildGenericResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(item['title'] ?? item['name'] ?? 'Unknown'),
            subtitle: Text(item['description'] ?? ''),
            onTap: () {
              // Handle item tap
            },
          ),
        );
      },
    );
  }

  // Build media grid layout (like original posts)
  Widget _buildMediaGrid(Map<String, dynamic> post) {
    // Combine all media items
    final allMedia = <Map<String, dynamic>>[];

    // Add images
    if (post['imageUrls'] != null) {
      for (int i = 0; i < (post['imageUrls'] as List).length; i++) {
        print('🖼️ Search Post Image $i: ${(post['imageUrls'] as List)[i]}');
        allMedia.add({
          'type': 'image',
          'url': (post['imageUrls'] as List)[i],
          'index': i,
        });
      }
    }

    // Add videos
    if (post['videoUrls'] != null) {
      for (int i = 0; i < (post['videoUrls'] as List).length; i++) {
        print('🎬 Search Post Video $i: ${(post['videoUrls'] as List)[i]}');
        allMedia.add({
          'type': 'video',
          'url': (post['videoUrls'] as List)[i],
          'thumbnailUrl': (post['videoThumbnailUrls'] as List).length > i
              ? (post['videoThumbnailUrls'] as List)[i]
              : null,
          'index': i,
        });
      }
    }

    if (allMedia.isEmpty) return const SizedBox.shrink();

    // Determine layout based on media count
    if (allMedia.length == 1) {
      return _buildSingleMedia(allMedia[0]);
    } else if (allMedia.length == 2) {
      return _buildTwoMedia(allMedia);
    } else if (allMedia.length == 3) {
      return _buildThreeMedia(allMedia);
    } else {
      return _buildMultipleMedia(allMedia);
    }
  }

  Widget _buildSingleMedia(Map<String, dynamic> media) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildMediaItem(media),
      ),
    );
  }

  Widget _buildTwoMedia(List<Map<String, dynamic>> allMedia) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaItem(allMedia[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaItem(allMedia[1]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(List<Map<String, dynamic>> allMedia) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaItem(allMedia[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildMediaItem(allMedia[1]),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildMediaItem(allMedia[2]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleMedia(List<Map<String, dynamic>> allMedia) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaItem(allMedia[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildMediaItem(allMedia[1]),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildMediaItem(allMedia[2]),
                      ),
                      if (allMedia.length > 3)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '+${allMedia.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(Map<String, dynamic> media) {
    if (media['type'] == 'image') {
      return Image.network(
        media['url']?.toString() ?? '',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('🖼️ Image load error: $error');
          return Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    } else {
      // Video
      final thumbnailUrl = media['thumbnailUrl'];
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            Image.network(
              thumbnailUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.video_library,
                    color: Colors.grey,
                  ),
                );
              },
            )
          else
            Container(
              color: Colors.grey[300],
              child: const Icon(
                Icons.video_library,
                color: Colors.grey,
              ),
            ),
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      );
    }
  }
}
