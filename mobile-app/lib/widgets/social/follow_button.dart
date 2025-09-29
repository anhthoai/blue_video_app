import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/social_service.dart';

class FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  final String currentUserId;
  final bool initialIsFollowing;
  final Color? followingColor;
  final Color? notFollowingColor;
  final double? width;
  final double height;
  final double borderRadius;
  final String? followingText;
  final String? notFollowingText;

  const FollowButton({
    super.key,
    required this.targetUserId,
    required this.currentUserId,
    this.initialIsFollowing = false,
    this.followingColor,
    this.notFollowingColor,
    this.width,
    this.height = 32.0,
    this.borderRadius = 16.0,
    this.followingText,
    this.notFollowingText,
  });

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: widget.notFollowingColor ?? Colors.blue,
      end: widget.followingColor ?? Colors.grey,
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

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);

      if (_isFollowing) {
        await socialService.unfollowUser(
          followerId: widget.currentUserId,
          followingId: widget.targetUserId,
        );
      } else {
        await socialService.followUser(
          followerId: widget.currentUserId,
          followingId: widget.targetUserId,
        );
      }

      setState(() {
        _isFollowing = !_isFollowing;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowing ? 'Following user!' : 'Unfollowed user!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _isLoading ? null : _toggleFollow,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: _isFollowing
                    ? (widget.followingColor ?? Colors.grey)
                    : (widget.notFollowingColor ?? Colors.blue),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: _isFollowing
                    ? Border.all(
                        color: widget.followingColor ?? Colors.grey,
                        width: 1,
                      )
                    : null,
              ),
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isFollowing ? Colors.grey : Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        _isFollowing
                            ? (widget.followingText ?? 'Following')
                            : (widget.notFollowingText ?? 'Follow'),
                        style: TextStyle(
                          color: _isFollowing ? Colors.grey[700] : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
