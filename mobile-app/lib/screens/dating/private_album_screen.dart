import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/dating_service.dart';
import '../../models/dating_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/presigned_image.dart';

final _albumProvider =
    FutureProvider.autoDispose.family<DatingProfile?, String?>((ref, targetUserId) async {
  if (targetUserId == null || targetUserId.isEmpty) {
    return DatingService().getMyDatingProfile();
  }
  return DatingService().getDatingProfile(targetUserId);
});

class PrivateAlbumScreen extends ConsumerStatefulWidget {
  final String? targetUserId; // null = own album
  final bool readOnly;
  const PrivateAlbumScreen({
    super.key,
    this.targetUserId,
    this.readOnly = false,
  });

  @override
  ConsumerState<PrivateAlbumScreen> createState() =>
      _PrivateAlbumScreenState();
}

class _PrivateAlbumScreenState extends ConsumerState<PrivateAlbumScreen> {
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _isOwner = widget.targetUserId == null && !widget.readOnly;
  }

  Future<void> _upload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    try {
      await DatingService().uploadPrivatePhoto(File(file.path));
      if (mounted) {
        ref.invalidate(_albumProvider(widget.targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Remove this photo from your private album?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DatingService().deletePrivatePhoto(index);
      if (mounted) ref.invalidate(_albumProvider(widget.targetUserId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_albumProvider(widget.targetUserId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwner ? 'My Private Album' : 'Private Album'),
        actions: [
          if (_isOwner)
            TextButton.icon(
              onPressed: () => _showAccessRequests(context),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Requests'),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          final photos = profile?.privateAlbumPhotos ?? [];
          return _buildGrid(context, photos);
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<String> photos) {
    // Add an "add" cell if owner and under limit
    final canAdd = _isOwner && photos.length < 9;
    final itemCount = photos.length + (canAdd ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == photos.length && canAdd) {
            return _AddPhotoCell(onTap: _upload);
          }
          return _PhotoCell(
            url: photos[index],
            canDelete: _isOwner,
            onDelete: () => _delete(index),
            onTap: () => _showFullScreen(context, photos, index),
          );
        },
      ),
    );
  }

  void _showFullScreen(
      BuildContext context, List<String> photos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenGallery(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  void _showAccessRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _AccessRequestsScreen(),
      ),
    );
  }
}

// ─── Photo cell ──────────────────────────────────────────────────────────────

class _PhotoCell extends StatelessWidget {
  final String url;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PhotoCell({
    required this.url,
    required this.canDelete,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PresignedImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: Colors.grey.shade800,
                child: const Icon(Icons.broken_image, color: Colors.white38),
              ),
            ),
            if (canDelete)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoCell extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoCell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Icon(
          Icons.add_photo_alternate_outlined,
          color: AppTheme.primaryColor,
          size: 36,
        ),
      ),
    );
  }
}

// ─── Full-screen gallery ─────────────────────────────────────────────────────

class _FullScreenGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _FullScreenGallery(
      {required this.photos, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
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
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: PresignedImage(
                imageUrl: widget.photos[index],
                fit: BoxFit.contain,
                errorWidget: const Icon(Icons.broken_image, color: Colors.white38),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Access requests sub-screen ──────────────────────────────────────────────

class _AccessRequestsScreen extends ConsumerWidget {
  const _AccessRequestsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = FutureProvider.autoDispose(
      (_) => DatingService().getPrivateAlbumAccessRequests(type: 'received'),
    );
    final data = ref.watch(requestsAsync);

    return Scaffold(
      appBar: AppBar(title: const Text('Access Requests')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (requests) => requests.isEmpty
            ? const Center(child: Text('No pending requests'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) =>
                    _RequestTile(request: requests[index], ref: ref),
              ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final PrivateAlbumAccessRequest request;
  final WidgetRef ref;
  const _RequestTile({required this.request, required this.ref});

  Future<void> _respond(BuildContext context, String status) async {
    try {
      await DatingService().respondPrivateAlbumAccess(request.id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'ACCEPTED' ? 'Accepted!' : 'Denied')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (request.requester?['avatarUrl'] as String?) != null
            ? NetworkImage(request.requester!['avatarUrl'] as String)
            : null,
        child: request.requester?['avatarUrl'] == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        (request.requester?['firstName'] ?? request.requester?['username'] ?? 'User') as String,
      ),
      subtitle: const Text('Wants to see your private album'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _respond(context, 'ACCEPTED'),
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          ),
          IconButton(
            onPressed: () => _respond(context, 'DENIED'),
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
