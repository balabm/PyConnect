import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/network/offline_mutation_queue.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';
import '../domain/driver_models.dart';
import 'driver_ride_screen.dart';
import 'post_trip_summary_sheet.dart';

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
      'FoodDelivery' || 'EssentialsDrop' => task.batchGroupId != null
          ? BatchedDeliveryScreen(task: task)
          : DeliveryLifecycleScreen(task: task),
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
  bool _advancing = false;

  String get _storeLabel =>
      widget.task.taskType == 'EssentialsDrop' ? 'Store' : 'Restaurant';

  @override
  void initState() {
    super.initState();
    // Restore the phase from the backend status so the delivery can be
    // resumed after an app kill/restart.
    _phase = _phaseFromStatus(widget.task.status);
  }

  /// Maps the backend DispatchTaskStatus string to the local UI phase.
  _DeliveryPhase _phaseFromStatus(String status) {
    return switch (status) {
      'ArrivedAtStore' => _DeliveryPhase.atStore,
      'OutForDelivery' => _DeliveryPhase.enRouteToCustomer,
      'Completed' => _DeliveryPhase.delivered,
      _ => _DeliveryPhase.headingToStore,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_phaseTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            tooltip: 'Emergency Issue / Cannot Complete',
            onPressed: () => _showEmergencyReleaseDialog(context),
          ),
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
        onPressed: _advancing ? null : () => _advancePhase(context),
        icon: _advancing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward),
        label: Text(label),
      ),
    );
  }

  Future<void> _advancePhase(BuildContext context) async {
    AppHaptics.medium();
    if (_advancing) return;

    // When confirming pickup at the store, require an explicit Yes/No
    // confirmation that all items have been picked up.
    if (_phase == _DeliveryPhase.atStore) {
      final confirmed = await _showPickupConfirmationDialog(context);
      if (!confirmed || !mounted) return;
    }

    setState(() => _advancing = true);

    final nextPhase = switch (_phase) {
      _DeliveryPhase.headingToStore => _DeliveryPhase.atStore,
      _DeliveryPhase.atStore => _DeliveryPhase.enRouteToCustomer,
      _DeliveryPhase.enRouteToCustomer => _DeliveryPhase.delivered,
      _DeliveryPhase.delivered => _DeliveryPhase.delivered,
    };

    // Persist the phase transition to the backend so it can be resumed.
    try {
      if (nextPhase == _DeliveryPhase.atStore) {
        await ref.read(driverApiProvider).markArrivedAtStore(widget.task.id);
      } else if (nextPhase == _DeliveryPhase.enRouteToCustomer) {
        await ref.read(driverApiProvider).markOutForDelivery(widget.task.id);
      }
    } catch (e) {
      // Network error: queue the mutation for replay when connectivity
      // is restored. Update the UI optimistically so the driver is not blocked.
      if (e is Exception && _isNetworkError(e)) {
        final path = nextPhase == _DeliveryPhase.atStore
            ? 'api/driver/tasks/${widget.task.id}/arrived-at-store'
            : 'api/driver/tasks/${widget.task.id}/out-for-delivery';
        try {
          await ref.read(offlineMutationQueueProvider).enqueue(
                QueuedMutation(
                  id: '${widget.task.id}_${nextPhase.name}',
                  method: 'POST',
                  path: path,
                  createdAt: DateTime.now(),
                ),
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Offline — saved. Will sync when back online.'),
                backgroundColor: AppTheme.warning,
              ),
            );
          }
        } catch (_) {
          // Queue enqueue failed — fall through to the generic error message.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Phase update failed: $e. Continuing anyway.')),
            );
          }
        }
      } else {
        // Non-network error — warn the driver but continue.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phase update failed: $e. Continuing anyway.')),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _phase = nextPhase;
        _advancing = false;
      });
    }
  }

  /// Shows a Yes/No confirmation dialog before proceeding to dropoff.
  /// Only proceeds to the en-route phase on "Yes".
  Future<bool> _showPickupConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shopping_bag, color: AppTheme.emerald),
            const SizedBox(width: 8),
            const Text('Confirm Pickup'),
          ],
        ),
        content: const Text('Have you picked up all items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Checks if an exception is a network error (vs a server error).
  bool _isNetworkError(Exception e) {
    // DioException network types are queued; other errors are surfaced.
    if (e.toString().contains('connection') ||
        e.toString().contains('timeout') ||
        e.toString().contains('network') ||
        e.toString().contains('socket')) {
      return true;
    }
    return false;
  }

  Future<void> _completeDelivery(BuildContext context) async {
    AppHaptics.medium();
    setState(() => _completing = true);
    try {
      await ref.read(driverApiProvider).completeTask(widget.task.id);
      if (mounted) {
        // Show the celebratory post-trip summary sheet with the earnings
        // breakdown before returning to the task pool.
        final earnings = widget.task.driverEarnings;
        PostTripSummarySheet.show(
          context,
          customerPaid: earnings, // Customer paid = driver earnings (0% commission)
          driverEarnings: earnings,
          tripType: widget.task.taskType == 'EssentialsDrop'
              ? 'Essentials Delivery'
              : 'Food Delivery',
          onDone: () {
            Navigator.pop(context); // Close the bottom sheet
            ref.read(activeTaskProvider.notifier).state = null;
            ref.read(driverSelectedTabProvider.notifier).state = 0;
          },
        );
      }
    } catch (e) {
      if (e is Exception && _isNetworkError(e)) {
        // Network error: queue the completion for replay when online.
        try {
          await ref.read(offlineMutationQueueProvider).enqueue(
                QueuedMutation(
                  id: '${widget.task.id}_complete',
                  method: 'POST',
                  path: 'api/driver/tasks/${widget.task.id}/complete',
                  createdAt: DateTime.now(),
                ),
              );
          if (mounted) {
            // Optimistically complete — show summary then return to task pool.
            final earnings = widget.task.driverEarnings;
            PostTripSummarySheet.show(
              context,
              customerPaid: earnings,
              driverEarnings: earnings,
              tripType: widget.task.taskType == 'EssentialsDrop'
                  ? 'Essentials Delivery'
                  : 'Food Delivery',
              onDone: () {
                Navigator.pop(context); // Close the bottom sheet
                ref.read(activeTaskProvider.notifier).state = null;
                ref.read(driverSelectedTabProvider.notifier).state = 0;
              },
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offline — completion saved. Will sync when back online.'),
                backgroundColor: AppTheme.warning,
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to complete: $e')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to complete: $e')),
          );
        }
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

  /// Shows a confirmation dialog for emergency release. The driver's task
  /// is unassigned and re-dispatched to another driver. The driver is set
  /// back to Online and not penalized.
  void _showEmergencyReleaseDialog(BuildContext context) {
    AppHaptics.heavy();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            const SizedBox(width: 8),
            const Text('Emergency Release'),
          ],
        ),
        content: const Text(
          'This will unassign you from the trip and send it to the next '
          'available driver. You will go back online. Use this only if you '
          'cannot complete the trip due to a breakdown or emergency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _performEmergencyRelease(context);
            },
            child: const Text('Release Task'),
          ),
        ],
      ),
    );
  }

  Future<void> _performEmergencyRelease(BuildContext context) async {
    setState(() => _completing = true);
    try {
      await ref.read(driverApiProvider).emergencyRelease(widget.task.id);
      if (mounted) {
        ref.read(activeTaskProvider.notifier).state = null;
        ref.read(driverSelectedTabProvider.notifier).state = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task released. Re-dispatched to another driver.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
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

/// Multi-order batched delivery state machine.
///
/// Phase 1: Pickup all orders at the store/restaurant.
/// Phase 2: Drop off each order in sequence.
class BatchedDeliveryScreen extends ConsumerStatefulWidget {
  const BatchedDeliveryScreen({super.key, required this.task});

  final DispatchTaskModel task;

  @override
  ConsumerState<BatchedDeliveryScreen> createState() =>
      _BatchedDeliveryScreenState();
}

class _BatchedDeliveryScreenState extends ConsumerState<BatchedDeliveryScreen> {
  List<DispatchTaskModel> _batchedTasks = [];
  final Set<String> _completed = {};
  bool _loading = true;
  bool _pickingUp = false;
  bool _completing = false;

  bool get _allPickedUp =>
      _batchedTasks.every((t) => t.status == 'OutForDelivery' || _completed.contains(t.id));

  bool get _allDelivered =>
      _batchedTasks.every((t) => _completed.contains(t.id));

  DispatchTaskModel? get _currentDropoff => _batchedTasks
      .where((t) => !_completed.contains(t.id))
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadBatched();
  }

  Future<void> _loadBatched() async {
    if (widget.task.batchGroupId == null) return;
    try {
      final tasks = await ref
          .read(driverApiProvider)
          .getBatchedTasks(widget.task.batchGroupId!);
      if (mounted) {
        setState(() {
          _batchedTasks = tasks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load batch: $e')),
        );
      }
    }
  }

  Future<void> _pickupAll() async {
    AppHaptics.medium();
    if (_pickingUp) return;
    setState(() => _pickingUp = true);

    try {
      final api = ref.read(driverApiProvider);
      for (final t in _batchedTasks) {
        final status = t.status;
        if (status == 'Assigned' || status == 'InProgress') {
          await api.markArrivedAtStore(t.id);
          await api.markOutForDelivery(t.id);
        } else if (status == 'ArrivedAtStore') {
          await api.markOutForDelivery(t.id);
        }
      }
      await _loadBatched();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pickup all failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingUp = false);
    }
  }

  Future<void> _completeDropoff(String taskId) async {
    AppHaptics.medium();
    if (_completing) return;
    setState(() => _completing = true);

    try {
      await ref.read(driverApiProvider).completeTask(taskId);
      if (mounted) {
        setState(() {
          _completed.add(taskId);
          _completing = false;
        });

        if (_allDelivered) {
          final earnings = _batchedTasks.fold<double>(
              0, (sum, t) => sum + t.driverEarnings);
          PostTripSummarySheet.show(
            context,
            customerPaid: earnings,
            driverEarnings: earnings,
            tripType: 'Batched Food Delivery',
            onDone: () {
              Navigator.pop(context);
              ref.read(activeTaskProvider.notifier).state = null;
              ref.read(driverSelectedTabProvider.notifier).state = 0;
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batched Delivery'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_allDelivered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 64, color: AppTheme.emerald),
              const SizedBox(height: 16),
              const Text(
                'All orders delivered',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (!_allPickedUp) {
      return _buildPickupAll(context);
    }

    return _buildDropoffSequence(context);
  }

  Widget _buildPickupAll(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pickup all orders at the restaurant before heading out.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          ..._batchedTasks.asMap().entries.map((e) {
            final index = e.key;
            final t = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoCard(
                icon: Icons.receipt_long,
                title: 'Order ${String.fromCharCode(65 + index)}',
                subtitle: t.dropoffAddress,
                iconColor: AppTheme.emerald,
              ),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _pickingUp ? null : _pickupAll,
              icon: _pickingUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Pickup All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropoffSequence(BuildContext context) {
    final current = _currentDropoff;
    if (current == null) return const SizedBox.shrink();

    final currentIndex = _batchedTasks.indexOf(current);
    final label = 'Dropoff Order ${String.fromCharCode(65 + currentIndex)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            icon: Icons.home_outlined,
            title: current.dropoffAddress,
            subtitle: label,
            iconColor: AppTheme.info,
          ),
          const SizedBox(height: 16),
          _NavigationButton(
            label: 'Navigate to customer',
            address: current.dropoffAddress,
          ),
          const SizedBox(height: 16),
          Text(
            'Pending dropoffs',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ..._batchedTasks.asMap().entries.map((e) {
            final index = e.key;
            final t = e.value;
            final isDone = _completed.contains(t.id);
            return ListTile(
              leading: Icon(
                isDone ? Icons.check_circle : Icons.circle_outlined,
                color: isDone ? AppTheme.emerald : null,
              ),
              title: Text('Order ${String.fromCharCode(65 + index)}'),
              subtitle: Text(t.dropoffAddress),
              trailing: isDone
                  ? null
                  : FilledButton(
                      onPressed: _completing ? null : () => _completeDropoff(t.id),
                      child: const Text('Complete'),
                    ),
            );
          }),
        ],
      ),
    );
  }
}
