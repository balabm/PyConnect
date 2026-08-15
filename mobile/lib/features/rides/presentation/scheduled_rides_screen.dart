import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

final scheduledRidesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(ridesApiProvider);
  return await api.listScheduledRides();
});

class ScheduledRidesScreen extends ConsumerStatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  ConsumerState<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends ConsumerState<ScheduledRidesScreen> {
  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(scheduledRidesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Rides')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AppHaptics.light();
          context.push('/rides/schedule');
        },
        backgroundColor: AppTheme.lagoon,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: ridesAsync.when(
        loading: () => const ShimmerList(withImage: false, count: 4),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(scheduledRidesProvider),
        ),
        data: (rides) => rides.isEmpty
            ? EmptyState(
                icon: Icons.event_busy,
                title: 'No scheduled rides',
                subtitle: 'Book a ride in advance for later',
                actionLabel: 'Schedule a Ride',
                onAction: () {
                  AppHaptics.light();
                  context.push('/rides/schedule');
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rides.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ride = rides[index] as Map<String, dynamic>;
                  return FadeSlideIn(
                    delay: Duration(milliseconds: index * 60),
                    child: _ScheduledRideCard(
                      ride: ride,
                      onCancel: () async {
                        final id = ride['id'] as String?;
                        if (id == null) return;
                        AppHaptics.heavy();
                        try {
                          final api = ref.read(ridesApiProvider);
                          await api.cancelScheduledRide(id);
                          ref.invalidate(scheduledRidesProvider);
                          if (context.mounted) {
                            AppHaptics.success();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Scheduled ride cancelled')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppHaptics.error();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
                          }
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ScheduledRideCard extends StatelessWidget {
  const _ScheduledRideCard({required this.ride, required this.onCancel});
  final Map<String, dynamic> ride;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final pickupAddress = ride['pickupAddress'] as String? ?? '';
    final dropoffAddress = ride['dropoffAddress'] as String? ?? '';
    final vehicleType = ride['vehicleType'] as String? ?? 'Bike';
    final estimatedFare = ride['estimatedFare'] ?? 0;
    final scheduledAt = ride['scheduledAt'] as String? ?? '';
    final distanceKm = ride['distanceKm'] ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: AppTheme.lagoon, size: 20),
                  const SizedBox(width: 8),
                  Text(_formatScheduleTime(scheduledAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.coral.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(vehicleType, style: TextStyle(color: AppTheme.coral, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.my_location, color: AppTheme.info, size: 16), const SizedBox(width: 6), Expanded(child: Text(pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.location_on, color: AppTheme.danger, size: 16), const SizedBox(width: 6), Expanded(child: Text(dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$distanceKm km', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              Text('\u20B9$estimatedFare (est.)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Cancel Scheduled Ride'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatScheduleTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final schedDate = DateTime(dt.year, dt.month, dt.day);
      final diff = schedDate.difference(today).inDays;

      final timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return 'Today at $timeStr';
      if (diff == 1) return 'Tomorrow at $timeStr';
      return '${dt.day}/${dt.month}/${dt.year} at $timeStr';
    } catch (_) {
      return iso;
    }
  }
}
