import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../widgets/dialogs/payment_method_dialog.dart';
import '../../widgets/dialogs/usdt_payment_dialog.dart';
import '../../widgets/dialogs/credit_card_payment_dialog.dart';

class CoinRechargeScreen extends ConsumerStatefulWidget {
  const CoinRechargeScreen({super.key});

  @override
  ConsumerState<CoinRechargeScreen> createState() => _CoinRechargeScreenState();
}

class _CoinRechargeScreenState extends ConsumerState<CoinRechargeScreen> {
  int selectedPackageIndex = 0;
  bool isLoading = false;
  List<Map<String, dynamic>> coinPackages = [];
  String selectedCurrency = 'BTC';

  @override
  void initState() {
    super.initState();
    _loadCoinPackages();
    _refreshUserBalance();

    // Debug: Print current user data
    final currentUser = ref.read(currentUserProvider);
    print('🔍 Coin Recharge Screen - Current User: ${currentUser?.toJson()}');
    print('🔍 Coin Balance: ${currentUser?.coinBalance}');
  }

  Future<void> _loadCoinPackages() async {
    try {
      setState(() => isLoading = true);
      print('🎯 Loading coin packages...');
      final packages = await ApiService().getCoinPackages();
      print('🎯 Loaded ${packages.length} packages: $packages');
      setState(() {
        coinPackages = packages;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('🎯 Error loading coin packages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load coin packages: $e')),
        );
      }
    }
  }

  Future<void> _processRecharge() async {
    if (coinPackages.isEmpty || selectedPackageIndex >= coinPackages.length) {
      print('⚠️ No package selected or packages not loaded');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a coin package')),
      );
      return;
    }

    final selectedPackage = coinPackages[selectedPackageIndex];
    final coins = selectedPackage['coins'] as int;
    final usdAmount = selectedPackage['usd'] as num;

    print('🎯 Processing recharge for $coins coins (\$${usdAmount})');

    // Show payment method selection dialog
    if (mounted) {
      final selectedMethod = await PaymentMethodDialog.show(
        context,
        coins: coins,
        usdAmount: usdAmount.toDouble(),
      );

      if (selectedMethod != null) {
        await _createPaymentInvoice(selectedMethod, coins);
      }
    }
  }

  Future<void> _createPaymentInvoice(PaymentMethod method, int coins) async {
    try {
      setState(() => isLoading = true);

      Map<String, dynamic> paymentData;

      if (method == PaymentMethod.usdt) {
        print('📝 Creating USDT payment invoice...');
        paymentData = await ApiService().createUsdtPaymentInvoice(coins: coins);
      } else {
        print('📝 Creating Credit Card payment invoice...');
        paymentData =
            await ApiService().createCreditCardPaymentInvoice(coins: coins);
      }

      print('✅ Payment invoice created: $paymentData');

      setState(() => isLoading = false);

      // Show appropriate payment dialog
      if (mounted) {
        if (method == PaymentMethod.usdt) {
          _showUsdtPaymentDialog(paymentData);
        } else {
          _showCreditCardPaymentDialog(paymentData);
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('❌ Payment failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  void _showUsdtPaymentDialog(Map<String, dynamic> paymentData) {
    UsdtPaymentDialog.show(
      context,
      paymentData: paymentData,
      onPaymentComplete: () {
        Navigator.of(context).pop();
        // Refresh user balance and update UI
        _refreshUserBalance();
        // Force rebuild to show updated balance
        setState(() {});
      },
      onCancel: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showCreditCardPaymentDialog(Map<String, dynamic> paymentData) {
    CreditCardPaymentDialog.show(
      context,
      paymentData: paymentData,
      onPaymentComplete: () {
        Navigator.of(context).pop();
        // Refresh user balance and update UI
        _refreshUserBalance();
        // Force rebuild to show updated balance
        setState(() {});
      },
      onCancel: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showPaymentDialog(Map<String, dynamic> paymentData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        paymentData: paymentData,
        onPaymentComplete: () {
          Navigator.of(context).pop();
          // Refresh user balance and update UI
          _refreshUserBalance();
          // Force rebuild to show updated balance
          setState(() {});
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _refreshUserBalance() async {
    try {
      print('🔄 Refreshing user balance...');
      await ref.read(authServiceProvider).refreshCurrentUser();

      // Debug: Print updated user data
      final updatedUser = ref.read(currentUserProvider);
      print('✅ User balance refreshed: ${updatedUser?.coinBalance}');
    } catch (e) {
      print('❌ Failed to refresh user balance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final userCoinBalance = currentUser?.coinBalance ?? 0;

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
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Coin Recharge',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.push('/main/coin-history');
                      },
                      child: const Text(
                        'Recharge Record',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coin Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Coin Balance',
                            style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$userCoinBalance',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              // TODO: Show coin details
                            },
                            child: const Text(
                              'Coin Details',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Online Recharge Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Online Recharge',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFEC4899),
                                      Color(0xFF8B5CF6)
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.monetization_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Coin Packages Grid
                          if (isLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF8B5CF6),
                              ),
                            )
                          else if (coinPackages.isNotEmpty)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: coinPackages.length,
                              itemBuilder: (context, index) {
                                final package = coinPackages[index];
                                final isSelected =
                                    selectedPackageIndex == index;
                                final coins = package['coins'] as int;
                                final usdPrice = package['usd'] is int
                                    ? (package['usd'] as int).toDouble()
                                    : package['usd'] as double;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedPackageIndex = index;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF8B5CF6)
                                              .withOpacity(0.1)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF8B5CF6)
                                            : Colors.grey.withOpacity(0.3),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Coin Icon
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFFFFD700),
                                                Color(0xFFFFA500)
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.monetization_on,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        // Coins Text
                                        Text(
                                          '${coins} Coins',
                                          style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFF8B5CF6)
                                                : const Color(0xFFEC4899),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        // Price Text
                                        Text(
                                          '\$${usdPrice.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            const Center(
                              child: Text('No coin packages available'),
                            ),

                          const SizedBox(height: 24),

                          // Recharge Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _processRecharge,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Recharge Now',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tips Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
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
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. If multiple recharges fail, the amount has not arrived for a long time, and the consumption amount has not been refunded, please contact customer service in [Personal Center] - [Feedback] and send a screenshot of the payment certificate for processing.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '2. Please try to pay within two minutes of generating the order. If you cannot pay, you can try to re-initiate the order request.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
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
}

class PaymentDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> paymentData;
  final VoidCallback onPaymentComplete;
  final VoidCallback onCancel;

  const PaymentDialog({
    super.key,
    required this.paymentData,
    required this.onPaymentComplete,
    required this.onCancel,
  });

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  bool isPaymentCompleted = false;
  bool isProcessing = false;

  Future<void> _processPaymentCompletion() async {
    if (isProcessing) return;

    setState(() => isProcessing = true);

    try {
      final paymentData = widget.paymentData;
      final coins = paymentData['coins'] as int;

      print('🎯 Processing payment completion for $coins coins');

      // Get current user
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Add coins to user's balance
      final newBalance = currentUser.coinBalance + coins;
      await authService.updateUserCoinBalance(
        newBalance,
        transactionType: 'RECHARGE',
        description: 'Coin recharge - $coins coins',
        paymentId: paymentData['paymentId'] as String?,
      );

      print(
          '✅ Payment completed! Added $coins coins. New balance: $newBalance');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added $coins coins to your account!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Close dialog and notify parent
      widget.onPaymentComplete();
    } catch (e) {
      print('❌ Payment completion failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentData = widget.paymentData;
    final coins = paymentData['coins'] as int;
    final usdAmount = paymentData['usdAmount'] is int
        ? (paymentData['usdAmount'] as int).toDouble()
        : paymentData['usdAmount'] as double;
    final address = paymentData['address'] as String;
    final qrCode = paymentData['qrCode'] as String;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.qr_code,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Payment Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${coins} Coins',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${usdAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // QR Code or Demo Message
            if (qrCode.isNotEmpty && qrCode != 'demo_qr_code_base64_data')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Scan QR Code to Pay',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // QR Code placeholder - in real implementation, decode base64 QR code
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'QR Code\n(Demo Mode)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Demo Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Demo mode: Click "I Have Paid" to complete',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Payment Address
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Address:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    address,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            // Process the actual payment and add coins
                            await _processPaymentCompletion();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'I Have Paid',
                            style: TextStyle(color: Colors.white),
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
}
