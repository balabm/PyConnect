import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';
import '../domain/driver_models.dart';
import 'driver_ride_screen.dart';

/// The Active Trip tab for the Captain app.
///
/// For ride tasks, it reuses the existing `DriverRideScreen` state machine.
/// For food/essentials, it currently shows an informational placeholder.
class ActiveTripScreen extends ConsumerWidget {
  const ActiveTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(activeTaskProvider);

    if (task == null) {
      return const Scaffold(
        body: Center(
          child: EmptyState(
            icon: Icons.two_wheeler_outlined,
            title: 'No active trip',
            subtitle: 'Accept a task from the Tasks tab to start a trip.',
          ),
        ),
      );
    }

    return _TaskView(task: task);
  }
}

class _TaskView extends StatelessWidget {
  const _TaskView({required this.task});

  final DispatchTaskModel task;

  @override
  Widget build(BuildContext context) {
    return switch (task.taskType) {
      'Ride' => DriverRideScreen(rideId: task.id, driverId: task.driverId ?? ''),
      _ => _NonRidePlaceholder(task: task),
    };
  }
}

class _NonRidePlaceholder extends StatelessWidget {
  const _NonRidePlaceholder({required this.task});

  final DispatchTaskModel task;

  @override
  Widget build(BuildContext context) {
    final icon = switch (task.taskType) {
      'FoodDelivery' => Icons.delivery_dining_outlined,
      'EssentialsDrop' => Icons.local_convenience_store_outlined,
      _ => Icons.local_shipping_outlined,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Active Trip')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppTheme.emerald),
              const SizedBox(height: 20),
              Text(
                '${task.taskType} trip accepted',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${task.pickupAddress} → ${task.dropoffAddress}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'Full lifecycle screen for ${task.taskType} is coming soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
