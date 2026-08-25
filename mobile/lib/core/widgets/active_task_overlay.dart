import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/food/data/food_api.dart';
import '../../features/rides/data/rides_api.dart';
import '../animations/haptic.dart';
import '../providers.dart';
import '../theme/app_theme.dart';

/// Represents an active task (ride or food order) that the user should be
/// able to quickly return to from anywhere in the app.
class ActiveTask {
  ActiveTask({
    required this.id,
    required this.type,
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String id;
  final ActiveTaskType type;
  final String status;
  final String label;
  final IconData icon;
  final Color color;
  final String route;
}

enum ActiveTaskType { ride, foodOrder }

/// Polls the backend for active rides and food orders. Returns the most
/// recent active task (if any) that the user can return to.
final activeTaskProvider = FutureProvider.autoDispose<ActiveTask?>((ref) async {
  final ridesApi = ref.watch(ridesApiProvider);
  final foodApi = ref.watch(foodApiProvider);

  try {
    // Check for active food orders
    final orders = await foodApi.listOrders(page: 1, pageSize: 5);
    for (final order in orders) {
      final status = (order['status'] as String?).toString().toLowerCase();
      if (_activeFoodStatuses.contains(status)) {
        final orderId = order['id']?.toString() ?? '';
        return ActiveTask(
          id: orderId,
          type: ActiveTaskType.foodOrder,
          status: status,
          label: _foodStatusLabel(status),
          icon: Icons.restaurant,
          color: AppTheme.warning,
          route: '/food/order/$orderId',
        );
      }
    }
  } catch (_) {
    // Ignore
  }

  try {
    // Check for active rides via the ride list
    final rides = await ridesApi.listRides(page: 1, pageSize: 5);
    for (final ride in rides) {
      final status = (ride['status'] as String?).toString().toLowerCase();
      if (_activeRideStatuses.contains(status)) {
        final rideId = ride['id']?.toString() ?? '';
        return ActiveTask(
          id: rideId,
          type: ActiveTaskType.ride,
          status: status,
          label: _rideStatusLabel(status),
          icon: Icons.two_wheeler,
          color: AppTheme.info,
          route: '/rides/$rideId',
        );
      }
    }
  } catch (_) {
    // Ignore
  }

  return null;
});

const _activeFoodStatuses = {
  'pending', 'confirmed', 'preparing', 'ready', 'outfordelivery', 'out_for_delivery',
};

const _activeRideStatuses = {
  'requested', 'accepted', 'enroute', 'en_route', 'arrived', 'started', 'ongoing',
};

String _foodStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Order placed — waiting for restaurant';
    case 'confirmed':
      return 'Order confirmed by restaurant';
    case 'preparing':
      return 'Preparing your order';
    case 'ready':
      return 'Order ready for pickup';
    case 'outfordelivery':
    case 'out_for_delivery':
      return 'On the way to you';
    default:
      return 'Order in progress';
  }
}

String _rideStatusLabel(String status) {
  switch (status) {
    case 'requested':
      return 'Finding your captain...';
    case 'accepted':
      return 'Captain assigned — en route to pickup';
    case 'enroute':
    case 'en_route':
      return 'Captain is on the way';
    case 'arrived':
      return 'Captain has arrived at pickup';
    case 'started':
    case 'ongoing':
      return 'Ride in progress';
    default:
      return 'Ride in progress';
  }
}

/// A floating pill widget that shows the user's active task (ride or food
/// order) at the top of the screen. Tapping it navigates to the tracking
/// screen for that task.
///
/// Designed to be placed in the app's root [MaterialApp.builder] wrapper so
/// it persists across all screens.
class ActiveTaskOverlay extends ConsumerWidget {
  const ActiveTaskOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(activeTaskProvider);

    final task = taskAsync.valueOrNull;
    if (task == null) return child;

    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: _ActiveTaskPill(task: task),
        ),
      ],
    );
  }
}

class _ActiveTaskPill extends StatefulWidget {
  const _ActiveTaskPill({required this.task});
  final ActiveTask task;

  @override
  State<_ActiveTaskPill> createState() => _ActiveTaskPillState();
}

class _ActiveTaskPillState extends State<_ActiveTaskPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        context.push(widget.task.route);
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.task.color.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: widget.task.color.withValues(
                      alpha: 0.3 + _pulseController.value * 0.2),
                  blurRadius: 12 + _pulseController.value * 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(widget.task.icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.task.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
