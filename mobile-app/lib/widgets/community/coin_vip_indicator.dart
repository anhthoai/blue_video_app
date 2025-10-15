import 'package:flutter/material.dart';

/// Widget to display coin or VIP indicator on post thumbnails
class CoinVipIndicator extends StatelessWidget {
  final bool isCoinPost;
  final bool isVipPost;
  final int coinCost;
  final double size;

  const CoinVipIndicator({
    super.key,
    required this.isCoinPost,
    required this.isVipPost,
    this.coinCost = 0,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    print(
        'CoinVipIndicator: isCoinPost=$isCoinPost, isVipPost=$isVipPost, coinCost=$coinCost');

    if (!isCoinPost && !isVipPost) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isVipPost ? Colors.purple : Colors.amber,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isVipPost ? Icons.diamond : Icons.monetization_on,
          color: Colors.white,
          size: size * 0.7,
        ),
      ),
    );
  }
}

/// Wrapper widget that adds coin/VIP indicator to any widget
class CoinVipThumbnailWrapper extends StatelessWidget {
  final Widget child;
  final bool isCoinPost;
  final bool isVipPost;
  final int coinCost;

  const CoinVipThumbnailWrapper({
    super.key,
    required this.child,
    required this.isCoinPost,
    required this.isVipPost,
    this.coinCost = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        CoinVipIndicator(
          isCoinPost: isCoinPost,
          isVipPost: isVipPost,
          coinCost: coinCost,
        ),
      ],
    );
  }
}

/// Widget to display coin cost text overlay
class CoinCostOverlay extends StatelessWidget {
  final int coinCost;
  final bool isVipPost;

  const CoinCostOverlay({
    super.key,
    required this.coinCost,
    this.isVipPost = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVipPost && coinCost <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 4,
      right: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVipPost ? Icons.diamond : Icons.monetization_on,
              color: isVipPost ? Colors.purple : Colors.amber,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              isVipPost ? 'VIP' : '$coinCost',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
