import 'package:flutter/material.dart';

enum PaymentMethod {
  usdt,
  creditCard,
}

class PaymentMethodDialog extends StatefulWidget {
  final int coins;
  final double usdAmount;
  final Function(PaymentMethod) onMethodSelected;

  const PaymentMethodDialog({
    super.key,
    required this.coins,
    required this.usdAmount,
    required this.onMethodSelected,
  });

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();

  static Future<PaymentMethod?> show(
    BuildContext context, {
    required int coins,
    required double usdAmount,
  }) {
    return showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentMethodDialog(
        coins: coins,
        usdAmount: usdAmount,
        onMethodSelected: (method) {
          Navigator.of(context).pop(method);
        },
      ),
    );
  }
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  PaymentMethod? selectedMethod = PaymentMethod.usdt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose Payment Method',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selected ${widget.coins} coins',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildPaymentMethod(
              PaymentMethod.usdt,
              'USDT (TRC20)',
              'Pay in external browser (OxaPay)',
              Icons.currency_bitcoin,
              Colors.green,
            ),
            const SizedBox(height: 10),
            _buildPaymentMethod(
              PaymentMethod.creditCard,
              'Credit Card',
              'Coming soon',
              Icons.credit_card,
              Colors.grey,
              enabled: false,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedMethod == PaymentMethod.usdt
                    ? () => widget.onMethodSelected(PaymentMethod.usdt)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Continue - \$${widget.usdAmount.toStringAsFixed(2)}',
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
    );
  }

  Widget _buildPaymentMethod(
    PaymentMethod method,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    {bool enabled = true}
  ) {
    final isSelected = selectedMethod == method;

    return GestureDetector(
      onTap: enabled
          ? () {
              setState(() {
                selectedMethod = method;
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled
                ? (isSelected ? color : Colors.grey[300]!)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: enabled
              ? (isSelected ? color.withOpacity(0.1) : Colors.white)
              : Colors.grey[100],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: enabled ? color.withOpacity(0.1) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: enabled ? color : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? (isSelected ? color : Colors.black87)
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled
                      ? (isSelected ? color : Colors.grey[400]!)
                      : Colors.grey[400]!,
                  width: 2,
                ),
                color: enabled && isSelected ? color : Colors.transparent,
              ),
              child: enabled && isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
