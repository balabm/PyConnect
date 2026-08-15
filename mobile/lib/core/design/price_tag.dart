import 'package:flutter/material.dart';

/// Formatted ₹ price tag with optional strikethrough for original price.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.amount,
    this.originalAmount,
    this.size = 16,
    this.bold = true,
  });

  final double amount;
  final double? originalAmount;
  final double size;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (originalAmount != null) ...[
          Text(
            '\u20B9${originalAmount!.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: size - 2,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          '\u20B9${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: size,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
