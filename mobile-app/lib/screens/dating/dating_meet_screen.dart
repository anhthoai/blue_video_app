import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/dating_service.dart';
import '../../core/services/file_url_service.dart';
import '../../models/dating_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/presigned_image.dart';
import 'dating_profile_screen.dart';
import 'dating_upgrade_screen.dart';

final _meetMatchesProvider =
    FutureProvider.autoDispose<List<DatingMatchUser>>((ref) async {
  return DatingService().getMutualMatches();
});

final _meetSuggestionsProvider =
    FutureProvider.autoDispose<DatingSuggestionResult>((ref) async {
  return DatingService().getSuggestedMatches();
});

final _meetUpgradeStatusProvider =
    FutureProvider.autoDispose<DatingUpgradeStatus>((ref) async {
  return DatingService().getUpgradeStatus();
});

class DatingMeetScreen extends ConsumerStatefulWidget {
  const DatingMeetScreen({super.key});

  @override
  ConsumerState<DatingMeetScreen> createState() => _DatingMeetScreenState();
}

class _DatingMeetScreenState extends ConsumerState<DatingMeetScreen> {
  final Set<String> _hiddenMatchUserIds = <String>{};
  final Set<String> _hiddenSuggestionUserIds = <String>{};
  final Set<String> _rejectingUserIds = <String>{};

