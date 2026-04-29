import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/community_hub_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/community_hub_models.dart';
import '../../models/community_post.dart';
import '../../widgets/community/community_hub_primitives.dart';
import '../../widgets/community/community_post_widget.dart';
import '../../widgets/community/video_card_widget.dart';

class ForumDetailScreen extends ConsumerStatefulWidget {
  final String forumId;

  const ForumDetailScreen({
    super.key,
    required this.forumId,
  });

  @override
  ConsumerState<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends ConsumerState<ForumDetailScreen> {
  CommunityForumDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;
  _ForumFeedTab _feed = _ForumFeedTab.recommended;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetail();
    });
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await ref.read(communityHubProvider.notifier).getForumDetail(
            widget.forumId,
            feed: _feed.apiValue,
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _toggleFollow() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }

    try {
      final updatedForum =
          await ref.read(communityHubProvider.notifier).toggleForumFollow(
                detail.forum.id,
              );
      if (!mounted || updatedForum == null) {
        return;
      }

      setState(() {
        _detail = CommunityForumDetail(
          forum: updatedForum,
          posts: detail.posts,
          feed: detail.feed,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update forum follow state: $error')),
      );
    }
  }

  void _selectFeed(_ForumFeedTab feed) {
    if (_feed == feed) {
      return;
    }

    setState(() {
      _feed = feed;
    });
    _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);
    final detail = _detail;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FD),
      appBar: AppBar(
        title: Text(detail?.forum.title ?? 'Forum'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
          children: [
            if (_isLoading && detail == null)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && detail == null)
              _buildMessageCard(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load forum',
                subtitle: _errorMessage!,
                actionLabel: 'Retry',
                onAction: _loadDetail,
              )
            else if (detail == null)
              _buildMessageCard(
                icon: Icons.forum_outlined,
                title: 'Forum not found',
                subtitle: 'This topic may have been removed or is not available yet.',
              )
            else ...[
              _buildHero(detail.forum),
              const SizedBox(height: 16),
              _buildFeedTabs(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: LinearProgressIndicator(),
                ),
              if (detail.posts.isEmpty)
                _buildMessageCard(
                  icon: Icons.dynamic_feed_outlined,
                  title: 'No posts in this forum yet',
                  subtitle: 'The topic is live, but there are no posts for this feed filter yet.',
                )
              else
                ...detail.posts.map((post) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPostCard(
                      post: post,
                      currentUserId: authState.currentUser?.id,
                      currentUsername: authState.currentUser?.username,
                      currentUserAvatar:
                          authState.currentUser?.avatarUrl ?? '',
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(CommunityForum forum) {
    final startColor = _parseHexColor(forum.accentStart, const Color(0xFF4F7DFF));
    final endColor = _parseHexColor(forum.accentEnd, const Color(0xFF5FD4FF));

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: <Color>[startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forum.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      forum.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _toggleFollow,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      forum.isFollowing ? Colors.white : Colors.white.withValues(alpha: 0.14),
                  foregroundColor: forum.isFollowing ? startColor : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(forum.isFollowing ? 'Following' : '+ Follow'),
              ),
            ],
          ),
          if (forum.description.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              forum.description,
              style: const TextStyle(
                color: Colors.white,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoPill(
                icon: Icons.dynamic_feed_rounded,
                label: '${formatCompactNumber(forum.postCount)} posts',
              ),
              _buildInfoPill(
                icon: Icons.groups_rounded,
                label: '${formatCompactNumber(forum.followerCount)} followers',
              ),
              ...forum.keywords.take(3).map((keyword) {
                return _buildInfoPill(
                  icon: Icons.tag_rounded,
                  label: keyword,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTabs() {
    final items = <MapEntry<_ForumFeedTab, String>>[
      const MapEntry<_ForumFeedTab, String>(_ForumFeedTab.recommended, 'Recommended'),
      const MapEntry<_ForumFeedTab, String>(_ForumFeedTab.newest, 'Newest'),
      const MapEntry<_ForumFeedTab, String>(_ForumFeedTab.highlights, 'Highlights'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = item.key == _feed;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => _selectFeed(item.key),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE9F2FF) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  item.value,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : const Color(0xFF4D596D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard({
    required CommunityPost post,
    required String? currentUserId,
    required String? currentUsername,
    required String? currentUserAvatar,
  }) {
    if (post.videoUrls.isNotEmpty) {
      return VideoCardWidget(
        post: post,
        onTap: () => context.push('/main/post/${post.id}', extra: post),
      );
    }

    return CommunityPostWidget(
      post: post,
      currentUserId: currentUserId,
      currentUsername: currentUsername,
      currentUserAvatar: currentUserAvatar,
      onTap: () => context.push('/main/post/${post.id}', extra: post),
      onUserTap: () => context.go('/main/profile/${post.userId}'),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppTheme.primaryColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ForumFeedTab {
  recommended('recommended'),
  newest('newest'),
  highlights('highlights');

  const _ForumFeedTab(this.apiValue);

  final String apiValue;
}

Color _parseHexColor(String? value, Color fallback) {
  final raw = value?.trim() ?? '';
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
