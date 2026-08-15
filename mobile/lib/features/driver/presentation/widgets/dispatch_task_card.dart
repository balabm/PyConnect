import 'package:flutter/material.dart';

import '../../../../core/animations/haptic.dart';
import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/driver_models.dart';

class DispatchTaskCard extends StatelessWidget {
  const DispatchTaskCard({
    required this.task,
    this.onAccept,
    super.key,
  });

  final DispatchTaskModel task;
  final VoidCallback? onAccept;

  static const _taskTypeIcons = {
    'Ride': Icons.motorcycle,
    'FoodDelivery': Icons.delivery_dining,
    'EssentialsDrop': Icons.local_convenience_store,
  };

  static const _taskTypeLabels = {
    'Ride': 'Ride',
    'FoodDelivery': 'Food Delivery',
    'EssentialsDrop': 'Essentials Drop',
  };

  @override
  Widget build(BuildContext context) {
    final icon = _taskTypeIcons[task.taskType] ?? Icons.local_shipping;
    final label = _taskTypeLabels[task.taskType] ?? task.taskType;
    final isAvailable = task.status == 'Available';

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!isAvailable)
                StatusBadge(
                  label: task.status,
                  variant: BadgeVariant.info,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.my_location, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.pickupAddress,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.dropoffAddress,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'YOU EARN: ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.emerald,
                    ),
                  ),
                  TextSpan(
                    text: '\u20B9${task.driverEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.emerald,
                    ),
                  ),
                  const TextSpan(
                    text: ' (100% of fare)',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.emerald,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isAvailable && onAccept != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  AppHaptics.medium();
                  onAccept!();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  'Accept Task',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
