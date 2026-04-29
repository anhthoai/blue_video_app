import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/community_hub_provider.dart';
import '../../core/providers/unlocked_posts_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/community_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_hub_models.dart';
import '../../models/community_post.dart';
import '../../widgets/community/community_hub_primitives.dart';
import '../../widgets/community/community_post_widget.dart';
import '../../widgets/community/video_card_widget.dart';
import '../../widgets/dialogs/coin_payment_dialog.dart';
import '_fullscreen_media_gallery.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  _CommunityTopTab _selectedTopTab = _CommunityTopTab.original;
  _CommunityFeedTab _selectedFeedTab = _CommunityFeedTab.recommended;
  _FollowingSection _selectedFollowingSection = _FollowingSection.topics;
  _RequestSection _selectedRequestSection = _RequestSection.latest;
  String _requestQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityHubProvider.notifier).ensureLoaded();
      _clearTagPostsAndLoadPosts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearTagPostsAndLoadPosts() {
    ref.read(communityServiceStateProvider.notifier).clearTagPosts();
    _loadPosts();
    _loadTrendingPosts();
    _loadTags();
  }

  Future<void> _loadPosts() async {
    try {
      await ref.read(communityServiceStateProvider.notifier).loadPosts();
    } catch (e) {
      debugPrint('Error loading community posts: $e');
    }
  }

  Future<void> _loadTags() async {
    await ref.read(communityServiceStateProvider.notifier).loadTags();
  }

  Future<void> _loadTrendingPosts() async {
    try {
      await ref.read(communityServiceStateProvider.notifier).loadTrendingPosts();
    } catch (e) {
      debugPrint('Error loading trending posts: $e');
    }
  }

  Future<void> _refreshOriginalTab() async {
    await Future.wait([
      ref.read(communityHubProvider.notifier).refresh(),
      _loadPosts(),
      _loadTrendingPosts(),
      _loadTags(),
    ]);
  }

  Future<void> _refreshFollowingTab() async {
    await Future.wait([
      ref.read(communityHubProvider.notifier).refresh(),
      _loadPosts(),
      _loadTrendingPosts(),
    ]);
  }

  Future<void> _refreshRequestTab() async {
    await ref.read(communityHubProvider.notifier).refresh();
  }

  void _openVideoPlayer(CommunityPost post) {
    if (post.videoUrls.isEmpty) return;

    if (post.cost > 0 || post.requiresVip) {
      _showPaymentDialog(post);
      return;
    }

    final mediaItems = <MediaItem>[];
    for (final videoUrl in post.videoUrls) {
      mediaItems.add(MediaItem(url: videoUrl, isVideo: true));
    }

    if (mediaItems.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenMediaGallery(
          mediaItems: mediaItems,
          initialIndex: 0,
        ),
      ),
    );
  }

  void _showPaymentDialog(CommunityPost post) {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser != null && currentUser.id == post.userId) {
      _openMediaAfterPayment(post);
      return;
    }

    final isUnlockedInMemory =
        ref.read(unlockedPostsProvider.notifier).isPostUnlocked(post.id);
    if (post.isUnlocked || isUnlockedInMemory) {
      _openMediaAfterPayment(post);
      return;
    }

    if (post.requiresVip) {
      VipPaymentDialog.show(
        context,
        onPaymentSuccess: () {
          _openMediaAfterPayment(post);
        },
        authorId: post.userId,
        authorName: post.firstName ?? post.username,
        authorAvatar: post.userAvatar,
      );
      return;
    }

    CoinPaymentDialog.show(
      context,
      coinCost: post.cost,
      postId: post.id,
      onPaymentSuccess: () {
        _openMediaAfterPayment(post);
      },
    );
  }

  void _openMediaAfterPayment(CommunityPost post) {
    final mediaItems = <MediaItem>[];
    for (final videoUrl in post.videoUrls) {
      mediaItems.add(MediaItem(url: videoUrl, isVideo: true));
    }

    if (mediaItems.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenMediaGallery(
          mediaItems: mediaItems,
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final communityState = ref.watch(communityServiceStateProvider);
    final authState = ref.watch(authServiceProvider);
    final hubState = ref.watch(communityHubProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(child: _buildPrimaryTabs()),
                  IconButton(
                    onPressed: _handleSearchPressed,
                    icon: const Icon(Icons.search_rounded),
                    iconSize: 30,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildTabBody(
                hubState: hubState,
                communityState: communityState,
                authState: authState,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedTopTab == _CommunityTopTab.request
            ? _createRequest
            : _createPost,
        heroTag: 'community_action_${_selectedTopTab.name}',
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: Icon(
          _selectedTopTab == _CommunityTopTab.request
              ? Icons.add_comment_rounded
              : Icons.add_rounded,
        ),
      ),
    );
  }

  Widget _buildPrimaryTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildPrimaryTabButton(
          label: 'Following',
          tab: _CommunityTopTab.following,
        ),
        _buildPrimaryTabButton(
          label: 'Original',
          tab: _CommunityTopTab.original,
        ),
        _buildPrimaryTabButton(
          label: 'Request',
          tab: _CommunityTopTab.request,
        ),
      ],
    );
  }

  Widget _buildPrimaryTabButton({
    required String label,
    required _CommunityTopTab tab,
  }) {
    final isSelected = _selectedTopTab == tab;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTopTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppTheme.primaryColor : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 30 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody({
    required CommunityHubState hubState,
    required CommunityServiceState communityState,
    required AuthService authState,
  }) {
    switch (_selectedTopTab) {
      case _CommunityTopTab.following:
        return _buildFollowingTab(hubState, communityState, authState);
      case _CommunityTopTab.original:
        return _buildOriginalTab(hubState, communityState, authState);
      case _CommunityTopTab.request:
        return _buildRequestTab(hubState);
    }
  }

  Widget _buildOriginalTab(
    CommunityHubState hubState,
    CommunityServiceState communityState,
    AuthService authState,
  ) {
    final posts = _feedPostsForCurrentFilter(communityState);

    return RefreshIndicator(
      onRefresh: _refreshOriginalTab,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
        children: [
          _buildSectionHeader(
            title: 'Hot Forums',
            actionText: 'More',
            onAction: () => context.push('/main/forums/hot'),
          ),
          const SizedBox(height: 14),
          if (hubState.isLoading && hubState.forums.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hubState.forums.isEmpty)
            _buildMessagePanel(
              icon: Icons.forum_outlined,
              title: 'No forums available yet',
              subtitle: 'Pull to refresh after the community hub finishes loading.',
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hubState.forums.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildForumCard(hubState.forums[index]);
                },
              ),
            ),
          const SizedBox(height: 18),
          _buildCreatorStrip(
            title: 'Content Creators',
            creators: hubState.creators.take(3).toList(),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSelectorChip(
                  label: 'Recommended',
                  selected: _selectedFeedTab == _CommunityFeedTab.recommended,
                  onTap: () {
                    setState(() {
                      _selectedFeedTab = _CommunityFeedTab.recommended;
                    });
                  },
                ),
                _buildSelectorChip(
                  label: 'Newest',
                  selected: _selectedFeedTab == _CommunityFeedTab.newest,
                  onTap: () {
                    setState(() {
                      _selectedFeedTab = _CommunityFeedTab.newest;
                    });
                  },
                ),
                _buildSelectorChip(
                  label: 'Highlights',
                  selected: _selectedFeedTab == _CommunityFeedTab.highlights,
                  onTap: () {
                    setState(() {
                      _selectedFeedTab = _CommunityFeedTab.highlights;
                    });
                  },
                ),
                _buildSelectorChip(
                  label: 'Videos',
                  selected: _selectedFeedTab == _CommunityFeedTab.videos,
                  onTap: () {
                    setState(() {
                      _selectedFeedTab = _CommunityFeedTab.videos;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (communityState.isLoading && posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (posts.isEmpty)
            _buildMessagePanel(
              icon: Icons.forum_outlined,
              title: 'No original posts yet',
              subtitle: 'Create the first community post or pull to refresh.',
            )
          else
            ...posts.map((post) {
              if (_selectedFeedTab == _CommunityFeedTab.videos) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: VideoCardWidget(
                    post: post,
                    onTap: () => _openVideoPlayer(post),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: CommunityPostWidget(
                  post: post,
                  currentUserId: authState.currentUser?.id,
                  currentUsername: authState.currentUser?.username,
                  currentUserAvatar: authState.currentUser?.avatarUrl ?? '',
                  onTap: () {
                    context.push('/main/post/${post.id}', extra: post);
                  },
                  onUserTap: () {
                    context.go('/main/profile/${post.userId}');
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFollowingTab(
    CommunityHubState hubState,
    CommunityServiceState communityState,
    AuthService authState,
  ) {
    final followedForums = hubState.followedForums;
    final followedCreators = hubState.followedCreators;
    final followedPosts =
        communityState.posts.where((post) => post.isFollowing).toList();

    return RefreshIndicator(
      onRefresh: _refreshFollowingTab,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
        children: [
          _buildCreatorStrip(
            title: 'Upload Masters',
            creators: followedCreators.isEmpty
                ? hubState.creators.take(3).toList()
                : followedCreators.take(3).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildSelectorChip(
                label: 'Topics',
                selected: _selectedFollowingSection == _FollowingSection.topics,
                onTap: () {
                  setState(() {
                    _selectedFollowingSection = _FollowingSection.topics;
                  });
                },
              ),
              _buildSelectorChip(
                label: 'Users',
                selected: _selectedFollowingSection == _FollowingSection.users,
                onTap: () {
                  setState(() {
                    _selectedFollowingSection = _FollowingSection.users;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedFollowingSection == _FollowingSection.topics) ...[
            if (followedForums.isEmpty)
              _buildMessagePanel(
                icon: Icons.favorite_outline_rounded,
                title: 'Nothing here, click to retry',
                subtitle:
                    'Follow a forum from the Original tab to keep its updates here.',
              )
            else
              ...followedForums.map((forum) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFollowedForumTile(forum),
                );
              }),
          ] else ...[
            if (followedCreators.isNotEmpty)
              SizedBox(
                height: 184,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: followedCreators.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildCreatorProfileCard(followedCreators[index]);
                  },
                ),
              ),
            if (followedCreators.isNotEmpty) const SizedBox(height: 18),
            if (followedPosts.isEmpty)
              _buildMessagePanel(
                icon: Icons.people_outline_rounded,
                title: 'Nothing here, click to retry',
                subtitle:
                    'Follow a user to see their latest posts and uploads.',
              )
            else
              ...followedPosts.map((post) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CommunityPostWidget(
                    post: post,
                    currentUserId: authState.currentUser?.id,
                    currentUsername: authState.currentUser?.username,
                    currentUserAvatar: authState.currentUser?.avatarUrl ?? '',
                    onTap: () {
                      context.push('/main/post/${post.id}', extra: post);
                    },
                    onUserTap: () {
                      context.go('/main/profile/${post.userId}');
                    },
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestTab(CommunityHubState hubState) {
    final filteredRequests = _filteredRequests(hubState);
    final rankingEntries = _requestRankingEntries(hubState);

    return RefreshIndicator(
      onRefresh: _refreshRequestTab,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
        children: [
          Row(
            children: [
              _buildSelectorChip(
                label: 'Latest',
                selected: _selectedRequestSection == _RequestSection.latest,
                onTap: () {
                  setState(() {
                    _selectedRequestSection = _RequestSection.latest;
                  });
                },
              ),
              _buildSelectorChip(
                label: 'Highlights',
                selected: _selectedRequestSection == _RequestSection.highlights,
                onTap: () {
                  setState(() {
                    _selectedRequestSection = _RequestSection.highlights;
                  });
                },
              ),
              _buildSelectorChip(
                label: 'Ranking',
                selected: _selectedRequestSection == _RequestSection.ranking,
                onTap: () {
                  setState(() {
                    _selectedRequestSection = _RequestSection.ranking;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Ask for a specific clip, set the coin bounty, then let other users upload files or attach search links. Linked search results are free for the contributor.',
              style: TextStyle(
                height: 1.45,
                color: Color(0xFF556274),
              ),
            ),
          ),
          if (_requestQuery.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF3FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Searching requests for "$_requestQuery"',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _requestQuery = '';
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (hubState.isLoading && hubState.requests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selectedRequestSection == _RequestSection.ranking)
            if (rankingEntries.isEmpty)
              _buildMessagePanel(
                icon: Icons.emoji_events_outlined,
                title: 'No ranking data yet',
                subtitle:
                    'Accepted request matches will start filling this board.',
              )
            else
              ...List.generate(rankingEntries.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRankingTile(rankingEntries[index], index + 1),
                );
              })
          else if (filteredRequests.isEmpty)
            _buildMessagePanel(
              icon: Icons.search_off_rounded,
              title: 'No requests matched this search',
              subtitle:
                  'Try a different keyword or create a new bounty request.',
            )
          else
            ...filteredRequests.map((request) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildRequestCard(request),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
      ],
    );
  }

  Widget _buildForumCard(CommunityForum forum) {
    final startColor = _parseForumColor(
      forum.accentStart,
      const Color(0xFF4F7DFF),
    );
    final endColor = _parseForumColor(
      forum.accentEnd,
      const Color(0xFF5FD4FF),
    );

    return InkWell(
      onTap: () => context.push('/main/forums/${forum.id}'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 238,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: <Color>[startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: startColor.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    forum.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    ref.read(communityHubProvider.notifier).toggleForumFollow(forum.id);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: forum.isFollowing
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.18),
                    foregroundColor: forum.isFollowing ? startColor : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    forum.isFollowing ? 'Following' : '+ Follow',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              forum.subtitle,
              style: const TextStyle(
                color: Colors.white,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${formatCompactNumber(forum.postCount)} posts',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorStrip({
    required String title,
    required List<CommunityCreator> creators,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, color: Color(0xFFFFBE33)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...creators.map((creator) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: _openContentCreatorScreen,
                child: CommunityAvatar(
                  name: creator.displayName,
                  avatarUrl: creator.avatarUrl,
                  radius: 20,
                ),
              ),
            );
          }),
          IconButton(
            onPressed: _openContentCreatorScreen,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE9F2FF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.primaryColor : const Color(0xFF4D596D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagePanel({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFFC2CAD7)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowedForumTile(CommunityForum forum) {
    final startColor = _parseForumColor(
      forum.accentStart,
      const Color(0xFF4F7DFF),
    );
    final endColor = _parseForumColor(
      forum.accentEnd,
      const Color(0xFF5FD4FF),
    );

    return InkWell(
      onTap: () => context.push('/main/forums/${forum.id}'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: <Color>[startColor, endColor],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.forum_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    forum.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatCompactNumber(forum.postCount)} posts',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    forum.subtitle,
                    style: const TextStyle(color: Color(0xFF516075)),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {
                ref.read(communityHubProvider.notifier).toggleForumFollow(forum.id);
              },
              child: const Text('Following'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorProfileCard(CommunityCreator creator) {
    return Container(
      width: 178,
      height: 184,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityAvatar(
                name: creator.displayName,
                avatarUrl: creator.avatarUrl,
                radius: 24,
              ),
              const Spacer(),
              IconButton(
                onPressed: _openContentCreatorScreen,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            creator.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatCompactNumber(creator.followers)} followers',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ref
                    .read(communityHubProvider.notifier)
                    .toggleCreatorFollow(creator.id);
              },
              child: Text(creator.isFollowing ? 'Following' : '+ Follow'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(CommunityRequest request) {
    final previewHints = request.previewHints
        .map((hint) => hint.trim())
        .where((hint) => hint.isNotEmpty)
        .take(3)
        .toList();
    final referenceImages = request.referenceImageUrls.take(4).toList();
    final requestContent = _requestPrimaryContent(request);

    return InkWell(
      onTap: () => context.push('/main/request/${request.id}'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CommunityAvatar(
                  name: request.authorName,
                  avatarUrl: request.authorAvatarUrl,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.authorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatCompactNumber(request.wantCount)} watching',
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(communityHubProvider.notifier).toggleWantRequest(request.id);
                  },
                  icon: Icon(
                    request.isWantedByCurrentUser
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 18,
                  ),
                  label: Text(
                    request.isWantedByCurrentUser ? 'Watching' : 'Want to see',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: request.isFeatured
                        ? const Color(0xFFFFF1E6)
                        : const Color(0xFFF1F5FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.boardLabel,
                    style: TextStyle(
                      color: request.isFeatured
                          ? const Color(0xFFDF7B1C)
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatRelativeTime(request.createdAt),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              requestContent,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            if (referenceImages.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildRequestReferencePreview(referenceImages),
            ],
            if (previewHints.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: previewHints.map((hint) {
                  return _buildRequestMetaPill(
                    hint,
                    icon: Icons.search_rounded,
                  );
                }).toList(),
              ),
            ],
            if (request.keywords.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: previewHints.isNotEmpty ? 12 : 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: request.keywords.map((keyword) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$keyword',
                        style: const TextStyle(
                          color: Color(0xFF5A6A83),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.monetization_on_outlined,
                    color: Color(0xFFF3AE2A)),
                const SizedBox(width: 6),
                Text(
                  '${request.totalCoins}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 18),
                const Icon(Icons.mode_comment_outlined,
                    color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text('${request.replyCount}'),
                const Spacer(),
                Text(
                  request.isOpen ? 'Open' : 'Ended',
                  style: TextStyle(
                    color: request.isOpen
                        ? const Color(0xFF1F8B4C)
                        : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingTile(_RequestRankEntry entry, int rank) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF616B7C),
              ),
            ),
          ),
          CommunityAvatar(
            name: entry.name,
            avatarUrl: entry.avatarUrl,
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCompactNumber(entry.followers)} followers',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Picked ${entry.approvedMatches}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  ref.read(communityHubProvider.notifier).toggleCreatorFollow(entry.creatorId);
                },
                child: Text(entry.isFollowing ? 'Following' : '+ Follow'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<CommunityPost> _feedPostsForCurrentFilter(CommunityServiceState state) {
    switch (_selectedFeedTab) {
      case _CommunityFeedTab.recommended:
        return state.posts;
      case _CommunityFeedTab.newest:
        final newestPosts = [...state.posts]
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
        return newestPosts;
      case _CommunityFeedTab.highlights:
        return state.trendingPosts.isNotEmpty
            ? state.trendingPosts
            : state.posts;
      case _CommunityFeedTab.videos:
        return state.posts.where((post) => post.videoUrls.isNotEmpty).toList();
    }
  }

  String _requestPrimaryContent(CommunityRequest request) {
    final title = _normalizeRequestText(request.title);
    final description = _normalizeRequestText(request.description);

    if (description.isEmpty) {
      return title;
    }
    if (title.isEmpty) {
      return description;
    }

    final normalizedTitle = title.toLowerCase();
    final normalizedDescription = description.toLowerCase();
    if (normalizedDescription == normalizedTitle ||
        normalizedDescription.startsWith(normalizedTitle)) {
      return description;
    }

    return '$title\n\n$description';
  }

  String _normalizeRequestText(String value) {
    return value
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  Widget _buildRequestReferencePreview(List<String> imageUrls) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              imageUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: const Color(0xFFF1F5FF),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                );
              },
            ),
          ),
          if (imageUrls.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '+${imageUrls.length - 1} more',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestMetaPill(String label, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5A6A83),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<CommunityRequest> _filteredRequests(CommunityHubState hubState) {
    List<CommunityRequest> requests = [...hubState.requests];

    if (_selectedRequestSection == _RequestSection.latest) {
      requests.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    } else if (_selectedRequestSection == _RequestSection.highlights) {
      requests = requests.where((request) => request.isFeatured).toList()
        ..sort((left, right) => right.totalCoins.compareTo(left.totalCoins));
    }

    if (_requestQuery.trim().isEmpty) {
      return requests;
    }

    final query = _requestQuery.trim().toLowerCase();
    return requests.where((request) {
      return request.title.toLowerCase().contains(query) ||
          request.description.toLowerCase().contains(query) ||
          request.keywords.any((keyword) => keyword.toLowerCase().contains(query));
    }).toList();
  }

  List<_RequestRankEntry> _requestRankingEntries(CommunityHubState hubState) {
    final rankingMap = <String, _RequestRankAccumulator>{};

    for (final creator in hubState.creators) {
      rankingMap[creator.id] = _RequestRankAccumulator(
        creatorId: creator.id,
        name: creator.displayName,
        avatarUrl: creator.avatarUrl,
        followers: creator.followers,
        isFollowing: creator.isFollowing,
      );
    }

    for (final request in hubState.requests) {
      for (final submission in request.submissions) {
        final accumulator = rankingMap.putIfAbsent(
          submission.contributorId,
          () => _RequestRankAccumulator(
            creatorId: submission.contributorId,
            name: submission.contributorName,
            avatarUrl: submission.contributorAvatarUrl,
            followers: 0,
            isFollowing: submission.isFollowingContributor,
          ),
        );

        accumulator.totalMatches += 1;
        if (submission.isApproved) {
          accumulator.approvedMatches += 1;
        }
      }
    }

    final entries = rankingMap.values
        .where((accumulator) => accumulator.totalMatches > 0)
        .map((accumulator) => accumulator.toEntry())
        .toList()
      ..sort((left, right) {
        final approvedComparison =
            right.approvedMatches.compareTo(left.approvedMatches);
        if (approvedComparison != 0) {
          return approvedComparison;
        }

        final totalComparison = right.totalMatches.compareTo(left.totalMatches);
        if (totalComparison != 0) {
          return totalComparison;
        }

        return right.followers.compareTo(left.followers);
      });

    return entries;
  }

  void _handleSearchPressed() {
    if (_selectedTopTab == _CommunityTopTab.request) {
      _showRequestSearchDialog();
      return;
    }

    _showCommunitySearchDialog();
  }

  void _showCommunitySearchDialog() {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogL10n.searchCommunity),
          content: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
            ),
            autofocus: true,
            onSubmitted: (_) {
              Navigator.pop(context);
              _searchPosts();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _searchPosts();
              },
              child: Text(l10n.search),
            ),
          ],
        );
      },
    );
  }

  void _showRequestSearchDialog() {
    final controller = TextEditingController(text: _requestQuery);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search requests'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Search by title, description or keyword',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search_rounded),
            ),
            autofocus: true,
            onSubmitted: (_) {
              setState(() {
                _requestQuery = controller.text.trim();
              });
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _requestQuery = controller.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _searchPosts() {
    if (_searchController.text.trim().isEmpty) {
      return;
    }

    context.push(
      '/main/search/${Uri.encodeComponent(_searchController.text.trim())}',
    );
  }

  void _createPost() async {
    final result = await context.push('/main/create-post');
    if (result == true) {
      await Future.wait([
        _loadPosts(),
        _loadTrendingPosts(),
        _loadTags(),
      ]);
    }
  }

  void _createRequest() async {
    final result = await context.push('/main/request/create');
    if (!mounted) {
      return;
    }

    if (result is String && result.isNotEmpty) {
      setState(() {
        _selectedTopTab = _CommunityTopTab.request;
        _selectedRequestSection = _RequestSection.latest;
      });
      context.push('/main/request/$result');
    }
  }

  void _openContentCreatorScreen() {
    context.push('/main/content-creators');
  }
}

Color _parseForumColor(String? rawValue, Color fallback) {
  final raw = rawValue?.trim() ?? '';
  if (raw.isEmpty) {
    return fallback;
  }

  final normalized = raw.replaceFirst('#', '');
  if (normalized.length != 6) {
    return fallback;
  }

  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return fallback;
  }

  return Color(0xFF000000 | parsed);
}

enum _CommunityTopTab { following, original, request }

enum _CommunityFeedTab { recommended, newest, highlights, videos }

enum _FollowingSection { topics, users }

enum _RequestSection { latest, highlights, ranking }

class _RequestRankEntry {
  final String creatorId;
  final String name;
  final String? avatarUrl;
  final int followers;
  final bool isFollowing;
  final int totalMatches;
  final int approvedMatches;

  const _RequestRankEntry({
    required this.creatorId,
    required this.name,
    required this.avatarUrl,
    required this.followers,
    required this.isFollowing,
    required this.totalMatches,
    required this.approvedMatches,
  });
}

class _RequestRankAccumulator {
  final String creatorId;
  final String name;
  final String? avatarUrl;
  final int followers;
  final bool isFollowing;
  int totalMatches = 0;
  int approvedMatches = 0;

  _RequestRankAccumulator({
    required this.creatorId,
    required this.name,
    required this.avatarUrl,
    required this.followers,
    required this.isFollowing,
  });

  _RequestRankEntry toEntry() {
    return _RequestRankEntry(
      creatorId: creatorId,
      name: name,
      avatarUrl: avatarUrl,
      followers: followers,
      isFollowing: isFollowing,
      totalMatches: totalMatches,
      approvedMatches: approvedMatches,
    );
  }
}