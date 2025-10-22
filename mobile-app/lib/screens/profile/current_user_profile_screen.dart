import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/video_service.dart';
import '../../core/services/api_service.dart';
import '../../models/video_model.dart';
import '../../models/community_post.dart';
import '../../widgets/common/presigned_image.dart';
import '../../widgets/community/community_post_widget.dart';

class CurrentUserProfileScreen extends ConsumerStatefulWidget {
  const CurrentUserProfileScreen({super.key});

  @override
  ConsumerState<CurrentUserProfileScreen> createState() =>
      _CurrentUserProfileScreenState();
}

class _CurrentUserProfileScreenState
    extends ConsumerState<CurrentUserProfileScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final VideoService _videoService = VideoService();
  final ApiService _apiService = ApiService();
  List<VideoModel> _userVideos = [];
  bool _isLoadingVideos = false;
  // Posts
  List<CommunityPost> _userPosts = [];
  bool _isLoadingPosts = false;
  // Liked videos
  List<VideoModel> _likedVideos = [];
  bool _isLoadingLiked = false;
  // Playlists
  List<Map<String, dynamic>> _userPlaylists = [];
  bool _isLoadingPlaylists = false;
  DateTime? _lastReloadTime;
  bool _isReloading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserVideos();
    _loadUserPosts();
    _loadLikedVideos();
    WidgetsBinding.instance.addObserver(this);

    // Listen for user data changes
    final authService = ref.read(authServiceProvider);
    authService.addListener(_onUserDataChanged);

    // Add tab change listener to load data when switching tabs
    _tabController.addListener(() {
      if (_tabController.index == 1 && _userPosts.isEmpty && !_isLoadingPosts) {
        _loadUserPosts();
      } else if (_tabController.index == 2 &&
          _likedVideos.isEmpty &&
          !_isLoadingLiked) {
        _loadLikedVideos();
      } else if (_tabController.index == 3 &&
          _userPlaylists.isEmpty &&
          !_isLoadingPlaylists) {
        _loadUserPlaylists();
      }
    });
  }

  void _onUserDataChanged() {
    if (mounted && !_isReloading) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only reload if we haven't reloaded recently (debounce)
      final now = DateTime.now();
      if (_lastReloadTime == null ||
          now.difference(_lastReloadTime!).inSeconds > 5) {
        _lastReloadTime = now;
        _reloadUserData();
      }
    }
  }

  void _reloadUserData() async {
    if (_isReloading) return; // Prevent multiple simultaneous reloads

    _isReloading = true;
    try {
      // Force reload user from SharedPreferences
      final authService = ref.read(authServiceProvider);
      await authService.reloadCurrentUser();
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isReloading = false;
    }
  }

  Future<void> _loadUserVideos() async {
    setState(() {
      _isLoadingVideos = true;
    });

    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      if (currentUser != null) {
        final videos = await _videoService.getUserVideos(currentUser.id);
        setState(() {
          _userVideos = videos;
        });
      }
    } catch (e) {
      print('Error loading user videos: $e');
    } finally {
      setState(() {
        _isLoadingVideos = false;
      });
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      if (currentUser != null) {
        print('Loading posts for user: ${currentUser.id}');
        final response = await _apiService.getUserCommunityPosts(
          userId: currentUser.id,
          page: 1,
          limit: 20,
        );
        print('Posts API response: $response');
        if (response['success'] == true && response['data'] != null) {
          final items = response['data'] as List<dynamic>;
          print('Found ${items.length} posts');
          final posts = items.map<CommunityPost>((json) {
            return CommunityPost(
              id: json['id'] ?? '',
              userId: json['userId'] ?? '',
              username: json['username'] ?? 'User',
              firstName: json['firstName'],
              lastName: json['lastName'],
              isVerified: json['isVerified'] ?? false,
              userAvatar: json['userAvatar'] ?? '',
              title: json['title'],
              content: json['content'] ?? '',
              type: _mapPostType(json['type']),
              images: List<String>.from(json['images'] ?? const []),
              videos: List<String>.from(json['videos'] ?? const []),
              imageUrls: (json['imageUrls'] as List<dynamic>?)
                      ?.map((url) => url is String ? url : '')
                      .where((url) => url.isNotEmpty)
                      .toList() ??
                  const [],
              videoUrls: (json['videoUrls'] as List<dynamic>?)
                      ?.map((url) => url is String ? url : '')
                      .where((url) => url.isNotEmpty)
                      .toList() ??
                  const [],
              videoThumbnailUrls: (json['videoThumbnailUrls'] as List<dynamic>?)
                      ?.map((url) => url is String ? url : '')
                      .where((url) => url.isNotEmpty)
                      .toList() ??
                  const [],
              duration: List<String>.from(json['duration'] ?? const []),
              videoUrl: null,
              linkUrl: json['linkUrl'],
              linkTitle: json['linkTitle'],
              linkDescription: json['linkDescription'],
              linkThumbnail: json['linkThumbnail'],
              pollData: json['pollOptions'],
              tags: List<String>.from(json['tags'] ?? const []),
              category: json['category'],
              likes: json['likes'] ?? 0,
              comments: json['comments'] ?? 0,
              shares: json['shares'] ?? 0,
              views: json['views'] ?? 0,
              isLiked: json['isLiked'] ?? false,
              isBookmarked: json['isBookmarked'] ?? false,
              isPinned: json['isPinned'] ?? false,
              isNsfw: json['isNsfw'] ?? false,
              isFeatured: json['isFeatured'] ?? false,
              cost: json['cost'] ?? 0,
              requiresVip: json['requiresVip'] ?? false,
              isUnlocked: true,
              createdAt:
                  DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
              publishedAt:
                  DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
            );
          }).toList();
          setState(() {
            _userPosts = posts;
          });
        } else {
          print('Posts API failed: ${response['message']}');
        }
      }
    } catch (e) {
      print('Error loading user posts: $e');
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _loadLikedVideos() async {
    setState(() {
      _isLoadingLiked = true;
    });

    try {
      print('Loading liked videos...');
      final response = await _apiService.getUserLikedVideos(page: 1, limit: 50);
      print('Liked videos API response: $response');
      if (response['success'] == true && response['data'] != null) {
        final items = response['data'] as List<dynamic>;
        print('Found ${items.length} liked videos');
        final videos = items
            .map<VideoModel>(
                (v) => VideoModel.fromJson(v as Map<String, dynamic>))
            .toList();
        setState(() {
          _likedVideos = videos;
        });
      } else {
        print('Liked videos API failed: ${response['message']}');
      }
    } catch (e) {
      print('Error loading liked videos: $e');
    } finally {
      setState(() {
        _isLoadingLiked = false;
      });
    }
  }

  Future<void> _loadUserPlaylists() async {
    setState(() {
      _isLoadingPlaylists = true;
    });

    try {
      print('Loading user playlists...');
      final response = await _apiService.getUserPlaylists(page: 1, limit: 50);
      print('Playlists API response: $response');
      if (response['success'] == true && response['data'] != null) {
        final items = response['data'] as List<dynamic>;
        print('Found ${items.length} playlists');
        final playlists = items
            .map<Map<String, dynamic>>((p) => p as Map<String, dynamic>)
            .toList();
        setState(() {
          _userPlaylists = playlists;
        });
      } else {
        print('Playlists API failed: ${response['message']}');
      }
    } catch (e) {
      print('Error loading user playlists: $e');
    } finally {
      setState(() {
        _isLoadingPlaylists = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final authService = ref.read(authServiceProvider);
    authService.removeListener(_onUserDataChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view profile'),
        ),
      );
    }

    return Scaffold(
      key: ValueKey(
          'profile_${currentUser.id}'), // Force rebuild when user changes
      body: Column(
        children: [
          // Header
          _buildCurrentUserHeader(currentUser),
          // Stats
          _buildCurrentUserStats(),
          // Wallet quick actions (Coin Recharge / History)
          _buildWalletQuickActions(),
          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.video_library, size: 24),
                text: 'Videos',
                height: 60,
              ),
              Tab(
                icon: Icon(Icons.post_add, size: 24),
                text: 'Posts',
                height: 60,
              ),
              Tab(
                icon: Icon(Icons.favorite, size: 24),
                text: 'Liked',
                height: 60,
              ),
              Tab(
                icon: Icon(Icons.playlist_play, size: 24),
                text: 'Playlists',
                height: 60,
              ),
              Tab(
                icon: Icon(Icons.analytics, size: 24),
                text: 'Analytics',
                height: 60,
              ),
            ],
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideosTab(),
                _buildPostsTab(),
                _buildLikedTab(),
                _buildPlaylistsTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletQuickActions() {
    final user = ref.read(authServiceProvider).currentUser;
    final coinBalance = user?.coinBalance ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          // Balance pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on,
                    color: Color(0xFF8B5CF6), size: 16),
                const SizedBox(width: 4),
                Text(
                  '$coinBalance coins',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _WalletActionButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Recharge',
            onTap: () => context.push('/main/coin-recharge'),
          ),
          const SizedBox(width: 8),
          _WalletActionButton(
            icon: Icons.receipt_long_outlined,
            label: 'History',
            onTap: () => context.push('/main/coin-history'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserHeader(user) {
    return Container(
      key: ValueKey('header_${user.id}'), // Force rebuild when user changes
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1976D2),
            Color(0xFF42A5F5),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.qr_code, color: Colors.white),
                    onPressed: () => _showQRCode(user),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => _shareProfile(user),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white),
                    onPressed: () {
                      context.go('/main/settings');
                    },
                  ),
                ],
              ),
            ),
            // Profile Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  // Profile Picture with Edit Button
                  Stack(
                    children: [
                      SizedBox(
                        key: ValueKey(user.avatarUrl ?? 'no-avatar'),
                        width: 80,
                        height: 80,
                        child:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                ? ClipOval(
                                    child: PresignedImage(
                                      imageUrl: user.avatarUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorWidget: const CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  )
                                : const CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            context.push('/main/profile/edit');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        key: ValueKey('username_${user.id}'),
                        user.username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: Colors.white, size: 16),
                      ],
                    ],
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      key: ValueKey('bio_${user.id}'),
                      user.bio!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Edit Profile Button
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/main/profile/edit');
                    },
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 28),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUserStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(_userVideos.length.toString(), 'Videos'),
          _buildStatItem('0', 'Followers'),
          _buildStatItem('0', 'Following'),
          _buildStatItem(_calculateTotalLikes().toString(), 'Likes'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab() {
    if (_isLoadingVideos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No videos yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/main/upload');
              },
              icon: const Icon(Icons.add),
              label: const Text('Upload Video'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _userVideos.length,
      itemBuilder: (context, index) {
        final video = _userVideos[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              context.push('/main/video/${video.id}/player');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      video.calculatedThumbnailUrl != null
                          ? PresignedImage(
                              imageUrl: video.calculatedThumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: Colors.grey[300],
                                child:
                                    const Icon(Icons.video_library, size: 48),
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.video_library, size: 48),
                            ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          onSelected: (value) {
                            if (value == 'add_to_playlist') {
                              _showAddToPlaylistDialog(video.id, video.title);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'add_to_playlist',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add, size: 20),
                                  SizedBox(width: 8),
                                  Text('Add to Playlist'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.formattedViewCount,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsTab() {
    if (_isLoadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userPosts.isEmpty) {
      return SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/main/community/create-post');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Post'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _loadUserPosts();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Posts'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentUser = ref.read(authServiceProvider).currentUser;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserPosts();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _userPosts.length,
        itemBuilder: (context, index) {
          final post = _userPosts[index];
          return CommunityPostWidget(
            post: post,
            currentUserId: currentUser?.id,
            currentUsername: currentUser?.username,
            currentUserAvatar: currentUser?.avatarUrl ?? '',
            onTap: () => context.push('/main/post/${post.id}'),
            onUserTap: () {},
          );
        },
      ),
    );
  }

  Widget _buildLikedTab() {
    if (_isLoadingLiked) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_likedVideos.isEmpty) {
      return SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No liked videos yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Videos you like will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _loadLikedVideos();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Liked Videos'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadLikedVideos();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _likedVideos.length,
        itemBuilder: (context, index) {
          final video = _likedVideos[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                context.push('/main/video/${video.id}/player');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        video.calculatedThumbnailUrl != null
                            ? PresignedImage(
                                imageUrl: video.calculatedThumbnailUrl!,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  color: Colors.grey[300],
                                  child:
                                      const Icon(Icons.video_library, size: 48),
                                ),
                              )
                            : Container(
                                color: Colors.grey[300],
                                child:
                                    const Icon(Icons.video_library, size: 48),
                              ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            onSelected: (value) {
                              if (value == 'add_to_playlist') {
                                _showAddToPlaylistDialog(video.id, video.title);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'add_to_playlist',
                                child: Row(
                                  children: [
                                    Icon(Icons.playlist_add, size: 20),
                                    SizedBox(width: 8),
                                    Text('Add to Playlist'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      video.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PostType _mapPostType(dynamic type) {
    final t =
        (type is String) ? type.toUpperCase() : type?.toString().toUpperCase();
    switch (t) {
      case 'TEXT':
        return PostType.text;
      case 'LINK':
        return PostType.link;
      case 'POLL':
        return PostType.poll;
      case 'MEDIA':
      default:
        return PostType.media;
    }
  }

  Widget _buildPlaylistsTab() {
    if (_isLoadingPlaylists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userPlaylists.isEmpty) {
      return SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.playlist_play_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No playlists yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first playlist',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _showCreatePlaylistDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Playlist'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _loadUserPlaylists();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Playlists'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await _loadUserPlaylists();
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: _userPlaylists.length,
            itemBuilder: (context, index) {
              final playlist = _userPlaylists[index];
              return _buildPlaylistCard(playlist);
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showCreatePlaylistDialog,
            child: const Icon(Icons.add),
            tooltip: 'Create Playlist',
          ),
        ),
      ],
    );
  }

  void _showAddToPlaylistDialog(String videoId, String videoTitle) async {
    final currentVideoId = videoId; // Store in local variable
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
                    await _addVideoToPlaylist(playlist['id'], playlist['name'],
                        videoId: currentVideoId);
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

  Future<void> _addVideoToPlaylist(String playlistId, String playlistName,
      {String? videoId}) async {
    try {
      final response = await _apiService.addVideoToPlaylist(
        playlistId: playlistId,
        videoId: videoId ?? '',
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

  Widget _buildPlaylistThumbnail(Map<String, dynamic> playlist) {
    // Use custom thumbnail if available
    if (playlist['thumbnailUrl'] != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: PresignedImage(
          imageUrl: playlist['thumbnailUrl'],
          fit: BoxFit.cover,
          errorWidget: _buildDefaultPlaylistThumbnail(),
        ),
      );
    }

    // Default thumbnail
    return _buildDefaultPlaylistThumbnail();
  }

  Widget _buildDefaultPlaylistThumbnail() {
    return const Center(
      child: Icon(Icons.playlist_play, size: 48, color: Colors.grey),
    );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Playlist created successfully!')),
                    );
                    _loadUserPlaylists(); // Refresh the list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(response['message'] ??
                              'Failed to create playlist')),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating playlist: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          context.push('/main/playlist/${playlist['id']}', extra: {
            'playlistName': playlist['name'],
            'playlistDescription': playlist['description'],
            'playlistThumbnail': playlist['thumbnailUrl'],
            'isPublic': playlist['isPublic'],
            'videoCount': playlist['videoCount'],
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playlist thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey[200],
                ),
                child: _buildPlaylistThumbnail(playlist),
              ),
            ),
            // Playlist info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist['name'] ?? 'Untitled Playlist',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${playlist['videoCount'] ?? 0} videos',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (playlist['isPublic'] == false)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'Private',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  Widget _buildAnalyticsTab() {
    final totalViews =
        _userVideos.fold(0, (sum, video) => sum + video.viewCount);
    final totalLikes = _calculateTotalLikes();
    final totalComments =
        _userVideos.fold(0, (sum, video) => sum + video.commentCount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAnalyticsCard('Total Views', totalViews.toString(),
            Icons.visibility, Colors.blue),
        const SizedBox(height: 12),
        _buildAnalyticsCard(
            'Total Likes', totalLikes.toString(), Icons.favorite, Colors.red),
        const SizedBox(height: 12),
        _buildAnalyticsCard('Total Comments', totalComments.toString(),
            Icons.comment, Colors.green),
        const SizedBox(height: 12),
        _buildAnalyticsCard('Videos', _userVideos.length.toString(),
            Icons.video_library, Colors.orange),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement Rate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildEngagementMetric(
                    'Likes per Video',
                    _userVideos.isNotEmpty
                        ? (totalLikes / _userVideos.length).toStringAsFixed(1)
                        : '0'),
                const SizedBox(height: 8),
                _buildEngagementMetric(
                    'Comments per Video',
                    _userVideos.isNotEmpty
                        ? (totalComments / _userVideos.length)
                            .toStringAsFixed(1)
                        : '0'),
                const SizedBox(height: 8),
                _buildEngagementMetric(
                    'Views per Video',
                    _userVideos.isNotEmpty
                        ? (totalViews / _userVideos.length).toStringAsFixed(0)
                        : '0'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementMetric(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _WalletActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCode(user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan to View Profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: 'bluevideoapp://profile/${user.id}',
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '@${user.username}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Save QR coming soon')),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Save'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareProfile(user) {
    Share.share(
      'Check out @${user.username} on Blue Video App!\n\nProfile: bluevideoapp://profile/${user.id}',
      subject: 'Profile of ${user.username}',
    );
  }

  int _calculateTotalLikes() {
    return _userVideos.fold(0, (sum, video) => sum + video.likeCount);
  }
}

// class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
//   final TabBar _tabBar;

//   _SliverAppBarDelegate(this._tabBar);

//   @override
//   double get minExtent => _tabBar.preferredSize.height;
//   @override
//   double get maxExtent => _tabBar.preferredSize.height;

//   @override
//   Widget build(
//       BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return Container(
//       color: Theme.of(context).scaffoldBackgroundColor,
//       child: _tabBar,
//     );
//   }

//   @override
//   bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
//     return false;
//   }
// }
