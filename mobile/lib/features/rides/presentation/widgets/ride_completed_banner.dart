import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Completion banner shown when a ride is finished.
class RideCompletedBanner extends StatelessWidget {
  const RideCompletedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lagoon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.lagoon, size: 32),
          SizedBox(width: 12),
          Text(
            'Ride Completed',
            style: TextStyle(
              color: AppTheme.lagoon,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
