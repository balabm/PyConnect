import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/admin_providers.dart';

class OrdersPane extends ConsumerWidget {
  const OrdersPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(adminActiveRidesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.receipt_long, size: 18),
              const SizedBox(width: 8),
              Text('Active Rides', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Expanded(
          child: ridesAsync.when(
            loading: () => const ShimmerList(withImage: false, count: 5),
            error: (_, _) => const ErrorState(message: 'Error loading rides'),
            data: (rides) {
              if (rides.isEmpty) {
                return const Center(child: Text('No active rides', style: TextStyle(color: AdminColors.textMuted)));
              }
              return ListView.builder(
                itemCount: rides.length,
                itemBuilder: (context, i) {
                  final ride = rides[i];
                  final variant = ride.status == 'EnRoute'
                      ? BadgeVariant.success
                      : ride.status == 'DriverAssigned' || ride.status == 'Accepted'
                          ? BadgeVariant.warning
                          : BadgeVariant.info;
                  final color = variant.foreground;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Text('₹${ride.estimatedFare.round()}', style: TextStyle(fontSize: 10, color: color)),
                    ),
                    title: Text('${ride.riderName} — ${ride.vehicleType}', style: const TextStyle(fontSize: 13)),
                    subtitle: Text(ride.driverName != null ? 'Driver: ${ride.driverName}' : 'Searching...'),
                    trailing: StatusBadge(
                      label: ride.status,
                      variant: variant,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
