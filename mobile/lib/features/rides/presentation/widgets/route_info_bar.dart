import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Modern gradient bar showing route distance and duration from OSRM.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppTheme.oceanGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lagoon.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricChip(
            icon: Icons.straighten,
            value: '${distanceKm.toStringAsFixed(1)} km',
            label: 'Distance',
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          _MetricChip(
            icon: Icons.access_time,
            value: '$durationMin min',
            label: 'Duration',
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
