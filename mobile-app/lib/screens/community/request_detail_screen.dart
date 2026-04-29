import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/community_hub_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/community_hub_models.dart';
import '../../widgets/community/community_hub_primitives.dart';
import '../../widgets/community/request_linked_media_picker.dart';
import '_fullscreen_media_gallery.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  int _previewIndex = 0;
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequest();
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(communityHubProvider.select((state) {
      for (final item in state.requests) {
        if (item.id == widget.requestId) {
          return item;
        }
      }
      return null;
    }));

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Detail')),
        body: Center(
          child: _isBootstrapping
              ? const CircularProgressIndicator()
              : const Text('Request not found'),
        ),
      );
    }

    final currentUser = ref.watch(authServiceProvider).currentUser;
    final isAuthor = currentUser?.id == request.authorId;
    final requestContent = _requestPrimaryContent(request);
    final previewHints = request.previewHints
        .map((hint) => hint.trim())
        .where((hint) => hint.isNotEmpty)
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Request Detail'),
      ),
      floatingActionButton: request.isOpen
          ? FloatingActionButton.extended(
              onPressed: _openSubmissionScreen,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Recommend media'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
        children: [
          _buildPreviewCarousel(request),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: request.isOpen ? () => _showSupportCoinsSheet(request) : null,
              icon: const Icon(Icons.monetization_on_outlined),
              label: const Text('Add Coins to This Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CommunityAvatar(
                      name: request.authorName,
                      avatarUrl: request.authorAvatarUrl,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            formatRelativeTime(request.createdAt),
                            style: const TextStyle(color: Color(0xFF7B8496)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: request.isOpen
                            ? const Color(0xFFE9F6EE)
                            : const Color(0xFFF0F2F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        request.isOpen ? 'Open' : 'Ended',
                        style: TextStyle(
                          color: request.isOpen
                              ? const Color(0xFF1F8B4C)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  requestContent,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
                if (previewHints.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: previewHints.map(_buildChip).toList(),
                  ),
                ],
                if (request.keywords.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: request.keywords.map((keyword) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCE5F6)),
                        ),
                        child: Text(
                          '#$keyword',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Total bounty',
                        value: '${request.totalCoins} coins',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Recommendations',
                        value: formatCompactNumber(request.submissions.length),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Watching',
                        value: formatCompactNumber(request.wantCount),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Supporters',
                        value: formatCompactNumber(request.supporterCount),
                      ),
                    ),
                  ],
                ),
                if (request.bonusCoins > 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${request.supporterCount} people added ${request.bonusCoins} bonus coins',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'Recommended media',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${request.submissions.length}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (request.submissions.isEmpty)
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 42,
                    color: Color(0xFFB4BFCE),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nothing here yet. Be the first to recommend media, upload a file, or attach a matching link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            )
          else
            ...request.submissions.map((submission) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildSubmissionCard(
                  request: request,
                  submission: submission,
                  isAuthor: isAuthor,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreviewCarousel(CommunityRequest request) {
    final imageSlides = request.referenceImageUrls;
    final requestContent = _requestPrimaryContent(request);
    final previewHints = request.previewHints
        .map((hint) => hint.trim())
        .where((hint) => hint.isNotEmpty)
        .take(3)
        .toList();

    if (imageSlides.isEmpty) {
      return Container(
        height: 240,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF121827), Color(0xFF24304C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                request.boardLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Text(
              requestContent,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            if (previewHints.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: previewHints.map((hint) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hint,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );
    }

    final slideCount = imageSlides.length;

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            itemCount: slideCount,
            onPageChanged: (index) {
              setState(() {
                _previewIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openRequestGallery(request, index),
                child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageSlides[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: const Color(0xFF1F2937),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white70,
                            size: 42,
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 18,
                      left: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          request.boardLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      bottom: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_full_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'View media',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
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
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_previewIndex + 1}/$slideCount',
          style: const TextStyle(
            color: Color(0xFF5F6C80),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B8496),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard({
    required CommunityRequest request,
    required CommunityRequestSubmission submission,
    required bool isAuthor,
  }) {
    final showApprove = isAuthor && request.isOpen && !submission.isApproved;
    final metadataChips = <String>[
      if (submission.fileName != null && submission.fileName!.trim().isNotEmpty)
        submission.fileName!.trim(),
      if (submission.searchKeyword != null &&
          submission.searchKeyword!.trim().isNotEmpty)
        'Search: ${submission.searchKeyword!.trim()}',
      if (submission.linkedMedia != null)
        communityLinkedMediaSourceLabel(submission.linkedMedia!),
      if (_submissionPreviewType(submission) == _SubmissionPreviewType.external)
        'External link',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              CommunityAvatar(
                name: submission.contributorName,
                avatarUrl: submission.contributorAvatarUrl,
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            submission.contributorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (submission.isApproved) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F7EE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Approved',
                              style: TextStyle(
                                color: Color(0xFF1F8B4C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatRelativeTime(submission.createdAt),
                      style: const TextStyle(color: Color(0xFF7B8496)),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  ref
                      .read(communityHubProvider.notifier)
                      .toggleSubmissionContributorFollow(
                        request.id,
                        submission.id,
                      );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: submission.isFollowingContributor
                      ? Colors.white
                      : AppTheme.primaryColor,
                  backgroundColor: submission.isFollowingContributor
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  side: BorderSide(
                    color: submission.isFollowingContributor
                        ? Colors.transparent
                        : const Color(0xFFB8C8EA),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  submission.isFollowingContributor ? 'Following' : '+ Follow',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            submission.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (submission.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              submission.description,
              style: const TextStyle(
                height: 1.45,
                color: Color(0xFF495569),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSubmissionMediaPreview(submission),
          if (metadataChips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metadataChips.map(_buildChip).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.favorite_border_rounded,
                  color: Colors.grey.shade600, size: 22),
              const SizedBox(width: 6),
              Text('${submission.likes}'),
              const SizedBox(width: 18),
              Icon(Icons.mode_comment_outlined,
                  color: Colors.grey.shade600, size: 22),
              const SizedBox(width: 6),
              Text('${submission.comments}'),
              const SizedBox(width: 18),
              Icon(Icons.play_circle_outline_rounded,
                  color: Colors.grey.shade600, size: 22),
              const SizedBox(width: 6),
              Text('${submission.playCount}'),
              const Spacer(),
              if (showApprove)
                FilledButton(
                  onPressed: () => _approveSubmission(submission),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Approve & reward'),
                )
              else
                OutlinedButton(
                  onPressed: request.isOpen
                      ? () => _showSupportCoinsSheet(request)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC58A12),
                    side: const BorderSide(color: Color(0xFFE6C779)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Support'),
                ),
            ],
          ),
        ],
      ),
    );
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

  Future<void> _openRequestGallery(CommunityRequest request, int initialIndex) async {
    final mediaItems = request.referenceImageUrls
        .map((url) => MediaItem(url: url, isVideo: false))
        .toList(growable: false);
    if (mediaItems.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FullscreenMediaGallery(
          mediaItems: mediaItems,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildSubmissionMediaPreview(CommunityRequestSubmission submission) {
    final previewType = _submissionPreviewType(submission);
    final mediaUrl = _submissionPrimaryUrl(submission);
    final previewImageUrl = _submissionPreviewImageUrl(submission);
    final linkedMedia = submission.linkedMedia;

    switch (previewType) {
      case _SubmissionPreviewType.image:
        if (previewImageUrl == null) {
          return _buildSubmissionFallbackCard(submission);
        }
        return InkWell(
          onTap: () => _openSubmissionTarget(submission),
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    previewImageUrl,
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
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case _SubmissionPreviewType.directVideo:
        if (previewImageUrl != null) {
          return InkWell(
            onTap: () => _openSubmissionTarget(submission),
            borderRadius: BorderRadius.circular(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      previewImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: const Color(0xFF111827),
                          alignment: Alignment.center,
                          child: Icon(
                            communityLinkedMediaPreviewIcon(
                              linkedMedia ??
                                  buildCommunityLinkedMediaFromExternalUrl(
                                    mediaUrl ?? '',
                                  ),
                            ),
                            color: Colors.white,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => _openSubmissionTarget(submission),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF111827), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case _SubmissionPreviewType.file:
        return InkWell(
          onTap: () => _openSubmissionTarget(submission),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD9E3F7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.fileName?.trim().isNotEmpty == true
                            ? submission.fileName!.trim()
                            : linkedMedia?.displayTitle ?? submission.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        linkedMedia != null
                            ? communityLinkedMediaSourceLabel(linkedMedia)
                            : 'Open file',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        );
      case _SubmissionPreviewType.external:
        return InkWell(
          onTap: () => _openSubmissionTarget(submission),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF4E72FF), Color(0xFF5CC1FF)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open linked media',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mediaUrl == null
                            ? 'External link'
                            : _submissionHostLabel(mediaUrl),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      case _SubmissionPreviewType.none:
        return _buildSubmissionFallbackCard(submission);
    }
  }

  Widget _buildSubmissionFallbackCard(CommunityRequestSubmission submission) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E3F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              submission.type == CommunityRequestSubmissionType.linkedVideo
                  ? Icons.link_rounded
                  : Icons.insert_drive_file_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Preview unavailable for this item, but it can still be opened from its original source.',
              style: TextStyle(
                color: Color(0xFF5A6A83),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _submissionPrimaryUrl(CommunityRequestSubmission submission) {
    final linkedMediaUrl = submission.linkedMedia?.primaryUrl?.trim();
    if (linkedMediaUrl != null && linkedMediaUrl.isNotEmpty) {
      return linkedMediaUrl;
    }

    final fileUrl = submission.fileUrl?.trim();
    if (fileUrl != null && fileUrl.isNotEmpty) {
      return fileUrl;
    }

    final linkedUrl = submission.linkedVideoUrl?.trim();
    if (linkedUrl != null && linkedUrl.isNotEmpty) {
      return linkedUrl;
    }

    return null;
  }

  String? _submissionPreviewImageUrl(CommunityRequestSubmission submission) {
    final linkedPreview = submission.linkedMedia?.previewImageUrl?.trim();
    if (linkedPreview != null && linkedPreview.isNotEmpty) {
      return linkedPreview;
    }

    final primaryUrl = _submissionPrimaryUrl(submission);
    if (_submissionPreviewType(submission) == _SubmissionPreviewType.image) {
      return primaryUrl;
    }

    return null;
  }

  _SubmissionPreviewType _submissionPreviewType(
    CommunityRequestSubmission submission,
  ) {
    switch (submission.linkedMedia?.previewKind) {
      case CommunityLinkedMediaPreviewKind.image:
        return _SubmissionPreviewType.image;
      case CommunityLinkedMediaPreviewKind.video:
        return _SubmissionPreviewType.directVideo;
      case CommunityLinkedMediaPreviewKind.audio:
      case CommunityLinkedMediaPreviewKind.file:
        return _SubmissionPreviewType.file;
      case CommunityLinkedMediaPreviewKind.external:
        return _SubmissionPreviewType.external;
      case null:
        break;
    }

    final mediaUrl = _submissionPrimaryUrl(submission);
    final mimeType = submission.mimeType?.trim().toLowerCase();
    final extension = _submissionFileExtension(submission, mediaUrl);

    if ((mimeType?.startsWith('image/') ?? false) ||
        _imageExtensions.contains(extension)) {
      return _SubmissionPreviewType.image;
    }

    if ((mimeType?.startsWith('video/') ?? false) ||
        _videoExtensions.contains(extension)) {
      return _SubmissionPreviewType.directVideo;
    }

    final fileUrl = submission.fileUrl?.trim();
    if (fileUrl != null && fileUrl.isNotEmpty) {
      return _SubmissionPreviewType.file;
    }

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      return _SubmissionPreviewType.external;
    }

    return _SubmissionPreviewType.none;
  }

  String _submissionFileExtension(
    CommunityRequestSubmission submission,
    String? mediaUrl,
  ) {
    final linkedExtension = submission.linkedMedia?.extension?.trim().toLowerCase();
    if (linkedExtension != null && linkedExtension.isNotEmpty) {
      return linkedExtension;
    }

    final fileName = submission.fileName?.trim();
    final candidate =
        fileName != null && fileName.isNotEmpty ? fileName : mediaUrl ?? '';
    if (candidate.isEmpty) {
      return '';
    }

    final parsedPath = Uri.tryParse(candidate)?.path ?? candidate;
    final dotIndex = parsedPath.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == parsedPath.length - 1) {
      return '';
    }

    return parsedPath.substring(dotIndex + 1).toLowerCase();
  }

  String _submissionHostLabel(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return 'External link';
    }
    return uri.host;
  }

  Future<void> _openSubmissionTarget(
    CommunityRequestSubmission submission,
  ) async {
    final linkedMedia = submission.linkedMedia;
    if (linkedMedia != null) {
      final openedInApp = await openCommunityLinkedMedia(context, linkedMedia);
      if (openedInApp) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    final mediaUrl = _submissionPrimaryUrl(submission);
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return;
    }

    switch (_submissionPreviewType(submission)) {
      case _SubmissionPreviewType.image:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => FullscreenMediaGallery(
              mediaItems: <MediaItem>[MediaItem(url: mediaUrl, isVideo: false)],
              initialIndex: 0,
            ),
          ),
        );
        return;
      case _SubmissionPreviewType.directVideo:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => FullscreenMediaGallery(
              mediaItems: <MediaItem>[MediaItem(url: mediaUrl, isVideo: true)],
              initialIndex: 0,
            ),
          ),
        );
        return;
      case _SubmissionPreviewType.file:
      case _SubmissionPreviewType.external:
        await _openExternalUrl(mediaUrl);
        return;
      case _SubmissionPreviewType.none:
        return;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link is not valid.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link right now.')),
      );
    }
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5A6A83),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showSupportCoinsSheet(CommunityRequest request) async {
    final controller = TextEditingController(text: '20');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add support coins',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Boost the bounty so more people will prioritize this request.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coins',
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(this.context);
                      final coins = int.tryParse(controller.text.trim()) ?? 0;
                      if (coins <= 0) {
                        return;
                      }

                      try {
                        await ref
                            .read(communityHubProvider.notifier)
                            .addSupportCoins(request.id, coins);
                        if (!mounted) {
                          return;
                        }

                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Added $coins coins to this request'),
                          ),
                        );
                      } catch (error) {
                        if (!mounted) {
                          return;
                        }

                        messenger.showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    child: const Text('Add coins'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveSubmission(CommunityRequestSubmission submission) async {
    try {
      await ref
          .read(communityHubProvider.notifier)
          .approveSubmission(widget.requestId, submission.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${submission.contributorName} was approved and the request was closed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _openSubmissionScreen() {
    context.push('/main/request/${widget.requestId}/submit');
  }

  Future<void> _loadRequest() async {
    try {
      await ref.read(communityHubProvider.notifier).fetchRequest(widget.requestId);
    } finally {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }
}

enum _SubmissionPreviewType { image, directVideo, file, external, none }

const Set<String> _imageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'heic',
};

const Set<String> _videoExtensions = <String>{
  'mp4',
  'mov',
  'm4v',
  'webm',
  'mkv',
  'avi',
  'wmv',
  'flv',
};