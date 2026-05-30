import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/dialogs/usdt_payment_dialog.dart';

class VipSubscriptionScreen extends ConsumerStatefulWidget {
  final String authorId;
  final String authorName;
  final String? authorAvatar;

  const VipSubscriptionScreen({
    super.key,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
  });

  @override
  ConsumerState<VipSubscriptionScreen> createState() =>
      _VipSubscriptionScreenState();
}

class _VipSubscriptionScreenState extends ConsumerState<VipSubscriptionScreen> {
  List<Map<String, dynamic>> vipPackages = [];
  bool isLoading = true;
  String? errorMessage;
  int selectedPackageIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadVipPackages();
  }

  Future<void> _loadVipPackages() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      print('🔍 Loading VIP packages for author: ${widget.authorId}');
      final packages = await ApiService().getVipPackages(widget.authorId);

      setState(() {
        vipPackages = packages;
        isLoading = false;
      });

      print('✅ Loaded ${packages.length} VIP packages');
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
      print('❌ Error loading VIP packages: $e');
    }
  }

  Future<void> _subscribeToVip(int packageIndex) async {
    if (packageIndex < 0 || packageIndex >= vipPackages.length) return;

    final package = vipPackages[packageIndex];
    final packageId = package['id'] as String;

    try {
      print('🔍 Creating VIP subscription for package: $packageId');
      final subscriptionData = await ApiService().createVipSubscription(
        widget.authorId,
        packageId,
      );

      print(
          '✅ VIP subscription created: ${subscriptionData['subscription']['id']}');

      final payment = subscriptionData['payment'];
      final paymentMethod = payment['method'] as String;
      final paymentStatus = payment['status'] as String;

      if (mounted) {
        if (paymentMethod == 'COINS' && paymentStatus == 'COMPLETED') {
          // Payment completed with coins - show detailed success message
          final package = vipPackages[packageIndex];
          final coins = (package['coins'] is String)
              ? int.parse(package['coins'] as String)
              : (package['coins'] as int);
          final duration = package['duration'] as String;

          _showCoinPaymentSuccessDialog(coins, duration);
        } else {
          // Default payment path: OxaPay USDT TRC20
          _showUsdtPaymentDialog(payment);
        }
      }
    } catch (e) {
      print('❌ Error creating VIP subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUsdtPaymentDialog(Map<String, dynamic> paymentData) {
    UsdtPaymentDialog.show(
      context,
      paymentData: paymentData,
      onPaymentComplete: () async {
        Navigator.of(context).pop();

        // Refresh user data to get updated VIP status
        print('🔄 Refreshing user data after VIP subscription...');
        await ref.read(authServiceProvider).refreshCurrentUser();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('VIP subscription activated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Navigate back
          context.pop();
        }
      },
      onCancel: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showCoinPaymentSuccessDialog(int coins, String duration) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Subscription Activated!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your VIP subscription has been activated successfully!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Payment Method: Coins',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      '• Amount Paid: $coins coins',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      '• Duration: ${_getDurationText(duration)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      '• Status: Active',
                      style: TextStyle(fontSize: 14, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You can now access all VIP content from this author!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Refresh user data to get updated VIP status
              print('🔄 Refreshing user data after VIP subscription...');
              await ref.read(authServiceProvider).refreshCurrentUser();

              if (mounted) {
                context.pop(); // Navigate back to previous screen
              }
            },
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDurationText(String duration) {
    switch (duration) {
      case 'ONE_MONTH':
        return '1 Month';
      case 'THREE_MONTHS':
        return '3 Months';
      case 'SIX_MONTHS':
        return '6 Months';
      case 'TWELVE_MONTHS':
        return '12 Months';
      default:
        return duration;
    }
  }

  String _getDurationDescription(String duration) {
    switch (duration) {
      case 'ONE_MONTH':
        return 'Perfect for trying out VIP content';
      case 'THREE_MONTHS':
        return 'Great value for regular followers';
      case 'SIX_MONTHS':
        return 'Best value for dedicated fans';
      case 'TWELVE_MONTHS':
        return 'Ultimate VIP experience';
      default:
        return 'VIP subscription';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'VIP Subscription',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Author info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: widget.authorAvatar != null
                                ? NetworkImage(widget.authorAvatar!)
                                : null,
                            child: widget.authorAvatar == null
                                ? const Icon(Icons.person,
                                    color: Colors.white, size: 24)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Subscribe to ${widget.authorName}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Get exclusive VIP content and support your favorite creator',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load VIP packages',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadVipPackages,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        )
                      : vipPackages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No VIP packages available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This author hasn\'t set up VIP packages yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: vipPackages.length,
                              itemBuilder: (context, index) {
                                final package = vipPackages[index];
                                final duration = package['duration'] as String;
                                final coins = (package['coins'] is String)
                                    ? int.parse(package['coins'] as String)
                                    : (package['coins'] as int);
                                final isSelected =
                                    selectedPackageIndex == index;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF8B5CF6)
                                          : Colors.grey[300]!,
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
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedPackageIndex = index;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(0xFF8B5CF6)
                                                          .withOpacity(0.1)
                                                      : Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.star,
                                                  color: isSelected
                                                      ? const Color(0xFF8B5CF6)
                                                      : Colors.grey[600],
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _getDurationText(
                                                          duration),
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF8B5CF6)
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                    Text(
                                                      _getDurationDescription(
                                                          duration),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${coins} coins',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF8B5CF6)
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Author earns ${coins} coins',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            // Subscribe button
            if (!isLoading && errorMessage == null && vipPackages.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedPackageIndex >= 0
                          ? () => _subscribeToVip(selectedPackageIndex)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selectedPackageIndex >= 0
                            ? 'Subscribe to ${_getDurationText(vipPackages[selectedPackageIndex]['duration'])}'
                            : 'Select a package',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
