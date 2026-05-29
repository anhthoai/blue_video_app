import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/dating_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dating_model.dart';
import '../../widgets/common/presigned_image.dart';
import 'private_album_screen.dart';

final _profileProvider =
    FutureProvider.autoDispose.family<DatingProfile?, String>((ref, userId) async {
  return DatingService().getDatingProfile(userId);
});

class DatingProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final List<String>? swipeProfileIds;
  final int swipeProfileIndex;

  const DatingProfileScreen({
    super.key,
    required this.userId,
    this.swipeProfileIds,
    this.swipeProfileIndex = 0,
  });

  @override
  ConsumerState<DatingProfileScreen> createState() => _DatingProfileScreenState();
}

class _DatingProfileScreenState extends ConsumerState<DatingProfileScreen> {
  bool _actionSent = false;
  String? _lastAction;
  bool _processingBottomAction = false;
  double? _swipeStartDy;

  late final PageController _mediaPageController;
  int _mediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _mediaPageController = PageController();
  }

  @override
  void dispose() {
    _mediaPageController.dispose();
    super.dispose();
  }

  List<String> _allPhotos(DatingProfile profile) {
    final photos = <String>[];
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      photos.add(profile.avatarUrl!);
    }
    photos.addAll(profile.publicPhotos);
    return photos;
  }

  bool _showPrivateAlbumCard(DatingProfile profile) {
    return profile.privateAlbumPhotoCount > 0;
  }

  String _privateAlbumButtonText(String? status) {
    final l10n = AppLocalizations.of(context);
    if (status == 'ACCEPTED') {
      return l10n.datingOpenPrivateAlbum;
    }
    if (status == 'PENDING') {
      return l10n.datingWaitingPermission;
    }
    return l10n.datingRequestUnlock;
  }

  Future<void> _handlePrivateAlbumAction(DatingProfile profile) async {
    final status = profile.privateAlbumAccessStatus;

    if (status == 'ACCEPTED') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrivateAlbumScreen(
            targetUserId: widget.userId,
            readOnly: true,
          ),
        ),
      );
      return;
    }

    if (status == 'PENDING') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).datingRequestSentCheckChat)),
      );
      return;
    }

    // Send request via chat
    try {
      final result = await DatingService().requestPrivateAlbumViaChat(widget.userId);
      if (!mounted) return;
      final chatRoomId = result['chatRoomId'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).datingRequestSentViaChat)),
      );
      ref.invalidate(_profileProvider(widget.userId));
      if (chatRoomId != null) {
        context.push('/main/chat/$chatRoomId');
      }
    } catch (e) {
      if (!mounted) return;
      final message = '$e';
      if (message.toLowerCase().contains('already') ||
          message.toLowerCase().contains('pending')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).datingRequestAlreadySentCheckChat)),
        );
        ref.invalidate(_profileProvider(widget.userId));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
      );
    }
  }

  Future<void> _sendAction(String action) async {
    try {
      await DatingService().sendMatchAction(widget.userId, action);
      if (mounted) {
        setState(() {
          _actionSent = true;
          _lastAction = action;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
      );
    }
  }

  Future<void> _startMessage() async {
    if (_processingBottomAction) return;
    setState(() => _processingBottomAction = true);
    try {
      final chatService = ref.read(chatServiceStateProvider.notifier);
      final room = await chatService.createChatRoom(
        type: 'PRIVATE',
        participantIds: [widget.userId],
      );
      if (!mounted || room == null) return;
      context.push('/main/chat/${room.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingBottomAction = false);
    }
  }

  Future<void> _addFriend() async {
    if (_processingBottomAction) return;
    setState(() => _processingBottomAction = true);
    try {
      await ApiService().followUser(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).datingFriendRequestSent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingBottomAction = false);
    }
  }

  bool get _canSwipeProfiles {
    final profileIds = widget.swipeProfileIds;
    return profileIds != null && profileIds.length > 1;
  }

  void _handleProfileSwipeStart(DragStartDetails details) {
    _swipeStartDy = details.globalPosition.dy;
  }

  void _handleProfileSwipeEnd(DragEndDetails details) {
    final profileIds = widget.swipeProfileIds;
    if (!_canSwipeProfiles || profileIds == null) {
      _swipeStartDy = null;
      return;
    }

    final startDy = _swipeStartDy;
    _swipeStartDy = null;
    if (startDy == null) {
      return;
    }

    // Keep horizontal swipes off the top media/header card.
    if (startDy < 430) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) {
      return;
    }

    final currentIndex = widget.swipeProfileIndex.clamp(0, profileIds.length - 1);
    final nextIndex = velocity < 0 ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= profileIds.length) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DatingProfileScreen(
          userId: profileIds[nextIndex],
          swipeProfileIds: profileIds,
          swipeProfileIndex: nextIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(_profileProvider(widget.userId));

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _handleProfileSwipeStart,
        onHorizontalDragEnd: _handleProfileSwipeEnd,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${l10n.error}: $e')),
          data: (profile) => profile == null
              ? Center(child: Text(l10n.datingProfileNotFound))
              : _buildProfile(context, profile),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processingBottomAction ? null : _startMessage,
                  icon: const Icon(Icons.message_outlined),
                  label: Text(l10n.messages),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 48,
                child: ElevatedButton(
                  onPressed: _processingBottomAction ? null : () => _sendAction('LIKE'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.favorite_border),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 48,
                child: OutlinedButton(
                  onPressed: _processingBottomAction ? null : _addFriend,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.person_add_alt_1),
                ),
              ),
              if (profileAsync.asData?.value?.privateAlbumAccessStatus == 'ACCEPTED') ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _processingBottomAction
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrivateAlbumScreen(
                                  targetUserId: widget.userId,
                                  readOnly: true,
                                ),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Icon(Icons.lock_open_outlined),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, DatingProfile profile) {
    final photos = _allPhotos(profile);
    final hasPrivateCard = _showPrivateAlbumCard(profile);
    final totalPages = photos.length + (hasPrivateCard ? 1 : 0);
    final privateCardIndex = hasPrivateCard ? photos.length : -1;
    final safeMediaIndex = totalPages == 0
        ? 0
        : (_mediaIndex < 0
            ? 0
            : (_mediaIndex >= totalPages ? totalPages - 1 : _mediaIndex));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SwipeMediaArea(
            height: 420,
            pageController: _mediaPageController,
            totalPages: totalPages,
            privateCardIndex: privateCardIndex,
            hasPrivateCard: hasPrivateCard,
            photos: photos,
            mediaIndex: _mediaIndex,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _mediaIndex = index);
            },
            buildPrivateCard: () => _buildPrivateAlbumMediaCard(profile),
            buildPlaceholder: _avatarPlaceholder,
            buildDots: () => _MediaDots(
              totalPages: totalPages,
              currentIndex: safeMediaIndex,
              privateCardIndex: privateCardIndex,
            ),
            onBack: () => Navigator.pop(context),
            isOnline: profile.isOnline == true,
            displayName: [
              profile.displayName,
              if (profile.age != null) '${profile.age}',
            ].join(', '),
            distanceText: profile.distanceKm != null
              ? (profile.distanceKm == 0 ? '0m' : '${profile.distanceKm} km')
              : null,
            onTapPhoto: (index) => _openPhotoGallery(photos, index),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBasicInfo(profile),
                const SizedBox(height: 20),
                if (_actionSent) _buildActionResult(),
                const SizedBox(height: 24),
                _buildBio(profile),
                if ((profile.bio ?? '').trim().isNotEmpty)
                  const SizedBox(height: 24),
                _buildPersonalInfo(profile),
                const SizedBox(height: 24),
                _buildExpectations(profile),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openPhotoGallery(List<String> photos, int initialIndex) {
    if (photos.isEmpty) {
      return;
    }

    final safeIndex = initialIndex < 0
        ? 0
        : (initialIndex >= photos.length ? photos.length - 1 : initialIndex);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DatingImageGalleryViewer(
          images: photos,
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  Widget _buildPrivateAlbumMediaCard(DatingProfile profile) {
    final l10n = AppLocalizations.of(context);
    final status = profile.privateAlbumAccessStatus;
    final buttonText = _privateAlbumButtonText(status);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151821), Color(0xFF252A38)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: Colors.white, size: 38),
                const SizedBox(height: 10),
                Text(
                  '${l10n.datingPrivatePhotos}: ${profile.privateAlbumPhotoCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'ACCEPTED'
                    ? l10n.datingPrivateAlbumPermissionGranted
                      : status == 'PENDING'
                      ? l10n.datingPrivateAlbumPending
                      : l10n.datingPrivateAlbumRequestPermission,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _handlePrivateAlbumAction(profile),
                  icon: Icon(status == 'ACCEPTED' ? Icons.lock_open : Icons.lock_outline),
                  label: Text(buttonText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo(DatingProfile profile) {
    final chips = <String>[];
    if (profile.role != null) {
      chips.add(DatingConstants.roleLabels[profile.role] ?? profile.role!);
    }
    if (profile.bodyType != null) {
      chips.add(DatingConstants.bodyTypeLabels[profile.bodyType] ?? profile.bodyType!);
    }
    if (profile.ethnicity != null) {
      chips.add(DatingConstants.ethnicityLabels[profile.ethnicity] ?? profile.ethnicity!);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) => _InfoChip(label: c)).toList(),
    );
  }

  Widget _buildActionResult() {
    final l10n = AppLocalizations.of(context);
    final isLike = _lastAction == 'LIKE' || _lastAction == 'SUPERLIKE';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: (isLike ? Colors.pink : Colors.grey).withValues(alpha: 0.15),
      ),
      child: Text(
        isLike
            ? (_lastAction == 'SUPERLIKE' ? l10n.datingSuperLiked : l10n.datingLikedWaitingMatch)
            : l10n.datingPassed,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isLike ? Colors.pink : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPersonalInfo(DatingProfile profile) {
    final l10n = AppLocalizations.of(context);
    final rows = <_InfoRow>[];

    if (profile.heightCm != null) {
      rows.add(_InfoRow(label: l10n.datingHeight, value: '${profile.heightCm} cm'));
    }
    if (profile.weightKg != null) {
      rows.add(_InfoRow(label: l10n.datingWeight, value: '${profile.weightKg} kg'));
    }
    if (profile.bodyHair != null) {
      rows.add(_InfoRow(
        label: l10n.datingBodyHair,
        value: DatingConstants.bodyHairLabels[profile.bodyHair] ?? profile.bodyHair!,
      ));
    }
    if (profile.languages.isNotEmpty) {
      rows.add(_InfoRow(label: l10n.datingLanguages, value: profile.languages.join(', ')));
    }
    if (profile.whereILive != null) {
      rows.add(_InfoRow(label: l10n.datingLivesIn, value: profile.whereILive!));
    }
    if (profile.nationality != null) {
      rows.add(_InfoRow(label: l10n.datingNationality, value: profile.nationality!));
    }
    if (profile.relationshipStatus != null) {
      rows.add(_InfoRow(
        label: l10n.datingRelationship,
        value: DatingConstants.relationshipStatusLabels[profile.relationshipStatus] ??
            profile.relationshipStatus!,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: l10n.datingAboutMe,
      child: Column(
        children: rows.map((r) => _InfoRowWidget(row: r)).toList(),
      ),
    );
  }

  Widget _buildBio(DatingProfile profile) {
    final bio = (profile.bio ?? '').trim();
    if (bio.isEmpty) return const SizedBox.shrink();

    return Text(
      bio,
      style: const TextStyle(fontSize: 14, height: 1.4),
    );
  }

  Widget _buildExpectations(DatingProfile profile) {
    final l10n = AppLocalizations.of(context);
    final hasData = profile.lookingFor.isNotEmpty ||
        profile.whereToMeet.isNotEmpty ||
        profile.preferredTribes.isNotEmpty;

    if (!hasData) return const SizedBox.shrink();

    return _Section(
      title: l10n.datingLookingFor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.lookingFor.isNotEmpty)
            _ChipGroup(
              label: l10n.datingInterestedIn,
              values: profile.lookingFor,
              labelMap: DatingConstants.lookingForLabels,
            ),
          if (profile.whereToMeet.isNotEmpty)
            _ChipGroup(
              label: l10n.datingWhereToMeet,
              values: profile.whereToMeet,
              labelMap: DatingConstants.whereToMeetLabels,
            ),
          if (profile.preferredTribes.isNotEmpty)
            _ChipGroup(
              label: l10n.datingTribes,
              values: profile.preferredTribes,
              labelMap: DatingConstants.tribeLabels,
            ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(Icons.person, color: Colors.white38, size: 80),
      ),
    );
  }
}

// Intercepts vertical drags in the media/avatar area only, routes them
// to the PageView; parent CustomScrollView handles other scroll areas.
class _SwipeMediaArea extends StatelessWidget {
  final double height;
  final PageController pageController;
  final int totalPages;
  final int privateCardIndex;
  final bool hasPrivateCard;
  final List<String> photos;
  final int mediaIndex;
  final ValueChanged<int> onPageChanged;
  final Widget Function() buildPrivateCard;
  final Widget Function() buildPlaceholder;
  final Widget Function() buildDots;
  final VoidCallback onBack;
  final bool isOnline;
  final String displayName;
  final String? distanceText;
  final void Function(int index)? onTapPhoto;

  const _SwipeMediaArea({
    required this.height,
    required this.pageController,
    required this.totalPages,
    required this.privateCardIndex,
    required this.hasPrivateCard,
    required this.photos,
    required this.mediaIndex,
    required this.onPageChanged,
    required this.buildPrivateCard,
    required this.buildPlaceholder,
    required this.buildDots,
    required this.onBack,
    required this.isOnline,
    required this.displayName,
    this.distanceText,
    this.onTapPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Absorb vertical drags in this area and manually drive the PageView
      onVerticalDragEnd: (details) {
        if (totalPages <= 1) return;
        final v = details.primaryVelocity ?? 0;
        if (v < -200 && mediaIndex < totalPages - 1) {
          pageController.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        } else if (v > 200 && mediaIndex > 0) {
          pageController.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      },
      // Consume the drag so parent scroll view doesn't react
      onVerticalDragUpdate: (_) {},
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (totalPages == 0)
              buildPlaceholder()
            else
              PageView.builder(
                controller: pageController,
                scrollDirection: Axis.vertical,
                // Disable built-in scroll physics; driven by GestureDetector above
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalPages,
                onPageChanged: onPageChanged,
                itemBuilder: (context, index) {
                  if (hasPrivateCard && index == privateCardIndex) {
                    return buildPrivateCard();
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      PresignedImage(
                        imageUrl: photos[index],
                        fit: BoxFit.cover,
                        errorWidget: buildPlaceholder(),
                      ),
                      if (onTapPhoto != null)
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onTapPhoto!(index),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.52, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
            if (totalPages > 1)
              Positioned(
                right: 12,
                top: 110,
                child: buildDots(),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!(hasPrivateCard && mediaIndex == privateCardIndex)) ...[
                    Row(
                      children: [
                        if (isOnline)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (distanceText != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Color(0xFFFFF59D),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            distanceText!,
                            style: const TextStyle(
                              color: Color(0xFFFFF59D),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                  if (totalPages > 1)
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.datingSwipeHint,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              top: MediaQuery.of(context).padding.top + 4,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatingImageGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _DatingImageGalleryViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_DatingImageGalleryViewer> createState() => _DatingImageGalleryViewerState();
}

class _DatingImageGalleryViewerState extends State<_DatingImageGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (value) {
          setState(() {
            _index = value;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: PresignedImage(
                imageUrl: widget.images[index],
                fit: BoxFit.contain,
                errorWidget: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MediaDots extends StatelessWidget {
  final int totalPages;
  final int currentIndex;
  final int privateCardIndex;

  const _MediaDots({
    required this.totalPages,
    required this.currentIndex,
    required this.privateCardIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalPages, (index) {
          final active = index == currentIndex;
          final isPrivate = index == privateCardIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: isPrivate
                ? Icon(
                    Icons.lock,
                    size: active ? 16 : 13,
                    color: active ? Colors.white : Colors.white54,
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 8 : 6,
                    height: active ? 8 : 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
          );
        }),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
}

class _InfoRowWidget extends StatelessWidget {
  final _InfoRow row;
  const _InfoRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              row.label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final String label;
  final List<String> values;
  final Map<String, String> labelMap;
  const _ChipGroup({required this.label, required this.values, required this.labelMap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: values.map((v) => _InfoChip(label: labelMap[v] ?? v)).toList(),
          ),
        ],
      ),
    );
  }
}
