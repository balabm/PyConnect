import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';

/// OTP prompt card shown when a driver is assigned or has arrived.
class OtpCard extends StatelessWidget {
  const OtpCard({super.key, required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? '';
    final arrived = status.toLowerCase() == 'arrivedatpickup';

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.password, color: AppTheme.sky, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arrived
                          ? 'Share your OTP with the driver'
                          : 'Your OTP is ready',
                      style: TextStyle(
                        color: AppTheme.sky,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Show this code to your driver to start the ride',
                      style: TextStyle(color: AppTheme.sky.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.sky.withValues(alpha: 0.4), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: AppTheme.sky, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Check your SMS / app notification',
                  style: TextStyle(
                    color: AppTheme.sky,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
