import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/community_hub_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/community_hub_models.dart';
import '../../widgets/community/community_hub_primitives.dart';

class ContentCreatorScreen extends ConsumerStatefulWidget {
  const ContentCreatorScreen({super.key});

  @override
  ConsumerState<ContentCreatorScreen> createState() =>
      _ContentCreatorScreenState();
}

class _ContentCreatorScreenState extends ConsumerState<ContentCreatorScreen> {
  CreatorMetricTab _metricTab = CreatorMetricTab.likes;
  CreatorLeaderboardWindow _window = CreatorLeaderboardWindow.daily;

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(communityHubProvider);

    if (hubState.isLoading && hubState.creators.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF240761),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (hubState.errorMessage != null && hubState.creators.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF240761),
        appBar: AppBar(
          title: const Text('Content Creator'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  hubState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.read(communityHubProvider.notifier).refresh();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final rankedCreators = [...hubState.creators]
      ..sort((left, right) {
        return right
            .metricValue(_window, _metricTab)
            .compareTo(left.metricValue(_window, _metricTab));
      });

    final topThree = <CommunityCreator>[];
    for (final creator in rankedCreators.take(3)) {
      topThree.add(creator);
    }

    final others = rankedCreators.skip(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF240761),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFB933F2), Color(0xFF3E11C6), Color(0xFF130B63)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: Colors.white,
                        ),
                        const Expanded(
                          child: Text(
                            'Content Creator',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: _buildMetricTabs(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: _buildPodium(topThree),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedCreatorWindowHeaderDelegate(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(36, 10, 36, 14),
                      child: _buildWindowTabs(),
                    ),
                  ),
                ),
              ];
            },
            body: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF3010A4), Color(0xFF130B63)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: others.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'More creators will appear here as activity grows.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                      itemCount: others.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (context, index) {
                        final creator = others[index];
                        final rank = index + 4;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  rank.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              CommunityAvatar(
                                name: creator.displayName,
                                avatarUrl: creator.avatarUrl,
                                radius: 26,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      creator.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${formatCompactNumber(creator.followers)} followers',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _metricLine(creator),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  ref
                                      .read(communityHubProvider.notifier)
                                      .toggleCreatorFollow(creator.id);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: creator.isFollowing
                                        ? Colors.transparent
                                        : Colors.white.withValues(alpha: 0.45),
                                  ),
                                  backgroundColor: creator.isFollowing
                                      ? AppTheme.primaryColor.withValues(alpha: 0.9)
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  creator.isFollowing ? 'Following' : '+ Follow',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTabs() {
    final items = <MapEntry<CreatorMetricTab, String>>[
      const MapEntry<CreatorMetricTab, String>(CreatorMetricTab.likes, 'Likes'),
      const MapEntry<CreatorMetricTab, String>(CreatorMetricTab.uploads, 'Uploads'),
      const MapEntry<CreatorMetricTab, String>(CreatorMetricTab.earnings, 'Earnings'),
    ];

    return Row(
      children: items.map((item) {
        final isSelected = item.key == _metricTab;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _metricTab = item.key;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? const Color(0xFF5BC8FF)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                item.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWindowTabs() {
    final items = <MapEntry<CreatorLeaderboardWindow, String>>[
      const MapEntry<CreatorLeaderboardWindow, String>(CreatorLeaderboardWindow.daily, 'Day'),
      const MapEntry<CreatorLeaderboardWindow, String>(CreatorLeaderboardWindow.weekly, 'Week'),
      const MapEntry<CreatorLeaderboardWindow, String>(CreatorLeaderboardWindow.monthly, 'Month'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: items.map((item) {
          final isSelected = item.key == _window;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _window = item.key;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: <Color>[Color(0xFFFD6BE7), Color(0xFF605BFF)],
                        )
                      : null,
                ),
                child: Text(
                  item.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPodium(List<CommunityCreator> topThree) {
    final podiumCreators = <CommunityCreator?>[
      topThree.length > 1 ? topThree[1] : null,
      topThree.isNotEmpty ? topThree[0] : null,
      topThree.length > 2 ? topThree[2] : null,
    ];
    final heights = <double>[84, 124, 98];
    final labels = <String>['No.2', 'No.1', 'No.3'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(podiumCreators.length, (index) {
        final creator = podiumCreators[index];
        if (creator == null) {
          return const Expanded(child: SizedBox());
        }

        final isCenter = index == 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: isCenter ? 0 : 36),
            child: Column(
              children: [
                CommunityAvatar(
                  name: creator.displayName,
                  avatarUrl: creator.avatarUrl,
                  radius: isCenter ? 42 : 34,
                ),
                const SizedBox(height: 10),
                Text(
                  creator.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCenter ? 18 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _metricLine(creator),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(communityHubProvider.notifier)
                        .toggleCreatorFollow(creator.id);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: creator.isFollowing
                        ? Colors.white.withValues(alpha: 0.18)
                        : const Color(0xFFF76BE4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: Text(creator.isFollowing ? 'Following' : '+ Follow'),
                ),
                const SizedBox(height: 16),
                Container(
                  height: heights[index],
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: isCenter
                          ? const <Color>[Color(0xFFFFF2CF), Color(0xFFFFD37D)]
                          : index == 0
                              ? const <Color>[Color(0xFFF4F3FF), Color(0xFFE6E2FF)]
                              : const <Color>[Color(0xFFF7E2E2), Color(0xFFD9B6B0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      labels[index].toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFF4A2A2A),
                        fontSize: isCenter ? 30 : 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _metricLine(CommunityCreator creator) {
    final value = creator.metricValue(_window, _metricTab);
    switch (_metricTab) {
      case CreatorMetricTab.likes:
        return 'Likes ${formatCompactNumber(value)}';
      case CreatorMetricTab.uploads:
        return 'Uploads ${formatCompactNumber(value)}';
      case CreatorMetricTab.earnings:
        return 'Coins ${formatCompactNumber(value)}';
    }
  }
}

class _PinnedCreatorWindowHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedCreatorWindowHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 78;

  @override
  double get maxExtent => 78;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F0B78).withValues(alpha: overlapsContent ? 0.98 : 0.94),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedCreatorWindowHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
