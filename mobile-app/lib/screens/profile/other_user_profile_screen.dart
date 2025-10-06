import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/video_service.dart';
import '../../core/services/api_service.dart';
import '../../models/video_model.dart';
import '../../widgets/common/presigned_image.dart';

class OtherUserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherUserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<OtherUserProfileScreen> createState() =>
      _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends ConsumerState<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isLoading = false;
  bool _isBlocked = false;
  int _followersCount = 0;
  final VideoService _videoService = VideoService();
  final ApiService _apiService = ApiService();
  List<VideoModel> _userVideos = [];
  bool _isLoadingVideos = false;
  Map<String, dynamic>? _userProfile;
  DateTime? _lastLoadTime;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserProfile();
    _loadUserVideos();
  }

  Future<void> _loadUserProfile() async {
    if (_isLoadingProfile) return; // Prevent multiple simultaneous loads

    // Debounce: only load if we haven't loaded recently
    final now = DateTime.now();
    if (_lastLoadTime != null && now.difference(_lastLoadTime!).inSeconds < 2) {
      return;
    }

    _lastLoadTime = now;
    _isLoadingProfile = true;

    try {
      final response = await _apiService.getUserProfile(widget.userId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _userProfile = response['data'];
          _followersCount = response['data']['followersCount'] ?? 0;
          _isFollowing = response['data']['isFollowing'] ?? false;
          _isBlocked = response['data']['isBlocked'] ?? false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');

      // Check if it's a 401 authentication error
      if (e.toString().contains('Authentication required')) {
        if (mounted) {
          // Show user-friendly message and redirect to login
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
      }
    } finally {
      _isLoadingProfile = false;
    }
  }

  Future<void> _loadUserVideos() async {
    if (_isLoadingVideos) return; // Prevent multiple simultaneous loads

    setState(() {
      _isLoadingVideos = true;
    });

    try {
      final videos = await _videoService.getUserVideos(widget.userId);
      setState(() {
        _userVideos = videos;
      });
    } catch (e) {
      print('Error loading user videos: $e');
    } finally {
      setState(() {
        _isLoadingVideos = false;
      });
    }
  }

  // Helper method to handle 401 authentication errors
  Future<void> _handleAuthError() async {
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          _buildOtherUserHeader(),
          // Stats
          _buildOtherUserStats(),
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherUserHeader() {
    final username = _userProfile?['username'] ?? 'Loading...';
    final avatarUrl = _userProfile?['avatarUrl'];
    final bio = _userProfile?['bio'] ?? '';
    final isVerified = _userProfile?['isVerified'] ?? false;
    final isLoading = _userProfile == null;

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
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      _shareProfile(username);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      _showOtherUserOptions();
                    },
                  ),
                ],
              ),
            ),
            // Profile Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Profile Picture
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: isLoading
                        ? const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                              strokeWidth: 2,
                            ),
                          )
                        : (avatarUrl != null && avatarUrl.isNotEmpty
                            ? ClipOval(
                                child: PresignedImage(
                                  imageUrl: avatarUrl,
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
                              )),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      else ...[
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              color: Colors.white, size: 18),
                        ],
                      ],
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Follow/Unfollow Button
                  if (!_isBlocked)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _toggleFollow,
                      icon: Icon(
                        _isFollowing ? Icons.person_remove : Icons.person_add,
                        size: 16,
                      ),
                      label: Text(_isFollowing ? 'Following' : 'Follow'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isFollowing ? Colors.white : Colors.blue,
                        foregroundColor:
                            _isFollowing ? Colors.blue : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Blocked',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherUserStats() {
    final totalLikes =
        _userVideos.fold(0, (sum, video) => sum + video.likeCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(_userVideos.length.toString(), 'Videos'),
          _buildStatItem(_followersCount.toString(), 'Followers'),
          _buildStatItem('0', 'Following'),
          _buildStatItem(totalLikes.toString(), 'Likes'),
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This user hasn\'t created any posts yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLikedTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Liked videos are private',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This user has chosen to keep their liked videos private',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_play_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No public playlists',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This user hasn\'t created any public playlists',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFollow() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> response;
      if (_isFollowing) {
        response = await _apiService.unfollowUser(widget.userId);
      } else {
        response = await _apiService.followUser(widget.userId);
      }

      if (response['success'] == true) {
        // Update local state immediately for UI responsiveness
        setState(() {
          _isFollowing = !_isFollowing;
        });

        // Refresh user profile data to get accurate counts from server
        await _loadUserProfile();

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
        await _handleAuthError();
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
          _isLoading = false;
        });
      }
    }
  }

  void _shareProfile(String username) {
    Share.share(
      'Check out @$username on Blue Video App!\n\nProfile: bluevideoapp://profile/${widget.userId}',
      subject: 'Profile of $username',
    );
  }

  void _showOtherUserOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                final username = _userProfile?['username'] ?? 'User';
                _shareProfile(username);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report User'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(_isBlocked ? 'Unblock User' : 'Block User'),
              onTap: () {
                Navigator.pop(context);
                if (_isBlocked) {
                  _showUnblockDialog();
                } else {
                  _showBlockDialog();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    String selectedReason = 'Spam';
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please select a reason:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                  DropdownMenuItem(
                      value: 'Harassment', child: Text('Harassment')),
                  DropdownMenuItem(
                      value: 'Inappropriate Content',
                      child: Text('Inappropriate Content')),
                  DropdownMenuItem(
                      value: 'Fake Account', child: Text('Fake Account')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedReason = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              const Text('Additional details (optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Describe the issue...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _reportUser(selectedReason, descriptionController.text);
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportUser(String reason, String description) async {
    try {
      final response = await _apiService.reportUser(
        userId: widget.userId,
        reason: reason,
        description: description.isEmpty ? null : description,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['success'] == true
                ? 'User reported successfully'
                : response['message'] ?? 'Failed to report user'),
            backgroundColor:
                response['success'] == true ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error reporting user: $e');

      // Check if it's a 401 authentication error
      if (e.toString().contains('Authentication required')) {
        await _handleAuthError();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to report user'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
            'Are you sure you want to block this user? You won\'t see their content anymore.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser();
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      final response = await _apiService.blockUser(widget.userId);

      if (mounted) {
        if (response['success'] == true) {
          setState(() {
            _isBlocked = true;
            _isFollowing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User blocked successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to block user'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error blocking user: $e');

      // Check if it's a 401 authentication error
      if (e.toString().contains('Authentication required')) {
        await _handleAuthError();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to block user'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showUnblockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: const Text(
            'Are you sure you want to unblock this user? You will be able to see their content again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unblockUser();
            },
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser() async {
    try {
      final response = await _apiService.unblockUser(widget.userId);

      if (mounted) {
        if (response['success'] == true) {
          setState(() {
            _isBlocked = false;
          });

          // Refresh user profile data to get accurate counts
          await _loadUserProfile();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User unblocked successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to unblock user'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error unblocking user: $e');

      // Check if it's a 401 authentication error
      if (e.toString().contains('Authentication required')) {
        await _handleAuthError();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unblock user'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
