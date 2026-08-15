import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';
import '../domain/driver_models.dart';
import 'driver_ride_screen.dart';

/// The Active Trip tab for the Captain app.
///
/// For ride tasks, it reuses the existing `DriverRideScreen` state machine.
/// For food/essentials, it shows a full delivery lifecycle state machine.
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

class _TaskView extends ConsumerWidget {
  const _TaskView({required this.task});

  final DispatchTaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (task.taskType) {
      'Ride' => DriverRideScreen(rideId: task.id, driverId: task.driverId ?? ''),
      'FoodDelivery' || 'EssentialsDrop' => DeliveryLifecycleScreen(task: task),
      _ => DeliveryLifecycleScreen(task: task),
    };
  }
}

/// Full delivery state machine for Food Delivery and Essentials Drop tasks.
///
/// Phases:
/// 1. Heading to Store → [Arrived at Store]
/// 2. At Store → [Confirm Order Picked Up]
/// 3. En Route to Customer → [Arrived at Delivery Location]
/// 4. Delivered → [Complete Delivery & Collect Cash/UPI]
class DeliveryLifecycleScreen extends ConsumerStatefulWidget {
  const DeliveryLifecycleScreen({super.key, required this.task});

  final DispatchTaskModel task;

  @override
  ConsumerState<DeliveryLifecycleScreen> createState() =>
      _DeliveryLifecycleScreenState();
}

