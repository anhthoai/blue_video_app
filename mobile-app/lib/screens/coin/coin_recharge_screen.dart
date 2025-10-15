import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/dialogs/coin_payment_dialog.dart';

class CoinRechargeScreen extends ConsumerStatefulWidget {
  const CoinRechargeScreen({super.key});

  @override
  ConsumerState<CoinRechargeScreen> createState() => _CoinRechargeScreenState();
}

class _CoinRechargeScreenState extends ConsumerState<CoinRechargeScreen> {
  int selectedPackageIndex = 0;
  bool isLoading = false;

  final List<CoinPackage> coinPackages = [
    CoinPackage(coins: 100, price: 100, usdPrice: 10.0),
    CoinPackage(coins: 200, price: 200, usdPrice: 20.0),
    CoinPackage(coins: 500, price: 500, usdPrice: 50.0),
    CoinPackage(coins: 1000, price: 1000, usdPrice: 100.0),
    CoinPackage(coins: 2000, price: 2000, usdPrice: 200.0),
    CoinPackage(coins: 10000, price: 10000, usdPrice: 1000.0),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authServiceProvider);
    final userCoinBalance = authState.currentUser?.coinBalance ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Top bar
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'Coin Recharge',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to recharge record
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Recharge Record')),
                            );
                          },
                          child: const Text(
                            'Recharge Record',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Coin balance card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Coin Balance',
                                style: TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Coin Details')),
                                  );
                                },
                                child: const Text(
                                  'Coin Details',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$userCoinBalance',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Online recharge tab
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Online Recharge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Coin packages grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: coinPackages.length,
                        itemBuilder: (context, index) {
                          final package = coinPackages[index];
                          final isSelected = selectedPackageIndex == index;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedPackageIndex = index;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Coin icon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.monetization_on,
                                      color: Colors.amber,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Coin amount
                                  Text(
                                    '${package.coins} Coins',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Price
                                  Text(
                                    '¥${package.price}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Recharge button
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _processRecharge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Recharge Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tips section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tips',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. If multiple recharges fail, and the amount has not arrived for a long time and has not been refunded, please contact customer service in [Personal Center] - [Feedback] and send a screenshot of the payment voucher for processing.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '2. Please try to pay within two minutes of generating the order. If payment cannot be made, you can try to re-initiate the order request.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ],
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
  }

  Future<void> _processRecharge() async {
    if (selectedPackageIndex < 0 ||
        selectedPackageIndex >= coinPackages.length) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final selectedPackage = coinPackages[selectedPackageIndex];

      // Show payment dialog
      final success = await CoinPaymentDialog.show(
        context,
        coinCost: selectedPackage.coins,
        isVipPost: false,
        onPaymentSuccess: () {
          // Update user's coin balance
          final authService = ref.read(authServiceProvider);
          final currentUser = authService.currentUser;
          if (currentUser != null) {
            final updatedUser = currentUser.copyWith(
              coinBalance: currentUser.coinBalance + selectedPackage.coins,
            );
            // TODO: Implement updateCurrentUser method in AuthService
            // authService.updateCurrentUser(updatedUser);
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Successfully recharged ${selectedPackage.coins} coins!'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          }
        },
      );

      if (success == null && context.mounted) {
        // User cancelled or payment failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recharge cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recharge failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}

class CoinPackage {
  final int coins;
  final int price; // in cents or local currency
  final double usdPrice; // in USD

  const CoinPackage({
    required this.coins,
    required this.price,
    required this.usdPrice,
  });
}
