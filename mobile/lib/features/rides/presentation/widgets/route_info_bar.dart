import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Clean, structured route info — no colored banner.
/// Integrates seamlessly into the bottom sheet like Uber.
class RouteInfoBar extends StatelessWidget {
  const RouteInfoBar({
    super.key,
    required this.distanceKm,
    required this.durationMin,
  });

  final double distanceKm;
  final int durationMin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          Icons.route,
          size: 16,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
        ),
        const SizedBox(width: 6),
        Text(
          '${distanceKm.toStringAsFixed(1)} km',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.access_time,
          size: 16,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
        ),
        const SizedBox(width: 6),
        Text(
          '$durationMin min',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}
