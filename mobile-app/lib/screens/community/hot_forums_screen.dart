import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/community_hub_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/community_hub_models.dart';
import '../../widgets/community/community_hub_primitives.dart';

class HotForumsScreen extends ConsumerStatefulWidget {
  const HotForumsScreen({super.key});

  @override
  ConsumerState<HotForumsScreen> createState() => _HotForumsScreenState();
}

class _HotForumsScreenState extends ConsumerState<HotForumsScreen> {
  List<CommunityForum> _forums = const <CommunityForum>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForums();
    });
  }

  Future<void> _loadForums() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final forums = await ref
          .read(communityHubProvider.notifier)
          .loadForums(scope: 'hot');
      if (!mounted) {
        return;
      }

      setState(() {
        _forums = forums;
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

  Future<void> _toggleFollow(CommunityForum forum) async {
    try {
      final updatedForum =
          await ref.read(communityHubProvider.notifier).toggleForumFollow(
                forum.id,
              );
      if (!mounted || updatedForum == null) {
        return;
      }

      setState(() {
        _forums = _forums.map((item) {
          return item.id == updatedForum.id ? updatedForum : item;
        }).toList(growable: false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FD),
      appBar: AppBar(
        title: const Text('Hot Forums'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadForums,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF101B42),
                    Color(0xFF2E58C5),
                    Color(0xFF68D4FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topics with the fastest community momentum',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Open a forum to browse current posts, or follow it to keep the topic inside Following.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoading && _forums.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _forums.isEmpty)
              _buildMessageCard(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load forums',
                subtitle: _errorMessage!,
                actionLabel: 'Retry',
                onAction: _loadForums,
              )
            else if (_forums.isEmpty)
              _buildMessageCard(
                icon: Icons.forum_outlined,
                title: 'No hot forums yet',
                subtitle: 'Once the backend has active topic traffic, it will show here.',
              )
            else
              ..._forums.map((forum) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildForumCard(forum),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildForumCard(CommunityForum forum) {
    final startColor = _parseHexColor(forum.accentStart, const Color(0xFF4F7DFF));
    final endColor = _parseHexColor(forum.accentEnd, const Color(0xFF5FD4FF));

    return InkWell(
      onTap: () => context.push('/main/forums/${forum.id}'),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: <Color>[startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: startColor.withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                forum.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (forum.isHot) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'HOT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          forum.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _toggleFollow(forum),
                    style: FilledButton.styleFrom(
                      backgroundColor: forum.isFollowing
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.14),
                      foregroundColor: forum.isFollowing
                          ? startColor
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(forum.isFollowing ? 'Following' : '+ Follow'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (forum.description.isNotEmpty)
                Text(
                  forum.description,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.45,
                  ),
                ),
              if (forum.description.isNotEmpty) const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildMetricPill(
                    icon: Icons.dynamic_feed_rounded,
                    label: '${formatCompactNumber(forum.postCount)} posts',
                  ),
                  _buildMetricPill(
                    icon: Icons.people_alt_rounded,
                    label: '${formatCompactNumber(forum.followerCount)} followers',
                  ),
                  if (forum.keywords.isNotEmpty)
                    ...forum.keywords.take(3).map((keyword) {
                      return _buildMetricPill(
                        icon: Icons.tag_rounded,
                        label: keyword,
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill({
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