  Future<void> _rejectUser(String userId) async {
    if (_rejectingUserIds.contains(userId)) return;
    setState(() => _rejectingUserIds.add(userId));

    try {
      await DatingService().sendMatchAction(userId, 'DISLIKE');
      if (!mounted) return;
      setState(() {
        _hiddenMatchUserIds.add(userId);
        _hiddenSuggestionUserIds.add(userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match rejected and hidden.')),
      );
      ref.invalidate(_meetMatchesProvider);
      ref.invalidate(_meetSuggestionsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _rejectingUserIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(_meetMatchesProvider);
    final suggestionsAsync = ref.watch(_meetSuggestionsProvider);
    final upgradeAsync = ref.watch(_meetUpgradeStatusProvider);

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (matches) {
        final visibleMatches = matches
            .where((item) => !_hiddenMatchUserIds.contains(item.user.userId))
            .toList();

        return suggestionsAsync.when(
          loading: () => _buildMeetList(
            context,
            ref,
            visibleMatches,
            suggestions: const [],
            suggestionsMeta: const DatingSuggestionMeta(
              maxPerDay: 3,
              remainingToday: 0,
              aiEnabled: false,
              tier: 'FREE',
            ),
            upgradeStatus: upgradeAsync.value,
            suggestionsLoading: true,
          ),
          error: (_, __) => _buildMeetList(
            context,
            ref,
            visibleMatches,
            suggestions: const [],
            suggestionsMeta: const DatingSuggestionMeta(
              maxPerDay: 3,
              remainingToday: 0,
              aiEnabled: false,
              tier: 'FREE',
            ),
            upgradeStatus: upgradeAsync.value,
          ),
          data: (suggestionResult) {
            final visibleSuggestions = suggestionResult.suggestions
                .where((item) => !_hiddenSuggestionUserIds.contains(item.user.userId))
                .toList();
            if (visibleMatches.isEmpty && visibleSuggestions.isEmpty) {
              return _buildEmpty(context, suggestionResult.meta, upgradeAsync.value);
            }

            return _buildMeetList(
              context,
              ref,
              visibleMatches,
              suggestions: visibleSuggestions,
              suggestionsMeta: suggestionResult.meta,
              upgradeStatus: upgradeAsync.value,
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(
    BuildContext context,
    DatingSuggestionMeta? meta,
    DatingUpgradeStatus? upgrade,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.3),
                    const Color(0xFF8E44FF).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Icon(
                Icons.favorite_outline,
                size: 50,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Matches Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Like someone and when they like you back,\nyou\'ll appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              meta?.aiEnabled == true
                  ? '✨ AI suggestions are active: ${meta?.remainingToday ?? 0}/${meta?.maxPerDay ?? 3} left today.'
                  : '✨ You get 3 auto suggestions per day.\nUpgrade VIP for AI-accuracy matching.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            if (meta?.aiEnabled != true && (upgrade?.tier == 'FREE' || upgrade == null)) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DatingUpgradeScreen(freeLimit: 60),
                    ),
                  );
                },
                child: const Text('Upgrade VIP for AI Match'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeetList(
    BuildContext context,
    WidgetRef ref,
    List<DatingMatchUser> matches,
    {
    required List<DatingSuggestedMatch> suggestions,
    required DatingSuggestionMeta suggestionsMeta,
    DatingUpgradeStatus? upgradeStatus,
    bool suggestionsLoading = false,
  }) {
    final children = <Widget>[];

    children.add(
      _SuggestionHeader(
        meta: suggestionsMeta,
        upgradeStatus: upgradeStatus,
      ),
    );

    if (suggestionsLoading) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LinearProgressIndicator(minHeight: 2),
      ));
    }

    if (suggestions.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            suggestionsMeta.aiEnabled
                ? 'AI Suggestions (${suggestionsMeta.remainingToday}/${suggestionsMeta.maxPerDay} left today)'
                : 'Daily Suggestions (${suggestionsMeta.remainingToday}/${suggestionsMeta.maxPerDay} left today)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      );
      children.add(const SizedBox(height: 8));
      for (final suggestion in suggestions) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _SuggestionCard(
              suggestion: suggestion,
              rejecting: _rejectingUserIds.contains(suggestion.user.userId),
              onReject: () => _rejectUser(suggestion.user.userId),
              swipeProfileIds: suggestions.map((item) => item.user.userId).toList(),
              swipeProfileIndex: suggestions.indexOf(suggestion),
            ),
          ),
        );
      }
    }

    if (matches.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Mutual Matches',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      );
      children.add(const SizedBox(height: 8));
      for (final match in matches) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _MatchCard(
              match: match,
              rejecting: _rejectingUserIds.contains(match.user.userId),
              onReject: () => _rejectUser(match.user.userId),
              swipeProfileIds: matches.map((item) => item.user.userId).toList(),
              swipeProfileIndex: matches.indexOf(match),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_meetMatchesProvider);
        ref.invalidate(_meetSuggestionsProvider);
        ref.invalidate(_meetUpgradeStatusProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: children,
      ),
    );
  }
}

class _SuggestionHeader extends StatelessWidget {
  final DatingSuggestionMeta meta;
  final DatingUpgradeStatus? upgradeStatus;

  const _SuggestionHeader({
    required this.meta,
    required this.upgradeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final showUpgradeCta = meta.aiEnabled == false && (upgradeStatus?.tier ?? 'FREE') == 'FREE';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: meta.aiEnabled
              ? const Color(0xFFE8F6FF)
              : const Color(0xFFFFF4E5),
          border: Border.all(
            color: meta.aiEnabled ? const Color(0xFF90CAF9) : const Color(0xFFFFCC80),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta.aiEnabled
                  ? 'AI Match Mode Active'
                  : 'Auto Match Mode (3/day)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: meta.aiEnabled ? const Color(0xFF1565C0) : const Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta.aiEnabled
                  ? 'Your VIP plan is using AI scoring for more accurate compatibility.'
                  : 'Upgrade VIP to get AI-powered accuracy for your daily 3 suggestions.',
              style: const TextStyle(fontSize: 12),
            ),
            if (showUpgradeCta) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DatingUpgradeScreen(freeLimit: 60),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: const Text('Upgrade VIP'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final DatingSuggestedMatch suggestion;
  final bool rejecting;
  final VoidCallback onReject;
  final List<String>? swipeProfileIds;
  final int swipeProfileIndex;

  const _SuggestionCard({
    required this.suggestion,
    required this.rejecting,
    required this.onReject,
    this.swipeProfileIds,
    this.swipeProfileIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final user = suggestion.user;
    final avatarUrl = appendCacheBuster(user.avatarUrl, user.updatedAt);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF8FBFF),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: avatarUrl != null
                    ? PresignedImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            title: Text(user.displayName),
            subtitle: Text(
              [
                if (user.distanceKm != null)
                  user.distanceKm == 0 ? '0m away' : '${user.distanceKm}km away',
                if (user.age != null) '${user.age} y/o',
                if (user.role != null) DatingConstants.roleLabels[user.role] ?? user.role!,
                'AI score ${suggestion.score}%',
              ].join(' · '),
            ),
            trailing: user.isOnline == true
                ? const Icon(Icons.circle, size: 10, color: Color(0xFF4CAF50))
                : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DatingProfileScreen(
                  userId: user.userId,
                  swipeProfileIds: swipeProfileIds,
                  swipeProfileIndex: swipeProfileIndex,
                ),
              ),
            ),
          ),
          if (suggestion.reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestion.reasons
                    .map((reason) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFCFD8DC)),
                          ),
                          child: Text(
                            reason,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: rejecting ? null : onReject,
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(Icons.person, color: Colors.white54, size: 20),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final DatingMatchUser match;
  final bool rejecting;
  final VoidCallback onReject;
  final List<String>? swipeProfileIds;
  final int swipeProfileIndex;

  const _MatchCard({
    required this.match,
    required this.rejecting,
    required this.onReject,
    this.swipeProfileIds,
    this.swipeProfileIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final user = match.user;
    final avatarUrl = appendCacheBuster(user.avatarUrl, user.updatedAt);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DatingProfileScreen(
            userId: user.userId,
            swipeProfileIds: swipeProfileIds,
            swipeProfileIndex: swipeProfileIndex,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 90,
                height: 100,
                child: avatarUrl != null
                  ? PresignedImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: _placeholder(),
                    )
                    : _placeholder(),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isOnline != null)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: user.isOnline == true
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                            ),
                          ),
                      ],
                    ),
                      if (user.distanceKm != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            user.distanceKm == 0 ? '0m away' : '${user.distanceKm}km away',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (user.age != null) '${user.age} y/o',
                        if (user.role != null)
                          DatingConstants.roleLabels[user.role] ?? user.role!,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8E44FF), Color(0xFFE91E63)],
                        ),
                      ),
                      child: const Text(
                        '❤️ Mutual Match',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: rejecting ? null : onReject,
                          icon: const Icon(Icons.person_off_outlined, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(color: Colors.red[300]!),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Arrow
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(Icons.person, color: Colors.white54, size: 36),
    );
  }
}
