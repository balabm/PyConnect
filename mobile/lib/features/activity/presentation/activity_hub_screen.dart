import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loaders.dart';
import '../../../core/widgets/empty_state_view.dart';

/// Unified activity feed provider that calls GET /api/activity/all.
/// Falls back to separate endpoints if the unified endpoint fails.
final _unifiedActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authTokenProvider);
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('/api/activity/all');
    final list = response as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  } catch (_) {
    // Fallback: return empty list, separate providers will fill in
    return [];
  }
});

/// Fallback providers that fetch food orders, ride history, stays, and rentals in parallel.
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
    final unifiedAsync = ref.watch(_unifiedActivityProvider);
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
                ref.invalidate(_unifiedActivityProvider);
                ref.invalidate(_foodOrdersProvider);
                ref.invalidate(_rideHistoryProvider);
                ref.invalidate(_staysBookingsProvider);
                ref.invalidate(_rentalsProvider);
              },
              child: _buildBody(context, unifiedAsync, foodAsync, rideAsync, staysAsync, rentalsAsync),
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
    AsyncValue<List<Map<String, dynamic>>> unifiedAsync,
    AsyncValue<List<dynamic>> foodAsync,
    AsyncValue<List<dynamic>> rideAsync,
    AsyncValue<List<Map<String, dynamic>>> staysAsync,
    AsyncValue<List<dynamic>> rentalsAsync,
  ) {
    // If the unified endpoint returned data, use it directly.
    final unified = unifiedAsync.valueOrNull;
    if (unified != null && unified.isNotEmpty) {
      return _buildUnifiedList(context, unified);
    }

    // Loading state (fallback providers)
    if (foodAsync.isLoading || rideAsync.isLoading || staysAsync.isLoading || rentalsAsync.isLoading) {
      return const SkeletonList(type: SkeletonType.activity, count: 6);
    }

    // Error state — only show error if ALL providers failed
    final allError = foodAsync.hasError && rideAsync.hasError && staysAsync.hasError && rentalsAsync.hasError;
    if (allError) {
      return EmptyStateView(
        isError: true,
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        subtitle: 'Could not load activity. Please try again.',
        actionLabel: 'Retry',
        onAction: () {
          ref.invalidate(_unifiedActivityProvider);
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
        final guests = booking['guests'] ?? booking['guestCount'];
        final bookingRef = booking['bookingReference'] ?? booking['referenceId'] ?? booking['id'];
        String subtitle = 'Stay booking';
        if (checkIn != null && checkOut != null) {
          subtitle = '$checkIn → $checkOut';
        }
        if (guests != null) {
          subtitle += ' · $guests ${guests == 1 ? 'guest' : 'guests'}';
        }
        if (bookingRef != null) {
          subtitle += ' · Ref: $bookingRef';
        }

        items.add(_ActivityItem(
          type: _ActivityType.stay,
          title: 'Homestay Booking',
          subtitle: subtitle,
          status: status,
          amount: (booking['totalAmount'] as num?)?.toDouble(),
          id: (booking['id'] as String?) ?? '',
          isActive: isActive,
          createdAt: DateTime.tryParse(booking['createdAt'] as String? ?? '') ?? DateTime.now(),
          onTap: () => context.push('/activity/stay/${booking['id']}'),
          ctaLabel: 'View Stay Pass',
          ctaAction: () => context.push('/activity/stay/${booking['id']}'),
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

        // Build subtitle from item names if available, fall back to count.
        final itemsList = map['items'] as List? ?? [];
        String subtitle;
        if (itemsList.isEmpty) {
          subtitle = '$itemCount ${itemCount == 1 ? 'item' : 'items'}';
        } else {
          final names = itemsList.map((i) {
            final im = i as Map<String, dynamic>;
            return (im['name'] as String?) ?? '';
          }).where((n) => n.isNotEmpty).toList();
          if (names.isEmpty) {
            subtitle = '$itemCount ${itemCount == 1 ? 'item' : 'items'}';
          } else if (names.length <= 3) {
            subtitle = names.join(', ');
          } else {
            subtitle = '${names.take(3).join(', ')} +${names.length - 3} more';
          }
        }

        items.add(_ActivityItem(
          type: _ActivityType.food,
          title: vendorName,
          subtitle: subtitle,
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
          onTap: () => context.push('/food/orders/${map['id']}'),
          ctaLabel: isActive ? 'Track Order' : 'Reorder',
          ctaAction: () => context.push('/food/orders/${map['id']}'),
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
        final driverName = (map['driverName'] as String?) ?? '';

        String rideSubtitle = '${map['pickupAddress'] ?? ''} → ${map['dropoffAddress'] ?? ''}';
        if (driverName.isNotEmpty) {
          rideSubtitle += ' · $driverName';
        }

        items.add(_ActivityItem(
          type: _ActivityType.ride,
          title: '$vehicleType Ride',
          subtitle: rideSubtitle,
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
          onTap: () => context.push('/rides/${map['id']}'),
          ctaLabel: isActive ? 'Track Ride' : 'View Receipt',
          ctaAction: () => context.push('/rides/${map['id']}/receipt'),
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
          final end = DateTime.tryParse(endTime.toString());
          if (end != null && isActive) {
            final remaining = end.difference(DateTime.now());
            if (remaining.isNegative) {
              subtitle = '$scooterModel \u2022 Overdue';
            } else {
              final h = remaining.inHours;
              final m = remaining.inMinutes.remainder(60);
              subtitle = '$scooterModel \u2022 Return in ${h}h ${m}m';
            }
          } else {
            subtitle = '$scooterModel \u2022 $startTime \u2192 $endTime';
          }
        } else if (startTime != null) {
          subtitle = '$scooterModel \u2022 from $startTime';
        }

        items.add(_ActivityItem(
          type: _ActivityType.rental,
          title: 'Scooter Rental',
          subtitle: subtitle,
          status: status,
          amount: (map['totalAmount'] as num?)?.toDouble(),
          id: (map['id'] as String?) ?? '',
          isActive: isActive,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
          onTap: () => context.push('/rentals'),
          ctaLabel: 'View Rental QR',
          ctaAction: () => context.push('/rentals'),
        ));
      }
    }

    // Sort: active first, then chronologically (most recent first)
    items.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (items.isEmpty) {
      return _buildEmptyState(context);
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

  /// Builds the activity list from the unified /api/activity/all endpoint.
  Widget _buildUnifiedList(BuildContext context, List<Map<String, dynamic>> unified) {
    final items = <_ActivityItem>[];
    for (final raw in unified) {
      final type = (raw['type'] as String?) ?? '';
      final typeLower = type.toLowerCase();
      _ActivityType? actType;
      if (typeLower == 'stay') actType = _ActivityType.stay;
      else if (typeLower == 'food') actType = _ActivityType.food;
      else if (typeLower == 'ride') actType = _ActivityType.ride;
      else if (typeLower == 'rental') actType = _ActivityType.rental;
      if (actType == null) continue;

      final filterName = actType == _ActivityType.stay ? 'Stays'
          : actType == _ActivityType.food ? 'Food'
          : actType == _ActivityType.ride ? 'Rides'
          : 'Rentals';
      if (_filter != 'All' && _filter != filterName) continue;

      final status = (raw['status'] as String?) ?? '';
      final statusLower = status.toLowerCase();
      final isActive = statusLower == 'pending' ||
          statusLower == 'confirmed' ||
          statusLower == 'preparing' ||
          statusLower == 'ready' ||
          statusLower == 'outfordelivery' ||
          statusLower == 'out_for_delivery' ||
          statusLower == 'requested' ||
          statusLower == 'accepted' ||
          statusLower == 'arrivedatpickup' ||
          statusLower == 'inprogress' ||
          statusLower == 'in_progress' ||
          statusLower == 'checkedin' ||
          statusLower == 'checked_in';

      items.add(_ActivityItem(
        type: actType,
        title: (raw['title'] as String?) ?? 'Activity',
        subtitle: (raw['subtitle'] as String?) ?? '',
        status: status,
        amount: (raw['amount'] as num?)?.toDouble(),
        id: (raw['id'] as String?) ?? '',
        isActive: isActive,
        createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? DateTime.now(),
        onTap: () => _navigateToDetail(context, actType!, raw['id'] as String? ?? ''),
        ctaLabel: isActive ? 'Track' : 'View',
        ctaAction: () => _navigateToDetail(context, actType!, raw['id'] as String? ?? ''),
      ));
    }

    items.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => FadeSlideIn(
        delay: Duration(milliseconds: index * 50),
        child: _ActivityCard(item: items[index]),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, _ActivityType type, String id) {
    switch (type) {
      case _ActivityType.stay:
        context.push('/activity/stay/$id');
      case _ActivityType.food:
        context.push('/food/orders/$id');
      case _ActivityType.ride:
        context.push('/rides/$id');
      case _ActivityType.rental:
        context.push('/rentals');
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    if (_filter == 'Food') {
      return EmptyStateView(
        icon: Icons.restaurant_outlined,
        title: 'Hungry?',
        subtitle: 'Your past food orders will appear here.',
        actionLabel: 'Explore Restaurants',
        onAction: () => context.go('/food'),
      );
    }
    if (_filter == 'Rides') {
      return const EmptyStateView(
        icon: Icons.local_taxi_outlined,
        title: 'No rides yet',
        subtitle: 'Your ride history will show up here.',
      );
    }
    if (_filter == 'Stays') {
      return const EmptyStateView(
        icon: Icons.bed_outlined,
        title: 'No stays yet',
        subtitle: 'Your bookings will appear here.',
      );
    }
    if (_filter == 'Rentals') {
      return const EmptyStateView(
        icon: Icons.key_outlined,
        title: 'No rentals yet',
        subtitle: 'Your rental history will show up here.',
      );
    }
    return const EmptyStateView(
      icon: Icons.receipt_long_outlined,
      title: 'No Activity Yet',
      subtitle: 'Your bookings, rides, and orders will appear here.',
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
    required this.createdAt,
    this.amount,
    this.ctaLabel,
    this.ctaAction,
  });

  final _ActivityType type;
  final String title;
  final String subtitle;
  final String status;
  final String id;
  final bool isActive;
  final VoidCallback onTap;
  final double? amount;
  final String? ctaLabel;
  final VoidCallback? ctaAction;
  final DateTime createdAt;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            // CTA button
            if (item.ctaLabel != null && item.ctaAction != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: item.ctaAction,
                  icon: Icon(
                    item.isActive ? Icons.track_changes : Icons.receipt_long,
                    size: 16,
                  ),
                  label: Text(item.ctaLabel!),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.emerald,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
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
