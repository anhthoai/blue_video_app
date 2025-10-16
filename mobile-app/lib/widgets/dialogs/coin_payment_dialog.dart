import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/unlocked_posts_provider.dart';

class CoinPaymentDialog extends ConsumerStatefulWidget {
  final int coinCost;
  final bool isVipPost;
  final String? postId; // Add postId to unlock the post
  final VoidCallback? onPaymentSuccess;

  const CoinPaymentDialog({
    super.key,
    required this.coinCost,
    this.isVipPost = false,
    this.postId,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<CoinPaymentDialog> createState() => _CoinPaymentDialogState();

  /// Show the coin payment dialog
  static Future<bool?> show(
    BuildContext context, {
    required int coinCost,
    bool isVipPost = false,
    String? postId,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CoinPaymentDialog(
        coinCost: coinCost,
        isVipPost: isVipPost,
        postId: postId,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }
}

class _CoinPaymentDialogState extends ConsumerState<CoinPaymentDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authServiceProvider);
    final currentUser = authState.currentUser;
    final userCoinBalance = currentUser?.coinBalance ?? 0;

    // Debug logging
    print('🔍 Coin Payment Dialog - Current User: ${currentUser?.toJson()}');
    print('🔍 Coin Balance: $userCoinBalance');
    final hasEnoughCoins = userCoinBalance >= widget.coinCost;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bell Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                size: 48,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 16),

            // Payment Message
            Text(
              hasEnoughCoins
                  ? 'Pay ${widget.coinCost} coins to unlock content'
                  : 'Pay ${widget.coinCost} coins to unlock content, insufficient balance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            if (!hasEnoughCoins) ...[
              const SizedBox(height: 8),
              Text(
                'Please go recharge',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            // Current Balance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Balance: $userCoinBalance coins',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Pay/Recharge Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);

                            if (hasEnoughCoins) {
                              // Process payment
                              final success =
                                  await _processPayment(ref, widget.coinCost);
                              if (context.mounted) {
                                setState(() => _isProcessing = false);
                                Navigator.of(context).pop(success);
                                if (success &&
                                    widget.onPaymentSuccess != null) {
                                  widget.onPaymentSuccess!();
                                }
                              }
                            } else {
                              // Navigate to recharge screen
                              if (context.mounted) {
                                setState(() => _isProcessing = false);
                                Navigator.of(context).pop(false);
                                context.push('/main/coin-recharge');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasEnoughCoins ? Colors.blue : Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            hasEnoughCoins ? 'Unlock Now' : 'Recharge Now',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _processPayment(WidgetRef ref, int coinCost) async {
    try {
      print('🎯 Processing coin payment for $coinCost coins');

      // Check if user has enough coins
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        print('❌ No current user found');
        return false;
      }

      if (currentUser.coinBalance < coinCost) {
        print('❌ Insufficient coins: ${currentUser.coinBalance} < $coinCost');
        return false;
      }

      // Simulate API call to process payment
      print('📡 Calling payment API...');
      await Future.delayed(const Duration(seconds: 1));

      // For demo purposes, simulate successful payment
      print('✅ Payment processed successfully');

      // Update user's coin balance
      final newBalance = currentUser.coinBalance - coinCost;
      await authService.updateUserCoinBalance(newBalance);

      print('✅ User coin balance updated: $newBalance');

      // Unlock the post permanently if postId is provided
      if (widget.postId != null) {
        print('🔓 Unlocking post: ${widget.postId}');
        final apiService = ApiService();
        final unlockSuccess = await apiService.unlockPost(widget.postId!);
        if (unlockSuccess) {
          print('✅ Post unlocked permanently');
          // Mark post as unlocked in memory provider
          ref.read(unlockedPostsProvider.notifier).unlockPost(widget.postId!);
        } else {
          print('⚠️ Failed to unlock post, but payment was processed');
        }
      }

      return true;
    } catch (e) {
      print('❌ Payment error: $e');
      return false;
    }
  }
}

/// VIP Payment Dialog (similar to coin but for VIP posts)
class VipPaymentDialog extends ConsumerWidget {
  final VoidCallback? onPaymentSuccess;

  const VipPaymentDialog({
    super.key,
    this.onPaymentSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authServiceProvider);
    final isVip = authState.currentUser?.isVip ?? false;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // VIP Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.diamond,
                size: 48,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 20),

            // Payment Message
            Text(
              isVip
                  ? 'You already have VIP access'
                  : 'VIP subscription required to view this content',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),
            Text(
              isVip
                  ? 'Enjoy your VIP content!'
                  : 'Upgrade to VIP to access exclusive content',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Subscribe/View Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop(false);

                      if (isVip) {
                        // Already VIP, allow access
                        onPaymentSuccess?.call();
                      } else {
                        // Navigate to VIP subscription screen
                        if (context.mounted) {
                          context.push('/main/vip-subscription');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isVip ? 'View Content' : 'Subscribe VIP',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show the VIP payment dialog
  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VipPaymentDialog(
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }
}
