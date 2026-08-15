import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Providers that fetch food orders, ride history, stays, and rentals in parallel.
final _foodOrdersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  ref.watch(authTokenProvider);
  final api = ref.watch(foodApiProvider);
  return await api.listOrders();
});

final _rideHistoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  ref.watch(authTokenProvider);
  final api = ref.watch(ridesApiProvider);
  return await api.listRides();
});

final _staysBookingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authTokenProvider);
  return ref.watch(staysApiProvider).listMyBookings();
});

final _rentalsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  ref.watch(authTokenProvider);
  return ref.watch(rentalApiProvider).listRentals();
});

/// A unified activity feed aggregating food orders, ride history, stays,
/// and rentals into a single chronological list.
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
    AsyncValue<List<Map<String, dynamic>>> staysAsync,
    AsyncValue<List<dynamic>> rentalsAsync,
  ) {
    // Loading state
    if (foodAsync.isLoading || rideAsync.isLoading || staysAsync.isLoading || rentalsAsync.isLoading) {
      return const ShimmerList(count: 6, withImage: false);
    }

    // Error state — only show error if ALL providers failed
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

    // Build unified activity items
    final items = <_ActivityItem>[];

    // Stays
    final stays = staysAsync.valueOrNull ?? [];
    if (_filter == 'All' || _filter == 'Stays') {
      for (final booking in stays) {
        final status = (booking['status'] as String?) ?? '';
        final statusLower = status.toLowerCase();
        final isActive = statusLower == 'pending' ||
            statusLower == 'confirmed' ||
            statusLower == 'checkedin' ||
            statusLower == 'checked_in';

        final checkIn = booking['checkInDate'];
        final checkOut = booking['checkOutDate'];
        String subtitle = 'Stay booking';
        if (checkIn != null && checkOut != null) {
          subtitle = '$checkIn → $checkOut';
        }

        items.add(_ActivityItem(
          type: _ActivityType.stay,
          title: 'Homestay Booking',
          subtitle: subtitle,
          status: status,
          amount: (booking['totalAmount'] as num?)?.toDouble(),
          id: (booking['id'] as String?) ?? '',
          isActive: isActive,
          onTap: () => context.push('/stays'),
        ));
      }
    }

    // Food orders
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

        final itemCount = (map['items'] as List?)?.length ?? 0;
        final vendorName = (map['vendorName'] as String?) ?? 'Food Order';

        items.add(_ActivityItem(
          type: _ActivityType.food,
          title: vendorName,
          subtitle: '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          onTap: () => context.push('/food/orders/${map['id']}'),
        ));
      }
    }

    // Rides
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

        final vehicleType = (map['vehicleType'] as String?) ?? 'Ride';

        items.add(_ActivityItem(
          type: _ActivityType.ride,
          title: '$vehicleType Ride',
          subtitle: '${map['pickupAddress'] ?? ''} → ${map['dropoffAddress'] ?? ''}',
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          onTap: () => context.push('/rides/${map['id']}'),
        ));
      }
    }

    // Rentals
    final rentals = rentalsAsync.valueOrNull ?? [];
    if (_filter == 'All' || _filter == 'Rentals') {
      for (final rental in rentals) {
        final map = rental as Map<String, dynamic>;
        final status = (map['status'] as String?) ?? '';
        final statusLower = status.toLowerCase();
        final isActive = statusLower == 'active' ||
            statusLower == 'ongoing' ||
            statusLower == 'pickedup' ||
            statusLower == 'picked_up';

        final scooterModel = (map['scooterModel'] as String?) ?? 'Scooter';
        final startTime = map['startTime'] ?? map['createdAt'];
        final endTime = map['endTime'];

        String subtitle = scooterModel;
        if (startTime != null && endTime != null) {
          subtitle = '$scooterModel · $startTime → $endTime';
        } else if (startTime != null) {
          subtitle = '$scooterModel · from $startTime';
        }

        items.add(_ActivityItem(
          type: _ActivityType.rental,
          title: 'Scooter Rental',
          subtitle: subtitle,
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          onTap: () => context.push('/transit'),
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
      return EmptyState(
        icon: _filter == 'Stays'
            ? Icons.bed_outlined
            : _filter == 'Food'
                ? Icons.restaurant_outlined
                : _filter == 'Rides'
                    ? Icons.two_wheeler_outlined
                    : _filter == 'Rentals'
                        ? Icons.key_outlined
                        : Icons.receipt_long_outlined,
        title: 'No ${_filter == 'All' ? 'activity' : _filter.toLowerCase()} yet',
        subtitle: _filter == 'All'
            ? 'Start exploring to see your orders and rides here.'
            : 'Your ${_filter.toLowerCase()} history will appear here.',
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

enum _ActivityType { stay, food, ride, rental }

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
      _ActivityType.stay => Icons.bed_outlined,
      _ActivityType.food => Icons.restaurant_outlined,
      _ActivityType.ride => Icons.two_wheeler_outlined,
      _ActivityType.rental => Icons.key_outlined,
    };

    final iconColor = switch (item.type) {
      _ActivityType.stay => AppTheme.info,
      _ActivityType.food => AppTheme.emerald,
      _ActivityType.ride => AppTheme.warning,
      _ActivityType.rental => AppTheme.danger,
    };

    final statusVariant = item.isActive
        ? BadgeVariant.warning
        : switch (item.status.toLowerCase()) {
            'completed' => BadgeVariant.success,
            'delivered' => BadgeVariant.success,
            'checkedin' || 'checked_in' => BadgeVariant.success,
            'returned' => BadgeVariant.success,
            'cancelled' => BadgeVariant.danger,
            'expired' => BadgeVariant.danger,
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
                    maxLines: 2,
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
      'checkedin' || 'checked_in' => 'Checked in',
      'active' => 'Active',
      'ongoing' => 'Ongoing',
      'pickedup' || 'picked_up' => 'Picked up',
      'returned' => 'Returned',
      'expired' => 'Expired',
      _ => status,
    };
  }
}
