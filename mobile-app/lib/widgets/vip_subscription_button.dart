import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VipSubscriptionButton extends StatelessWidget {
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final bool isCurrentUser;
  final bool isVipSubscribed;

  const VipSubscriptionButton({
    super.key,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.isCurrentUser = false,
    this.isVipSubscribed = false,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show button for current user
    if (isCurrentUser) {
      return const SizedBox.shrink();
    }

    // If already subscribed, show different button
    if (isVipSubscribed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              color: Colors.green,
              size: 16,
            ),
            const SizedBox(width: 6),
            const Text(
              'VIP Subscribed',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Show subscribe button
    return ElevatedButton.icon(
      onPressed: () {
        final uri = Uri(
          path: '/main/vip-subscription/$authorId',
          queryParameters: {
            'name': authorName,
            if (authorAvatar != null) 'avatar': authorAvatar!,
          },
        );
        context.push(uri.toString());
      },
      icon: const Icon(
        Icons.star,
        color: Colors.white,
        size: 16,
      ),
      label: const Text(
        'Subscribe VIP',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
      ),
    );
  }
}
