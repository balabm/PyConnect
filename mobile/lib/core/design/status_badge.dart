import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Colored pill badge for status indicators.
///
/// Variants map to common states: open/closed, active/inactive, etc.
enum BadgeVariant {
  success(Color(0xFF2A9D8F), Color(0xFFE0F5F2)),
  warning(Color(0xFFE9C46A), Color(0xFFFEF6E0)),
  danger(Color(0xFFE76F51), Color(0xFFFDEDE9)),
  info(Color(0xFF4895EF), Color(0xFFE8F2FE)),
  neutral(Color(0xFF6C757D), Color(0xFFF0F0F1));

  const BadgeVariant(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.icon,
  });

  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: variant.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: variant.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: variant.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
