import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/dating_service.dart';
import '../../models/dating_model.dart';
import '../../core/theme/app_theme.dart';
import 'dating_profile_screen.dart';

final _meetMatchesProvider =
    FutureProvider.autoDispose<List<DatingMatchUser>>((ref) async {
  return DatingService().getMutualMatches();
});

class DatingMeetScreen extends ConsumerWidget {
  const DatingMeetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(_meetMatchesProvider);

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (matches) => matches.isEmpty
          ? _buildEmpty(context)
          : _buildMatchList(context, ref, matches),
    );
  }

  Widget _buildEmpty(BuildContext context) {
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
                    AppTheme.primaryColor.withOpacity(0.3),
                    const Color(0xFF8E44FF).withOpacity(0.3),
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
              '✨ VIP members unlock AI-powered matching\nto find the most compatible person for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchList(
    BuildContext context,
    WidgetRef ref,
    List<DatingMatchUser> matches,
  ) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_meetMatchesProvider),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _MatchCard(match: matches[index]),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final DatingMatchUser match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final user = match.user;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DatingProfileScreen(userId: user.userId),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
                child: user.avatarUrl != null
                    ? Image.network(user.avatarUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
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
                        if (user.isOnline == true)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                      ],
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
