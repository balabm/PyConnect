import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A labelled value row used in fare breakdowns and receipt-style layouts.
class FareRow extends StatelessWidget {
  const FareRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.small = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final bool small;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 12.0 : (bold ? 16.0 : 14.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (small ? AppTheme.coral : null),
            ),
          ),
        ],
      ),
    );
  }
}
