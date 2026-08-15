import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

final rideHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(ridesApiProvider);
  return await api.listRides();
});

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(rideHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: RefreshIndicator(
        onRefresh: () {
          AppHaptics.light();
          return ref.refresh(rideHistoryProvider.future);
        },
        child: ridesAsync.when(
          loading: () => const ShimmerList(withImage: true, count: 6),
          error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(rideHistoryProvider),
          ),
          data: (rides) => rides.isEmpty
              ? const EmptyState(
                  icon: Icons.history_outlined,
                  title: 'No rides yet',
                  subtitle: 'Your ride history will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rides.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ride = rides[index] as Map<String, dynamic>;
                    return FadeSlideIn(
                      delay: Duration(milliseconds: index * 60),
                      child: _RideCard(ride: ride),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? 'Unknown';
    final totalAmount = ride['totalAmount'] ?? 0;
    final rideId = ride['rideId'] as String? ?? ride['id'] as String? ?? '';
    final vehicleType = ride['vehicleType'] as String? ?? 'Bike';
    final distanceKm = ride['distanceKm'] ?? 0;
    final statusColor = _statusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardShadow
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            AppHaptics.light();
            context.push('/rides/$rideId');
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_vehicleIcon(vehicleType), color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ride['pickupAddress'] ?? 'Pickup'} → ${ride['dropoffAddress'] ?? 'Dropoff'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$vehicleType · ${distanceKm}km',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\u20B9$totalAmount',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return AppTheme.warning;
      case 'accepted':
      case 'driverassigned':
        return AppTheme.info;
      case 'ongoing':
      case 'started':
      case 'enroute':
        return AppTheme.lagoon;
      case 'completed':
        return AppTheme.lagoon;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.darkTextSecondary;
    }
  }

  IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.local_taxi;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.directions;
    }
  }
}
