import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';

/// Progress tracker showing ride lifecycle stages.
class RideStatusCard extends StatelessWidget {
  const RideStatusCard({super.key, required this.status});

  final String status;

  static const _stages = [
    'Requested',
    'Searching',
    'DriverAssigned',
    'ArrivedAtPickup',
    'EnRoute',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        _stages.indexWhere((s) => s.toLowerCase() == status.toLowerCase());
    final isCancelled =
        status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'drivercancelled';

    if (isCancelled) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.cancel, color: AppTheme.coral),
            const SizedBox(width: 12),
            Text(
              'Ride Cancelled',
              style: TextStyle(
                color: AppTheme.coral,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (currentIndex < 0) {
      return AppCard(child: Text('Status: $status'));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ride Status', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                final reached = i ~/ 2 < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: reached ? AppTheme.emerald : Theme.of(context).dividerColor,
                  ),
                );
              }
              final stageIndex = i ~/ 2;
              final reached = stageIndex <= currentIndex;
              return Icon(
                reached ? Icons.check_circle : Icons.radio_button_unchecked,
                color: reached ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              );
            }),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _stages.map((s) {
                final reached = _stages.indexOf(s) <= currentIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    s.replaceAllMapped(
                      RegExp(r'[A-Z]'),
                      (m) => ' ${m.group(0)}',
                    ).trim(),
                    style: TextStyle(
                      fontSize: 10,
                      color: reached ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: reached ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
