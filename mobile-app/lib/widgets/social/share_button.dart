import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/social_service.dart';

class ShareButton extends ConsumerStatefulWidget {
  final String contentId;
  final String contentType; // 'video', 'user', 'comment'
  final String userId;
  final int shareCount;
  final Color? color;
  final double size;
  final bool showCount;

  const ShareButton({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.userId,
    this.shareCount = 0,
    this.color,
    this.size = 24.0,
    this.showCount = true,
  });

  @override
  ConsumerState<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends ConsumerState<ShareButton> {
  bool _isSharing = false;

  Future<void> _shareContent() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      final socialService = SocialService();
      final success = await socialService.shareContent(
        userId: widget.userId,
        contentId: widget.contentId,
        contentType: widget.contentType,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content shared successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share to',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () => _shareToPlatform('facebook'),
                ),
                _buildShareOption(
                  icon: Icons.alternate_email,
                  label: 'Twitter',
                  color: const Color(0xFF1DA1F2),
                  onTap: () => _shareToPlatform('twitter'),
                ),
                _buildShareOption(
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  color: const Color(0xFFE4405F),
                  onTap: () => _shareToPlatform('instagram'),
                ),
                _buildShareOption(
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareToPlatform('whatsapp'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: Colors.grey[600]!,
                  onTap: _copyLink,
                ),
                _buildShareOption(
                  icon: Icons.more_horiz,
                  label: 'More',
                  color: Colors.grey[600]!,
                  onTap: _shareToMore,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToPlatform(String platform) async {
    Navigator.pop(context);

    try {
      final socialService = SocialService();
      await socialService.shareContent(
        userId: widget.userId,
        contentId: widget.contentId,
        contentType: widget.contentType,
        platforms: [platform],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to ${platform.toUpperCase()}!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share to $platform: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyLink() {
    Navigator.pop(context);

    // In a real app, you would copy the actual link
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareToMore() {
    Navigator.pop(context);

    // In a real app, you would use the system share sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening system share sheet...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isSharing ? null : _showShareOptions,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isSharing
              ? SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.color ?? Colors.grey,
                    ),
                  ),
                )
              : Icon(
                  Icons.share,
                  color: widget.color ?? Colors.grey,
                  size: widget.size,
                ),
          if (widget.showCount) ...[
            const SizedBox(width: 4),
            Text(
              _formatCount(widget.shareCount),
              style: TextStyle(
                color: widget.color ?? Colors.grey,
                fontSize: widget.size * 0.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
