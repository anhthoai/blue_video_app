import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:async';
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
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cvcController = TextEditingController();
  final _expiryController = TextEditingController();
  bool isProcessing = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cvcController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentData = widget.paymentData;
    final orderNumber = paymentData['transId']?.toString() ??
        paymentData['trans_id']?.toString() ??
        'N/A';
    final usdAmount = paymentData['amount'] is int
        ? (paymentData['amount'] as int).toDouble()
        : paymentData['amount'] as double;

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
              // Header
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
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Order Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Order Number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          orderNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$usdAmount (USD)',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'about USD',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Credit Card Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Credit Card Number
                    const Text(
                      'Credit Card number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Card logos
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Text(
                                  'VISA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 32,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Text(
                                  'MC',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 32,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Text(
                                  'JCB',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(19),
                        CardNumberInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: '1234 5678 9012 3456',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card number';
                        }
                        if (value.replaceAll(' ', '').length < 16) {
                          return 'Please enter a valid card number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // CVC Code
                    const Text(
                      'Credit Card Code(CVC)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.credit_card,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '888',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cvcController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        hintText: '123',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter CVC code';
                        }
                        if (value.length < 3) {
                          return 'Please enter a valid CVC code';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Expire Date
                    const Text(
                      'Expire Date(MM/YY)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        ExpiryDateInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: 'MM/YY',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter expiry date';
                        }
                        if (value.length < 5) {
                          return 'Please enter a valid expiry date';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Processing...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Pay \$${usdAmount.toStringAsFixed(2)}',
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
      ),
    );
  }

  void _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // Get payment data
      final paymentData = widget.paymentData;
      final transId = paymentData['trans_id']?.toString() ??
          paymentData['transId']?.toString() ??
          '';
      final amount = paymentData['amount']?.toString() ?? '';
      final sign = paymentData['sign']?.toString() ?? '';
      final endpointUrl = paymentData['endpoint_url']?.toString() ??
          paymentData['endpointUrl']?.toString() ??
          '';
      final orderId = paymentData['orderId'] as String? ?? '';

      if (transId.isEmpty ||
          amount.isEmpty ||
          sign.isEmpty ||
          endpointUrl.isEmpty) {
        throw Exception('Missing payment data');
      }

      print('💳 Opening payment gateway...');
      print('   Transaction ID: $transId');
      print('   Amount: $amount');
      print('   Endpoint: $endpointUrl');

      // Open WebView with payment form
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _CreditCardPaymentWebView(
              transId: transId,
              amount: amount,
              sign: sign,
              endpointUrl: endpointUrl,
              orderId: orderId,
              onPaymentComplete: widget.onPaymentComplete,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Credit Card Payment failed: $e');
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
        setState(() {
          isProcessing = false;
        });
      }
    }
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length <= 4) {
      return newValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length <= 2) {
      return newValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CreditCardPaymentWebView extends StatefulWidget {
  final String transId;
  final String amount;
  final String sign;
  final String endpointUrl;
  final String orderId;
  final VoidCallback onPaymentComplete;

  const _CreditCardPaymentWebView({
    required this.transId,
    required this.amount,
    required this.sign,
    required this.endpointUrl,
    required this.orderId,
    required this.onPaymentComplete,
  });

  @override
  State<_CreditCardPaymentWebView> createState() =>
      _CreditCardPaymentWebViewState();
}

class _CreditCardPaymentWebViewState extends State<_CreditCardPaymentWebView> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('📄 Page started loading: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            print('✅ Page finished loading: $url');

            // Check if we're on success/fail page
            if (url.contains('/payment/success')) {
              print('✅ Payment successful! Detected success URL');
            } else if (url.contains('/payment/fail')) {
              print('❌ Payment failed! Detected fail URL');
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
            });

            // Don't close on timeout - let user see the error
            if (error.errorCode == -6) {
              // ERR_CONNECTION_REFUSED
              print('⚠️  Connection refused - gateway might be down');
            } else if (error.errorCode == -7) {
              // ERR_TIMED_OUT
              print('⚠️  Request timed out - gateway is slow');
            }
          },
          onHttpError: (HttpResponseError error) {
            print('❌ HTTP error: ${error.response?.statusCode}');
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    // Create HTML form that auto-submits
    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: #f5f5f5;
          }
          .container {
            text-align: center;
            padding: 20px;
          }
          .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #8B5CF6;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
      </head>
      <body onload="document.getElementById('paymentForm').submit();">
        <div class="container">
          <div class="spinner"></div>
          <p>Redirecting to payment gateway...</p>
          <form id="paymentForm" action="${widget.endpointUrl}" method="post">
            <input type="hidden" name="trans_id" value="${widget.transId}">
            <input type="hidden" name="amount" value="${widget.amount}">
            <input type="hidden" name="sign" value="${widget.sign}">
            <noscript>
              <input type="submit" value="Click here if not redirected automatically">
            </noscript>
          </form>
        </div>
      </body>
      </html>
    ''';

    _controller.loadHtmlString(html);
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        print(
            '🔍 Checking credit card payment status for order: ${widget.orderId}');

        final response = await http.get(
          Uri.parse('${ApiService.baseUrl}/payment/status/${widget.orderId}'),
          headers: await ApiService().getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true &&
              data['data']['status'] == 'COMPLETED') {
            timer.cancel();
            print('✅ Credit Card payment confirmed via IPN!');

            if (mounted) {
              Navigator.of(context).pop();
              widget.onPaymentComplete();
            }
          }
        }
      } catch (e) {
        print('❌ Error checking credit card payment status: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _pollTimer?.cancel();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8B5CF6),
              ),
            ),
        ],
      ),
    );
  }
}
