import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/app_localizations.dart';

const String _pendingPaymentOrderKey = 'pending_payment_order_id';

class PaymentProcessingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PaymentProcessingScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends ConsumerState<PaymentProcessingScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _isCompleted = false;
  bool _isFailed = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _savePendingOrder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startPolling();
    });
  }

  Future<void> _savePendingOrder() async {
    if (widget.orderId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPaymentOrderKey, widget.orderId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isCompleted && !_isFailed) {
      _checkStatus();
    }
  }

  void _startPolling() {
    final l10n = AppLocalizations.of(context);
    if (widget.orderId.isEmpty) {
      setState(() {
        _isFailed = true;
        _statusText = l10n.paymentMissingOrder;
      });
      return;
    }

    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkStatus(),
    );
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_isCompleted || _isFailed) return;

    try {
      final data = await ApiService().getPaymentStatus(widget.orderId);
      final status = (data['status']?.toString() ?? '').toUpperCase();

      if (status == 'COMPLETED') {
        _timer?.cancel();
        await ref.read(authServiceProvider).refreshCurrentUser();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingPaymentOrderKey);
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isCompleted = true;
          _statusText = l10n.paymentSuccessSyncingTitle;
        });
      } else if (status == 'FAILED' || status == 'CANCELED' || status == 'CANCELLED') {
        _timer?.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingPaymentOrderKey);
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isFailed = true;
          _statusText = l10n.paymentNotCompletedRetry;
        });
      }
    } catch (_) {
      // Keep polling; transient network errors are expected when app switches foreground/background.
    }
  }

  void _goHome() {
    if (_isCompleted) {
      context.go('/main/coin-recharge?paymentSuccess=1');
      return;
    }
    context.go('/main/coin-recharge');
  }

  void _goHistory() {
    context.go('/main/coin-history');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusText = _statusText ?? l10n.paymentCheckingResultTitle;
    final color = _isFailed
        ? const Color(0xFFCC3D3D)
        : (_isCompleted ? const Color(0xFF2E9B5B) : Colors.black87);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isFailed
                          ? Icons.error_outline
                          : (_isCompleted
                              ? Icons.check_circle_outline
                              : Icons.sync_outlined),
                      size: 72,
                      color: _isFailed
                          ? const Color(0xFFCC3D3D)
                          : (_isCompleted
                              ? const Color(0xFF2E9B5B)
                              : const Color(0xFFD5BC79)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.paymentSyncPendingHelp,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8E8E93),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _goHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD5BC79),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          l10n.paymentOpenHome,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _goHistory,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9F8646),
                          side: const BorderSide(color: Color(0xFFBFA45E)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          l10n.paymentViewRechargeRecord,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