class _DeliveryLifecycleScreenState
    extends ConsumerState<DeliveryLifecycleScreen> {
  _DeliveryPhase _phase = _DeliveryPhase.headingToStore;
  bool _completing = false;

  String get _storeLabel =>
      widget.task.taskType == 'EssentialsDrop' ? 'Store' : 'Restaurant';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_phaseTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel trip',
            onPressed: () => _cancelTrip(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _PhaseProgressIndicator(phase: _phase),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildPhaseContent(context),
                  const SizedBox(height: 24),
                  _buildActionButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _phaseTitle => switch (_phase) {
        _DeliveryPhase.headingToStore => 'Heading to $_storeLabel',
        _DeliveryPhase.atStore => 'At $_storeLabel',
        _DeliveryPhase.enRouteToCustomer => 'En route to customer',
        _DeliveryPhase.delivered => 'Delivery complete',
      };

  List<Widget> _buildPhaseContent(BuildContext context) {
    return switch (_phase) {
      _DeliveryPhase.headingToStore => [
          _InfoCard(
            icon: Icons.storefront,
            title: widget.task.pickupAddress,
            subtitle: '$_storeLabel pickup location',
            iconColor: AppTheme.emerald,
          ),
          const SizedBox(height: 16),
          _OrderSummaryCard(task: widget.task),
          const SizedBox(height: 16),
          _NavigationButton(
            label: 'Navigate to $_storeLabel',
            address: widget.task.pickupAddress,
          ),
        ],
      _DeliveryPhase.atStore => [
          _InfoCard(
            icon: Icons.storefront,
            title: widget.task.pickupAddress,
            subtitle: 'You are at the $_storeLabel',
            iconColor: AppTheme.emerald,
          ),
          const SizedBox(height: 16),
          _OrderSummaryCard(task: widget.task, showChecklist: true),
          const SizedBox(height: 16),
          Text(
            'Verify all items are packed before confirming pickup.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      _DeliveryPhase.enRouteToCustomer => [
          _InfoCard(
            icon: Icons.home_outlined,
            title: widget.task.dropoffAddress,
            subtitle: 'Customer delivery address',
            iconColor: AppTheme.info,
          ),
          const SizedBox(height: 16),
          _CustomerContactCard(task: widget.task),
          const SizedBox(height: 16),
          _NavigationButton(
            label: 'Navigate to customer',
            address: widget.task.dropoffAddress,
          ),
        ],
      _DeliveryPhase.delivered => [
          _DeliveryCompleteCard(task: widget.task),
        ],
    };
  }

  Widget _buildActionButton(BuildContext context) {
    if (_phase == _DeliveryPhase.delivered) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _completing
              ? null
              : () => _completeDelivery(context),
          icon: _completing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle),
          label: const Text('Complete Delivery & Collect Cash/UPI'),
        ),
      );
    }

    final label = switch (_phase) {
      _DeliveryPhase.headingToStore => 'Arrived at $_storeLabel',
      _DeliveryPhase.atStore => 'Confirm Order Picked Up',
      _DeliveryPhase.enRouteToCustomer => 'Arrived at Delivery Location',
      _DeliveryPhase.delivered => '',
    };

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _advancePhase(context),
        icon: const Icon(Icons.arrow_forward),
        label: Text(label),
      ),
    );
  }

  void _advancePhase(BuildContext context) {
    AppHaptics.medium();
    setState(() {
      _phase = switch (_phase) {
        _DeliveryPhase.headingToStore => _DeliveryPhase.atStore,
        _DeliveryPhase.atStore => _DeliveryPhase.enRouteToCustomer,
        _DeliveryPhase.enRouteToCustomer => _DeliveryPhase.delivered,
        _DeliveryPhase.delivered => _DeliveryPhase.delivered,
      };
    });
  }

  Future<void> _completeDelivery(BuildContext context) async {
    AppHaptics.medium();
    setState(() => _completing = true);
    try {
      await ref.read(driverApiProvider).completeTask(widget.task.id);
      if (mounted) {
        ref.read(activeTaskProvider.notifier).state = null;
        ref.read(driverSelectedTabProvider.notifier).state = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delivery completed. Earnings: \u20B9${widget.task.driverEarnings.toStringAsFixed(0)}',
            ),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _cancelTrip(BuildContext context) {
    AppHaptics.light();
    ref.read(activeTaskProvider.notifier).state = null;
    ref.read(driverSelectedTabProvider.notifier).state = 0;
  }
}

enum _DeliveryPhase {
  headingToStore,
  atStore,
  enRouteToCustomer,
  delivered,
}

/// Horizontal progress indicator showing the 4 delivery phases.
class _PhaseProgressIndicator extends StatelessWidget {
  const _PhaseProgressIndicator({required this.phase});

  final _DeliveryPhase phase;

  @override
  Widget build(BuildContext context) {
    final phases = [
      ('Store', Icons.storefront),
      ('Pickup', Icons.shopping_bag_outlined),
      ('En route', Icons.two_wheeler),
      ('Delivered', Icons.check_circle),
    ];

    final currentIndex = phase.index;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: List.generate(phases.length * 2 - 1, (i) {
          if (i.isOdd) {
            final completed = i ~/ 2 < currentIndex;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: completed ? AppTheme.emerald : Theme.of(context).dividerColor,
              ),
            );
          }
          final idx = i ~/ 2;
          final (label, icon) = phases[idx];
          final isCurrent = idx == currentIndex;
          final isDone = idx < currentIndex;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrent || isDone
                      ? AppTheme.emerald
                      : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: isCurrent || isDone
                        ? AppTheme.emerald
                        : Theme.of(context).dividerColor,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isCurrent || isDone ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? AppTheme.emerald
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.task, this.showChecklist = false});

  final DispatchTaskModel task;
  final bool showChecklist;

  @override
  Widget build(BuildContext context) {
    // Parse items from the task if available, otherwise show a generic summary
    final earnings = task.driverEarnings;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 20, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text(
                'Order Summary',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (showChecklist) ...[
            if (task.orderItems != null && task.orderItems!.isNotEmpty) ...[
              // Real itemized checklist from backend order data
              if (task.orderId != null)
                _DetailRow(label: 'Order ID', value: task.orderId!),
              const SizedBox(height: 8),
              ...task.orderItems!.map((item) => _ChecklistItem(
                    label: '${item.quantity}x ${item.name}',
                    note: item.specialInstructions,
                  )),
              const SizedBox(height: 8),
              _ChecklistItem(label: 'Payment confirmation checked'),
              _ChecklistItem(label: 'Packaging intact'),
            ] else ...[
              // Generic checklist fallback
              _ChecklistItem(label: '1x Order items verified'),
              _ChecklistItem(label: '1x Payment confirmation checked'),
              _ChecklistItem(label: '1x Packaging intact'),
            ],
          ] else ...[
            _DetailRow(label: 'Task type', value: task.taskType),
            _DetailRow(label: 'Pickup', value: task.pickupAddress),
            _DetailRow(label: 'Dropoff', value: task.dropoffAddress),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your earnings',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '\u20B9${earnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label, this.note});

  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_box_outline_blank, size: 20, color: AppTheme.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                if (note != null && note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Note: $note',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _CustomerContactCard extends StatelessWidget {
  const _CustomerContactCard({required this.task});

  final DispatchTaskModel task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Contact',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.emerald.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppTheme.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Customer',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: AppTheme.emerald),
                tooltip: 'Call customer',
                onPressed: () {
                  AppHaptics.light();
                  // In production: launch tel: URI
                },
              ),
              IconButton(
                icon: const Icon(Icons.message, color: AppTheme.emerald),
                tooltip: 'SMS customer',
                onPressed: () {
                  AppHaptics.light();
                  // In production: launch sms: URI
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({required this.label, required this.address});

  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          AppHaptics.light();
          // In production: open maps app with address
        },
        icon: const Icon(Icons.navigation),
        label: Text(label),
      ),
    );
  }
}

class _DeliveryCompleteCard extends StatelessWidget {
  const _DeliveryCompleteCard({required this.task});

  final DispatchTaskModel task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 64, color: AppTheme.emerald),
          const SizedBox(height: 16),
          const Text(
            'Order Delivered',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Collect cash or UPI payment from the customer.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _DetailRow(label: 'Dropoff', value: task.dropoffAddress),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Earnings',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '\u20B9${task.driverEarnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
