import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/nsfw_settings_service.dart';
import '../dialogs/nsfw_confirmation_dialog.dart';

/// Wrapper widget that blurs NSFW content and shows confirmation dialog
class NsfwBlurWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final bool isNsfw;
  final VoidCallback? onUnblur;

  const NsfwBlurWrapper({
    super.key,
    required this.child,
    required this.isNsfw,
    this.onUnblur,
  });

  @override
  ConsumerState<NsfwBlurWrapper> createState() => _NsfwBlurWrapperState();
}

class _NsfwBlurWrapperState extends ConsumerState<NsfwBlurWrapper> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final nsfwSettings = ref.watch(nsfwSettingsProvider);

    // If not NSFW, show content directly
    if (!widget.isNsfw) {
      return widget.child;
    }

    // If user has enabled NSFW viewing, show content directly
    if (nsfwSettings.isNsfwViewingEnabled) {
      return widget.child;
    }

    // Otherwise, show blurred content with overlay
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Blurred content
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: widget.child,
        ),

        // Dark overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),

        // Warning overlay
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isProcessing ? null : _handleTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.visibility_off,
                        size: 24,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'NSFW Content',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Tap to view (18+)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show confirmation dialog
      final confirmed = await NsfwConfirmationDialog.show(context);

      if (confirmed == true) {
        // User confirmed age and enabled NSFW viewing
        // The state will update automatically via Riverpod
        widget.onUnblur?.call();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}

/// Wrapper for NSFW video thumbnails
class NsfwVideoThumbnailWrapper extends ConsumerStatefulWidget {
  final String thumbnailUrl;
  final bool isNsfw;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onTap;

  const NsfwVideoThumbnailWrapper({
    super.key,
    required this.thumbnailUrl,
    required this.isNsfw,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  ConsumerState<NsfwVideoThumbnailWrapper> createState() =>
      _NsfwVideoThumbnailWrapperState();
}

class _NsfwVideoThumbnailWrapperState
    extends ConsumerState<NsfwVideoThumbnailWrapper> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final nsfwSettings = ref.watch(nsfwSettingsProvider);

    // Build the thumbnail image
    final thumbnailWidget = Image.network(
      widget.thumbnailUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: const Icon(Icons.error, color: Colors.grey),
        );
      },
    );

    // If not NSFW or user has enabled NSFW viewing, show thumbnail directly
    if (!widget.isNsfw || nsfwSettings.isNsfwViewingEnabled) {
      return GestureDetector(
        onTap: widget.onTap,
        child: thumbnailWidget,
      );
    }

    // Otherwise, show blurred thumbnail with overlay
    return GestureDetector(
      onTap: _isProcessing ? null : _handleTap,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Blurred thumbnail
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: thumbnailWidget,
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          // NSFW badge
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.visibility_off,
                      size: 20,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NSFW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show confirmation dialog
      final confirmed = await NsfwConfirmationDialog.show(context);

      if (confirmed == true) {
        // User confirmed age and enabled NSFW viewing
        // Now call the onTap callback
        widget.onTap?.call();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
