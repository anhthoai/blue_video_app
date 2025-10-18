import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PaymentMethod {
  creditCard,
  usdt,
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
    return showDialog<PaymentMethod>(
      context: context,
      barrierDismissible: true,
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
  PaymentMethod? selectedMethod;

  @override
  Widget build(BuildContext context) {
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
                  Icons.payment,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 18,
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

            const SizedBox(height: 16),

            // Selected Package Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Selected ${widget.coins} coins',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Methods
            _buildPaymentMethod(
              PaymentMethod.creditCard,
              'Credit Card',
              'Pay with Visa, MasterCard, JCB',
              Icons.credit_card,
              Colors.blue,
            ),

            const SizedBox(height: 12),

            _buildPaymentMethod(
              PaymentMethod.usdt,
              'USDT (TRC20)',
              'Pay with USDT cryptocurrency',
              Icons.currency_bitcoin,
              Colors.green,
            ),

            const SizedBox(height: 24),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedMethod != null
                    ? () => widget.onMethodSelected(selectedMethod!)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Pay \$${widget.usdAmount.toStringAsFixed(2)}',
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
  ) {
    final isSelected = selectedMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
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
                      color: isSelected ? color : Colors.black87,
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
                  color: isSelected ? color : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
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
