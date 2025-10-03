import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/video_service.dart';
import '../../models/video_model.dart';

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
  List<VideoModel> _userVideos = [];
  bool _isLoadingVideos = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserVideos();
    WidgetsBinding.instance.addObserver(this);

    // Listen for user data changes
    final authService = ref.read(authServiceProvider);
    authService.addListener(_onUserDataChanged);
  }

  void _onUserDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload user data when app comes back to foreground
      _reloadUserData();
    }
  }

  void _reloadUserData() async {
    // Force reload user from SharedPreferences
    final authService = ref.read(authServiceProvider);
    await authService.reloadCurrentUser();
    if (mounted) {
      setState(() {});
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
      body: Column(
        children: [
          // Header
          _buildCurrentUserHeader(currentUser),
          // Stats
          _buildCurrentUserStats(),
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

  Widget _buildCurrentUserHeader(user) {
    return Container(
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
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
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
                      video.thumbnailUrl != null &&
                              video.thumbnailUrl!.isNotEmpty
                          ? Image.network(
                              video.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add_outlined, size: 64, color: Colors.grey[400]),
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
        ],
      ),
    );
  }

  Widget _buildLikedTab() {
    return Center(
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
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play_outlined, size: 64, color: Colors.grey[400]),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playlist creation coming soon')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Playlist'),
          ),
        ],
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
