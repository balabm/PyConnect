import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          _showScheduleSheet(context);
        },
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
                  _showScheduleSheet(context);
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
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final api = ref.read(ridesApiProvider);
                          await api.cancelScheduledRide(id);
                          ref.invalidate(scheduledRidesProvider);
                          if (context.mounted) {
                            AppHaptics.success();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Scheduled ride cancelled')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppHaptics.error();
                            messenger.showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
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

  void _showScheduleSheet(BuildContext context) {
    final pickupCtrl = TextEditingController();
    final dropoffCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime scheduledAt = DateTime.now().add(const Duration(hours: 2));
    int vehicleType = 1; // Bike=1, Auto=2, Car=3
    int paymentMethod = 1; // Cash=1, UPI=2, Card=3
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Schedule a Ride', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Book a ride in advance. We\'ll dispatch a captain at your scheduled time.',
                  style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: pickupCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pickup address',
                    prefixIcon: Icon(Icons.my_location, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Pickup address is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dropoffCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dropoff address',
                    prefixIcon: Icon(Icons.location_on, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Dropoff address is required' : null,
                ),
                const SizedBox(height: 16),
                // Date & time picker
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: scheduledAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (pickedDate != null && ctx.mounted) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(scheduledAt),
                      );
                      if (pickedTime != null) {
                        final newScheduledAt = DateTime(
                          pickedDate.year, pickedDate.month, pickedDate.day,
                          pickedTime.hour, pickedTime.minute,
                        );
                        // Prevent scheduling in the past (today but time already passed)
                        if (newScheduledAt.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a time at least 30 minutes from now'),
                              backgroundColor: AppTheme.warning,
                            ),
                          );
                          return;
                        }
                        setSheetState(() {
                          scheduledAt = newScheduledAt;
                        });
                      }
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Schedule date & time',
                      prefixIcon: Icon(Icons.schedule, size: 20),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatScheduleTime(scheduledAt.toIso8601String())),
                  ),
                ),
                const SizedBox(height: 16),
                // Vehicle type selector
                const Text('Vehicle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _VehicleChip(label: 'Bike', icon: Icons.two_wheeler, selected: vehicleType == 1, onSelected: () => setSheetState(() => vehicleType = 1)),
                    _VehicleChip(label: 'Auto', icon: Icons.local_taxi, selected: vehicleType == 2, onSelected: () => setSheetState(() => vehicleType = 2)),
                    _VehicleChip(label: 'Car', icon: Icons.directions_car, selected: vehicleType == 3, onSelected: () => setSheetState(() => vehicleType = 3)),
                  ],
                ),
                const SizedBox(height: 16),
                // Payment method selector
                const Text('Payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _VehicleChip(label: 'Cash', icon: Icons.payments_outlined, selected: paymentMethod == 1, onSelected: () => setSheetState(() => paymentMethod = 1)),
                    _VehicleChip(label: 'UPI', icon: Icons.account_balance_wallet_outlined, selected: paymentMethod == 2, onSelected: () => setSheetState(() => paymentMethod = 2)),
                    _VehicleChip(label: 'Card', icon: Icons.credit_card, selected: paymentMethod == 3, onSelected: () => setSheetState(() => paymentMethod = 3)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => submitting = true);
                            AppHaptics.light();
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            try {
                              await ref.read(ridesApiProvider).scheduleRide({
                                'pickupAddress': pickupCtrl.text.trim(),
                                'dropoffAddress': dropoffCtrl.text.trim(),
                                'vehicleType': vehicleType,
                                'paymentMethod': paymentMethod,
                                'scheduledAt': scheduledAt.toUtc().toIso8601String(),
                              });
                              ref.invalidate(scheduledRidesProvider);
                              if (mounted) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Ride scheduled successfully!'),
                                    backgroundColor: AppTheme.emerald,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed to schedule: $e'), backgroundColor: AppTheme.danger),
                                );
                                setSheetState(() => submitting = false);
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.emerald,
                    ),
                    child: submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Schedule Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({required this.label, required this.icon, required this.selected, required this.onSelected});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.emerald,
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
                  Icon(Icons.schedule, color: AppTheme.emerald, size: 20),
                  const SizedBox(width: 8),
                  Text(_formatScheduleTime(scheduledAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(vehicleType, style: TextStyle(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.w600)),
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
