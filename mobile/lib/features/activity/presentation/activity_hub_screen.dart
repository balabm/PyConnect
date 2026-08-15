import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Providers that fetch food orders and ride history in parallel.
final _foodOrdersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(foodApiProvider);
  return await api.listOrders();
});

final _rideHistoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(ridesApiProvider);
  return await api.listRides();
});

/// Stub: my-stays bookings endpoint is not yet available.
final _staysBookingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return [];
});

/// Stub: my-rentals endpoint is not yet available.
final _rentalsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return [];
});

/// A unified activity feed aggregating food orders, ride history, and
/// venue bookings into a single chronological list.
class ActivityHubScreen extends ConsumerStatefulWidget {
  const ActivityHubScreen({super.key});

  @override
  ConsumerState<ActivityHubScreen> createState() => _ActivityHubScreenState();
}

class _ActivityHubScreenState extends ConsumerState<ActivityHubScreen> {
  String _filter = 'All'; // All, Stays, Food, Rides, Rentals

  @override
  Widget build(BuildContext context) {
    final foodAsync = ref.watch(_foodOrdersProvider);
    final rideAsync = ref.watch(_rideHistoryProvider);
    final staysAsync = ref.watch(_staysBookingsProvider);
    final rentalsAsync = ref.watch(_rentalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Activity')),
      body: Column(
        children: [
          // Category filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Stays'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Food'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rides'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rentals'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_foodOrdersProvider);
                ref.invalidate(_rideHistoryProvider);
                ref.invalidate(_staysBookingsProvider);
                ref.invalidate(_rentalsProvider);
              },
              child: _buildBody(context, foodAsync, rideAsync, staysAsync, rentalsAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.emerald : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppTheme.emerald : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<dynamic>> foodAsync,
    AsyncValue<List<dynamic>> rideAsync,
    AsyncValue<List<dynamic>> staysAsync,
    AsyncValue<List<dynamic>> rentalsAsync,
  ) {
    // Loading state
    if (foodAsync.isLoading || rideAsync.isLoading || staysAsync.isLoading || rentalsAsync.isLoading) {
      return const ShimmerList(count: 6, withImage: false);
    }

    // Error state
    final allError = foodAsync.hasError && rideAsync.hasError && staysAsync.hasError && rentalsAsync.hasError;
    if (allError) {
      return ErrorState(
        message: 'Could not load activity. Please try again.',
        onRetry: () {
          ref.invalidate(_foodOrdersProvider);
          ref.invalidate(_rideHistoryProvider);
          ref.invalidate(_staysBookingsProvider);
          ref.invalidate(_rentalsProvider);
        },
      );
    }

    // Stays and rentals tabs are stubs pending backend booking endpoints.
    if (_filter == 'Stays' || _filter == 'Rentals') {
      return EmptyState(
        icon: _filter == 'Stays' ? Icons.bed_outlined : Icons.key_outlined,
        title: 'No ${_filter.toLowerCase()} yet',
        subtitle: '$_filter booking history will appear here once the backend endpoint is wired.',
      );
    }

    // Build unified activity items
    final items = <_ActivityItem>[];

    final foodOrders = foodAsync.valueOrNull ?? [];
    if (_filter == 'All' || _filter == 'Food') {
      for (final order in foodOrders) {
        final map = order as Map<String, dynamic>;
        final status = (map['status'] as String?) ?? '';
        final statusLower = status.toLowerCase();
        final isActive = statusLower == 'pending' ||
            statusLower == 'confirmed' ||
            statusLower == 'preparing' ||
            statusLower == 'ready' ||
            statusLower == 'outfordelivery' ||
            statusLower == 'out_for_delivery';

        items.add(_ActivityItem(
          type: _ActivityType.food,
          title: (map['vendorName'] as String?) ?? 'Food Order',
          subtitle: '${(map['items'] as List?)?.length ?? 0} items',
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          onTap: () => context.push('/food/orders/${map['id']}'),
        ));
      }
    }

    final rides = rideAsync.valueOrNull ?? [];
    if (_filter == 'All' || _filter == 'Rides') {
      for (final ride in rides) {
        final map = ride as Map<String, dynamic>;
        final status = (map['status'] as String?) ?? '';
        final statusLower = status.toLowerCase();
        final isActive = statusLower == 'requested' ||
            statusLower == 'accepted' ||
            statusLower == 'arrivedatpickup' ||
            statusLower == 'inprogress' ||
            statusLower == 'in_progress';

        items.add(_ActivityItem(
          type: _ActivityType.ride,
          title: 'Ride',
          subtitle: '${map['pickupAddress'] ?? ''} → ${map['dropoffAddress'] ?? ''}',
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          onTap: () => context.push('/rides/${map['id']}'),
        ));
      }
    }

    // Sort: active first, then by most recent (assuming API returns most recent first)
    items.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return 0;
    });

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No activity yet',
        subtitle: 'Start exploring to see your orders and rides here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => FadeSlideIn(
        delay: Duration(milliseconds: index * 50),
        child: _ActivityCard(item: items[index]),
      ),
    );
  }
}

enum _ActivityType { food, ride }

class _ActivityItem {
  const _ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.id,
    required this.isActive,
    required this.onTap,
    this.amount,
  });

  final _ActivityType type;
  final String title;
  final String subtitle;
  final String status;
  final String id;
  final bool isActive;
  final VoidCallback onTap;
  final double? amount;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});
  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      _ActivityType.food => Icons.restaurant_outlined,
      _ActivityType.ride => Icons.two_wheeler_outlined,
    };

    final iconColor = switch (item.type) {
      _ActivityType.food => AppTheme.emerald,
      _ActivityType.ride => AppTheme.emerald,
    };

    final statusVariant = item.isActive
        ? BadgeVariant.warning
        : switch (item.status.toLowerCase()) {
            'completed' => BadgeVariant.success,
            'delivered' => BadgeVariant.success,
            'cancelled' => BadgeVariant.danger,
            _ => BadgeVariant.info,
          };

    final statusLabel = _friendlyStatus(item.status);

    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: item.isActive
                ? AppTheme.warning.withValues(alpha: 0.3)
                : Theme.of(context).dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.light
                  ? AppTheme.cardShadow
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Service icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status + amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: statusLabel, variant: statusVariant),
                if (item.amount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '\u20B9${item.amount!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyStatus(String status) {
    return switch (status.toLowerCase()) {
      'pending' => 'Pending',
      'confirmed' => 'Confirmed',
      'preparing' => 'Preparing',
      'ready' => 'Ready',
      'outfordelivery' || 'out_for_delivery' => 'On the way',
      'delivered' => 'Delivered',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'requested' => 'Finding driver',
      'accepted' => 'Driver assigned',
      'arrivedatpickup' => 'Driver arrived',
      'inprogress' || 'in_progress' => 'In progress',
      _ => status,
    };
  }
}
