import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/dating_service.dart';
import '../../core/services/file_url_service.dart';
import '../../l10n/app_localizations.dart';
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
        SnackBar(content: Text(AppLocalizations.of(context).datingPassed)),
      );
      ref.invalidate(_meetMatchesProvider);
      ref.invalidate(_meetSuggestionsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _rejectingUserIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matchesAsync = ref.watch(_meetMatchesProvider);
    final suggestionsAsync = ref.watch(_meetSuggestionsProvider);
    final upgradeAsync = ref.watch(_meetUpgradeStatusProvider);

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${l10n.error}: $e')),
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
                .where((item) =>
                    !_hiddenSuggestionUserIds.contains(item.user.userId))
                .toList();
            if (visibleMatches.isEmpty && visibleSuggestions.isEmpty) {
              return _buildEmpty(
                  context, suggestionResult.meta, upgradeAsync.value);
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
    final l10n = AppLocalizations.of(context);
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
            Text(
              l10n.datingNoMatchesYet,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.datingLikeSomeoneBack,
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
                  ? meta?.tier == 'UNLIMITED'
                      ? '✨ ${l10n.datingAiSuggestionsActive}: ${l10n.datingPlanUnlimitedUnlocked}'
                      : '✨ ${l10n.datingAiSuggestionsActive}: ${meta?.remainingToday ?? 0}/${meta?.maxPerDay ?? 3}'
                  : '✨ ${l10n.datingAutoSuggestionsPerDay}\n${l10n.datingUpgradeVipForAiMatch}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            if (meta?.aiEnabled != true &&
                (upgrade?.tier == 'FREE' || upgrade == null)) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DatingUpgradeScreen(),
                    ),
                  );
                },
                child: Text(l10n.datingUpgradeVipForAiMatch),
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
    List<DatingMatchUser> matches, {
    required List<DatingSuggestedMatch> suggestions,
    required DatingSuggestionMeta suggestionsMeta,
    DatingUpgradeStatus? upgradeStatus,
    bool suggestionsLoading = false,
  }) {
    final l10n = AppLocalizations.of(context);
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
            suggestionsMeta.tier == 'UNLIMITED'
                ? (suggestionsMeta.aiEnabled
                    ? l10n.datingAiSuggestions
                    : l10n.datingDailySuggestions)
                : (suggestionsMeta.aiEnabled
                    ? '${l10n.datingAiSuggestions} (${suggestionsMeta.remainingToday}/${suggestionsMeta.maxPerDay})'
                    : '${l10n.datingDailySuggestions} (${suggestionsMeta.remainingToday}/${suggestionsMeta.maxPerDay})'),
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
              swipeProfileIds:
                  suggestions.map((item) => item.user.userId).toList(),
              swipeProfileIndex: suggestions.indexOf(suggestion),
            ),
          ),
        );
      }
    }

    if (matches.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.datingMutualMatches,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
    final l10n = AppLocalizations.of(context);
    final showUpgradeCta =
        meta.aiEnabled == false && (upgradeStatus?.tier ?? 'FREE') == 'FREE';
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
            color: meta.aiEnabled
                ? const Color(0xFF90CAF9)
                : const Color(0xFFFFCC80),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta.aiEnabled
                  ? l10n.datingAiMatchModeActive
                  : l10n.datingAutoMatchMode,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: meta.aiEnabled
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta.aiEnabled
                  ? meta.tier == 'UNLIMITED'
                      ? l10n.datingBestAiQuality
                      : l10n.datingVipAiScoring
                  : l10n.datingUpgradeVipAiAccuracy,
              style: const TextStyle(fontSize: 12),
            ),
            if (showUpgradeCta) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DatingUpgradeScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: Text(l10n.datingUpgradeVipForAiMatch),
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
    final l10n = AppLocalizations.of(context);
    final user = suggestion.user;
    final avatarUrl = appendCacheBuster(user.avatarUrl, user.updatedAt);
    final roleLabel = user.role != null
        ? DatingConstants.roleLabels[user.role] ?? user.role!
        : null;
    final distanceLabel = user.distanceKm != null
        ? user.distanceKm == 0
            ? '0m'
            : '${user.distanceKm}km'
        : null;
    final ageLabel = user.age != null ? '${user.age} y/o' : null;
    final scoreGradient = suggestion.score >= 80
        ? const [Color(0xFF4C6FFF), Color(0xFF2AA9FF)]
        : const [Color(0xFF8E44FF), Color(0xFFD94FD5)];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openProfile(context, user.userId),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF4F9FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFD7EAFE), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF90CAF9).withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: 76,
                        height: 96,
                        child: avatarUrl != null
                            ? PresignedImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                errorWidget: _placeholder(),
                              )
                            : _placeholder(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient:
                                      LinearGradient(colors: scoreGradient),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scoreGradient.last
                                          .withValues(alpha: 0.24),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${l10n.datingAiScore} ${suggestion.score}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (distanceLabel != null)
                                _buildMetaChip(
                                    Icons.place_outlined, distanceLabel),
                              if (ageLabel != null)
                                _buildMetaChip(Icons.cake_outlined, ageLabel),
                              if (roleLabel != null)
                                _buildMetaChip(Icons.person_outline, roleLabel),
                            ],
                          ),
                          if (user.isOnline != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6FBFF),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFD7EAFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                  const SizedBox(width: 6),
                                  Text(
                                    user.isOnline == true
                                        ? 'Online now'
                                        : 'Offline',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (suggestion.reasons.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestion.reasons
                        .map((reason) => _buildReasonChip(
                              _localizedReason(context, reason),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: rejecting ? null : onReject,
                        icon: const Icon(Icons.person_off_outlined, size: 16),
                        label: Text(l10n.datingReject),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E88E5),
                          side: const BorderSide(color: Color(0xFFB3D7FF)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(colors: scoreGradient),
                        boxShadow: [
                          BoxShadow(
                            color: scoreGradient.last.withValues(alpha: 0.20),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingProfileScreen(
          userId: userId,
          swipeProfileIds: swipeProfileIds,
          swipeProfileIndex: swipeProfileIndex,
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCEBFB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5A7FB9)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF355070),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7EAFE)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5B73),
        ),
      ),
    );
  }

  String _localizedReason(BuildContext context, String reason) {
    final normalized = reason.trim().toLowerCase();
    if (normalized == 'trending in your area' ||
        normalized.contains('trending in your area')) {
      return AppLocalizations.of(context).datingTrendingInYourArea;
    }
    return reason;
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
    final l10n = AppLocalizations.of(context);
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
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: const Color(0xFFE91E63).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar — taller, full left side
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 100,
                    height: 120,
                    child: avatarUrl != null
                        ? PresignedImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                if (user.isOnline != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: user.isOnline == true
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.isOnline == true ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (user.age != null) '${user.age} y/o',
                        if (user.role != null)
                          DatingConstants.roleLabels[user.role] ?? user.role!,
                        if (user.distanceKm != null)
                          user.distanceKm == 0 ? '0m' : '${user.distanceKm}km',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Mutual Match badge — prominent gradient pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8E24AA), Color(0xFFE91E63)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE91E63).withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '❤️ ${l10n.datingMutualMatch}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: rejecting ? null : onReject,
                      icon: const Icon(Icons.person_off_outlined, size: 15),
                      label: Text(l10n.datingReject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[300]!),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Arrow
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child:
                  Icon(Icons.chevron_right, color: Color(0xFFE91E63), size: 22),
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
