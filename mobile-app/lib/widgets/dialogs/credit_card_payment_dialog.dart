import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/api_service.dart';

class CreditCardPaymentDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> paymentData;
  final VoidCallback onPaymentComplete;
  final VoidCallback onCancel;

  const CreditCardPaymentDialog({
    super.key,
    required this.paymentData,
    required this.onPaymentComplete,
    required this.onCancel,
  });

  @override
  ConsumerState<CreditCardPaymentDialog> createState() =>
      _CreditCardPaymentDialogState();

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> paymentData,
    required VoidCallback onPaymentComplete,
    required VoidCallback onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreditCardPaymentDialog(
        paymentData: paymentData,
        onPaymentComplete: onPaymentComplete,
        onCancel: onCancel,
      ),
    );
  }
}

class _CreditCardPaymentDialogState
    extends ConsumerState<CreditCardPaymentDialog> {
  late final WebViewController _webViewController;
  Timer? _pollTimer;
  bool _isLoadingGateway = true;
  bool _hasStartedPolling = false;

  late final String _orderId;
  late final String _endpointUrl;
  late final String _transId;
  late final String _amountParam;
  late final String _sign;
  late final double _usdAmount;

  @override
  void initState() {
    super.initState();
    final paymentData = widget.paymentData;

    _orderId = paymentData['orderId']?.toString() ??
        paymentData['extOrderId']?.toString() ??
        '';
    _endpointUrl = paymentData['endpointUrl'] as String? ??
        paymentData['endpoint_url'] as String? ??
        '';
    _transId = paymentData['transId']?.toString() ??
        paymentData['trans_id']?.toString() ??
        '';
    _amountParam = paymentData['amount']?.toString() ??
        paymentData['usdAmount']?.toString() ??
        '0';
    _sign = paymentData['sign']?.toString() ?? '';
    _usdAmount = _parseUsdAmount(paymentData);

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoadingGateway = true;
            });
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoadingGateway = false;
              });
            }
            _handleNavigation(url);
          },
          onNavigationRequest: (request) {
            if (_handleNavigation(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to load payment page: ${error.description}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      )
      ..loadHtmlString(_buildAutoSubmitForm());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_orderId.isEmpty ||
          _endpointUrl.isEmpty ||
          _transId.isEmpty ||
          _sign.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Missing payment information. Please try again later.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        widget.onCancel();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Redirecting to secure payment gateway...'),
          duration: Duration(seconds: 3),
        ),
      );

      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentData = widget.paymentData;
    final orderNumber = paymentData['transId']?.toString() ??
        paymentData['trans_id']?.toString() ??
        'N/A';
    final displayAmount = _usdAmount > 0
        ? '\$${_usdAmount.toStringAsFixed(2)}'
        : (_amountParam.isNotEmpty ? _amountParam : '—');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.credit_card,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Credit Card Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _handleCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Order Number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          orderNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$displayAmount USD',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 420,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _webViewController),
                      if (_isLoadingGateway)
                        Container(
                          color: Colors.white.withOpacity(0.85),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Connecting to payment gateway...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Complete your card details in the secure payment page above. '
                'Do not close this window until you return to Blue Video.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                  ),
                  child: const Text(
                    'Cancel Payment',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  double _parseUsdAmount(Map<String, dynamic> paymentData) {
    final amountValue = paymentData['usdAmount'] ?? paymentData['amount'];
    if (amountValue is num) {
      return amountValue.toDouble();
    }
    if (amountValue is String) {
      return double.tryParse(amountValue) ?? 0.0;
    }
    return 0.0;
  }

  String _buildAutoSubmitForm() {
    final sanitizedEndpoint = _endpointUrl;
    final sanitizedAmount = _amountParam;
    final sanitizedTransId = _transId;
    final sanitizedSign = _sign;

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Redirecting…</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background-color: #f9fafb;
      color: #0f172a;
      margin: 0;
      padding: 24px;
      text-align: center;
    }
    .card {
      display: inline-block;
      background: #ffffff;
      padding: 24px;
      border-radius: 16px;
      box-shadow: 0 12px 40px rgba(15, 23, 42, 0.12);
      max-width: 420px;
      width: 100%;
    }
    h2 {
      margin-top: 0;
      font-size: 20px;
    }
    p {
      color: #475569;
      font-size: 14px;
      line-height: 1.6;
    }
    button {
      margin-top: 20px;
      padding: 12px 20px;
      background: #6c5ce7;
      color: #ffffff;
      border: none;
      border-radius: 12px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
    }
    button:focus {
      outline: none;
      box-shadow: 0 0 0 3px rgba(108, 92, 231, 0.35);
    }
    .hint {
      margin-top: 18px;
      font-size: 13px;
      color: #64748b;
    }
  </style>
  <script>
    function submitForm() {
      document.forms[0].submit();
    }
    window.addEventListener('load', function() {
      setTimeout(submitForm, 600);
    });
  </script>
</head>
<body>
  <div class="card">
    <h2>Connecting to secure payment...</h2>
    <p>Please wait a moment. If the payment page does not open automatically, tap the button below.</p>
    <form action="$sanitizedEndpoint" method="post">
      <input type="hidden" name="trans_id" value="$sanitizedTransId" />
      <input type="hidden" name="amount" value="$sanitizedAmount" />
      <input type="hidden" name="sign" value="$sanitizedSign" />
      <button type="submit">Continue to payment</button>
    </form>
    <p class="hint">Keep this window open until you return to the app.</p>
  </div>
</body>
</html>
''';
  }

  bool _handleNavigation(String url) {
    try {
      final apiUri = Uri.parse(ApiService.baseUrl);
      final origin = '${apiUri.scheme}://${apiUri.authority}';
      final successUrl = '$origin/payment/success';
      final failureUrl = '$origin/payment/fail';

      if (url.startsWith(successUrl)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment submitted. Waiting for confirmation...'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      if (url.startsWith(failureUrl)) {
        _handlePaymentFailure('Payment was cancelled or failed.');
        return true;
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return false;
  }

  Future<void> _startPolling() async {
    if (_hasStartedPolling || _orderId.isEmpty) {
      return;
    }
    _hasStartedPolling = true;

    int attempt = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      attempt++;
      try {
        final response = await http.get(
          Uri.parse('${ApiService.baseUrl}/payment/status/$_orderId'),
          headers: await ApiService().getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final status = (data['data']['status'] as String?) ?? '';
            if (status == 'COMPLETED') {
              timer.cancel();
              _handlePaymentSuccess();
              return;
            } else if (status == 'FAILED' || status == 'CANCELLED') {
              timer.cancel();
              _handlePaymentFailure(
                  'Payment failed. Please try again with another method.');
              return;
            }
          }
        }
      } catch (e) {
        print('❌ Error checking credit card payment status: $e');
      }

      if (attempt >= 24) {
        timer.cancel();
        _handlePaymentFailure(
            'Payment confirmation is taking longer than expected. Please verify the transaction status later.');
      }
    });
  }

  void _handlePaymentSuccess() {
    _pollTimer?.cancel();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment confirmed! Thank you.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    widget.onPaymentComplete();
  }

  void _handlePaymentFailure(String message) {
    _pollTimer?.cancel();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );

    widget.onCancel();
  }

  void _handleCancel() {
    _pollTimer?.cancel();
    widget.onCancel();
  }
}
