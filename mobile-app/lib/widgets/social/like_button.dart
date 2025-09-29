import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/social_service.dart';
import '../../models/like_model.dart';

class LikeButton extends ConsumerStatefulWidget {
  final String targetId;
  final LikeType type;
  final String userId;
  final int initialLikeCount;
  final bool initialIsLiked;
  final Color? likedColor;
  final Color? unlikedColor;
  final double size;
  final bool showCount;

  const LikeButton({
    super.key,
    required this.targetId,
    required this.type,
    required this.userId,
    this.initialLikeCount = 0,
    this.initialIsLiked = false,
    this.likedColor,
    this.unlikedColor,
    this.size = 24.0,
    this.showCount = true,
  });

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;
    _likeCount = widget.initialLikeCount;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _colorAnimation = ColorTween(
      begin: widget.unlikedColor ?? Colors.grey,
      end: widget.likedColor ?? Colors.red,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_isLiked) {
      await _unlike();
    } else {
      await _like();
    }
  }

  Future<void> _like() async {
    setState(() {
      _isLiked = true;
      _likeCount++;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);
      await socialService.likeItem(
        userId: widget.userId,
        targetId: widget.targetId,
        type: widget.type,
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = false;
        _likeCount--;
      });
    }
  }

  Future<void> _unlike() async {
    setState(() {
      _isLiked = false;
      _likeCount--;
    });

    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);
      await socialService.unlikeItem(
        userId: widget.userId,
        targetId: widget.targetId,
        type: widget.type,
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = true;
        _likeCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _colorAnimation.value,
                  size: widget.size,
                ),
                if (widget.showCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(_likeCount),
                    style: TextStyle(
                      color: _colorAnimation.value,
                      fontSize: widget.size * 0.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
