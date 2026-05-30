import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../widgets/dialogs/payment_method_dialog.dart';
import '../../l10n/app_localizations.dart';

const String _pendingPaymentOrderKey = 'pending_payment_order_id';

class CoinRechargeScreen extends ConsumerStatefulWidget {
  final String? initialOrderId;
  final bool initialPaymentSuccess;

  const CoinRechargeScreen({
    super.key,
    this.initialOrderId,
    this.initialPaymentSuccess = false,
  });

  @override
  ConsumerState<CoinRechargeScreen> createState() => _CoinRechargeScreenState();
}

class _CoinRechargeScreenState extends ConsumerState<CoinRechargeScreen> {
  int selectedPackageIndex = 0;
  bool isLoading = false;
  List<Map<String, dynamic>> coinPackages = [];

  @override
  void initState() {
    super.initState();
    _loadCoinPackages();
    _refreshUserBalance();

    if (widget.initialOrderId != null && widget.initialOrderId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(
          '/main/payment-processing?orderId=${Uri.encodeComponent(widget.initialOrderId!)}',
        );
      });
    }

    if (widget.initialPaymentSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paymentConfirmedCoinsAdded),
            backgroundColor: Colors.green,
          ),
        );
      });
    }

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
      if (!mounted) return;
      setState(() {
        coinPackages = packages;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      print('🎯 Error loading coin packages: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToLoadCoinPackages}: $e')),
        );
      }
    }
  }

  Future<void> _processRecharge() async {
    if (coinPackages.isEmpty || selectedPackageIndex >= coinPackages.length) {
      print('⚠️ No package selected or packages not loaded');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseSelectCoinPackage)),
        );
      }
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

      if (method == PaymentMethod.creditCard) {
        if (!mounted) return;
        setState(() => isLoading = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.creditCardComingSoon),
            backgroundColor: Colors.blueGrey,
          ),
        );
        return;
      }

      Map<String, dynamic> paymentData;
      print('📝 Creating USDT payment invoice...');
      paymentData = await ApiService().createUsdtPaymentInvoice(coins: coins);

      print('✅ Payment invoice created: $paymentData');

      if (!mounted) return;
      setState(() => isLoading = false);

      await _launchExternalPaymentFlow(paymentData);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      print('❌ Payment failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.paymentFailed}: $e')),
        );
      }
    }
  }

  Future<void> _launchExternalPaymentFlow(Map<String, dynamic> paymentData) async {
    final l10n = AppLocalizations.of(context);
    final orderId = paymentData['orderId']?.toString();
    final paymentUri = paymentData['paymentUri']?.toString() ?? '';

    if (orderId == null || orderId.isEmpty || paymentUri.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToOpenPaymentGateway),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPaymentOrderKey, orderId);

    final launched = await launchUrl(
      Uri.parse(paymentUri),
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      await prefs.remove(_pendingPaymentOrderKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.couldNotOpenBrowserForPayment),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await context.push<bool>(
      '/main/payment-processing?orderId=${Uri.encodeComponent(orderId)}',
    );

    if (confirmed == true && mounted) {
      await prefs.remove(_pendingPaymentOrderKey);
      await _refreshUserBalance();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentConfirmedCoinsAdded),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _refreshUserBalance() async {
    try {
      print('🔄 Refreshing user balance...');
      await ref.read(authServiceProvider).refreshCurrentUser();

      // Debug: Print updated user data
      final updatedUser = ref.read(currentUserProvider);
      print('✅ User balance refreshed: ${updatedUser?.coinBalance}');

      // Only update UI if widget is still mounted
      if (mounted) {
        setState(() {});
      }
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
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).coinRecharge,
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
                      child: Text(
                        AppLocalizations.of(context).rechargeRecord,
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
                          Text(
                            AppLocalizations.of(context).coinBalance,
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
                            child: Text(
                              AppLocalizations.of(context).coinDetails,
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
                                child: Text(
                                  AppLocalizations.of(context).onlineRecharge,
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
                                    _processRecharge();
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
                                          '$coins ${AppLocalizations.of(context).coins}',
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
                            Center(
                              child: Text(AppLocalizations.of(context)
                                  .noCoinPackagesAvailable),
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
                                  : Text(
                                      AppLocalizations.of(context).rechargeNow,
                                      style: const TextStyle(
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
