import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Modern success card displayed after a ride is successfully requested.
class RideResultCard extends StatelessWidget {
  const RideResultCard({
    super.key,
    required this.result,
    required this.onTrack,
  });

  final Map<String, dynamic> result;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final surgeMultiplier =
        (result['surgeMultiplier'] as num?)?.toDouble() ?? 1.0;
    final surgeReason = result['surgeReason'] as String?;
    final status = result['status'] as String? ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppTheme.emeraldGradient,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Ride Requested!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FareRow(
              label: 'Fare (100% to driver)',
              value: '\u20B9${result['fare']}',
              color: Colors.white,
            ),
            if (surgeMultiplier > 1.0) ...[
              _FareRow(
                label: 'Surge (${surgeMultiplier}x)',
                value: surgeReason ?? 'High demand',
                small: true,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
            _FareRow(
              label: 'Platform booking fee',
              value: '\u20B9${result['platformBookingFee']}',
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white24, thickness: 1),
            ),
            _FareRow(
              label: 'Total',
              value: '\u20B9${result['totalAmount']}',
              bold: true,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MetricPill(
                  icon: Icons.route,
                  text: '${result['distanceKm']} km',
                ),
                const SizedBox(width: 8),
                _MetricPill(
                  icon: Icons.access_time,
                  text: '${result['estimatedDurationMin']} min',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTrack,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                icon: const Icon(Icons.track_changes),
                label: const Text(
                  'Track Ride',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.small = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final bool small;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 12 : 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: color ?? Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 12 : (bold ? 18 : 14),
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
