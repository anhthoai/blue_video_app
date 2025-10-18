import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../core/services/auth_service.dart';

class UsdtPaymentDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> paymentData;
  final VoidCallback onPaymentComplete;
  final VoidCallback onCancel;

  const UsdtPaymentDialog({
    super.key,
    required this.paymentData,
    required this.onPaymentComplete,
    required this.onCancel,
  });

  @override
  ConsumerState<UsdtPaymentDialog> createState() => _UsdtPaymentDialogState();

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> paymentData,
    required VoidCallback onPaymentComplete,
    required VoidCallback onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UsdtPaymentDialog(
        paymentData: paymentData,
        onPaymentComplete: onPaymentComplete,
        onCancel: onCancel,
      ),
    );
  }
}

class _UsdtPaymentDialogState extends ConsumerState<UsdtPaymentDialog> {
  bool isPaymentCompleted = false;

  @override
  Widget build(BuildContext context) {
    final paymentData = widget.paymentData;
    final amount = paymentData['amount'] is String
        ? double.parse(paymentData['amount'] as String)
        : (paymentData['amount'] as double? ?? 0.0);
    final address = paymentData['address'] as String? ?? '';
    final qrCode = paymentData['qrCode'] as String? ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'USDT (TRC20)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Recharge Amount
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Recharge Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      amount.toStringAsFixed(8),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Text(
                  'Please do not repeat payment or modify the amount, otherwise, it may not be credited, and we will not be responsible',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    // QR Code Image
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: qrCode.isNotEmpty
                          ? Image.memory(
                              base64Decode(qrCode),
                              fit: BoxFit.contain,
                            )
                          : const Center(
                              child: Icon(
                                Icons.qr_code,
                                size: 100,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Withdrawal Address:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: Text(
                              address,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: () => _copyToClipboard(address),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                'Copy',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Recharge Amount Copy
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Flexible(
                      flex: 2,
                      child: Text(
                        'Recharge Amount: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: Text(
                        amount.toStringAsFixed(8),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: () =>
                            _copyToClipboard(amount.toStringAsFixed(8)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'Copy',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Important Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Warm Reminder',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When recharging via third-party platforms (Binance, OKX, etc.), the third-party platform may deduct a handling fee. Please confirm that the "actual transfer amount after deducting the handling fee" is consistent with the "recharge amount"! Otherwise, it will not be credited!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recharge Amount + Handling Fee = Required Transfer Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For example: recharge 100U, handling fee 1U, required transfer amount is 101U',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // I Have Paid Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isPaymentCompleted ? null : () => _markAsPaid(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaymentCompleted
                        ? Colors.green
                        : const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isPaymentCompleted
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Payment Completed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'I Have Paid',
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
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _markAsPaid() async {
    setState(() {
      isPaymentCompleted = true;
    });

    try {
      // Get payment data
      final paymentData = widget.paymentData;
      final coins = paymentData['coins'] as int? ?? 0;

      // Import auth service
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
        description: 'USDT coin recharge - $coins coins',
        paymentId: paymentData['paymentId'] as String?,
      );

      print(
          '✅ USDT Payment completed! Added $coins coins. New balance: $newBalance');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added $coins coins to your account!'),
          backgroundColor: Colors.green,
        ),
      );

      // Call the completion callback
      widget.onPaymentComplete();
    } catch (e) {
      print('❌ USDT Payment completion failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment processing failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
