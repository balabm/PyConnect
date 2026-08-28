import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Aggregated notifications screen — shows recent orders, rides, and bookings
/// as a unified activity feed. This serves as the in-app notification center
/// until a dedicated push notification history is available on the backend.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<NotificationItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final items = <NotificationItem>[];

      // Load recent food orders
      try {
        final orders = await api.get('/api/orders', queryParameters: {'page': 1, 'pageSize': 5});
        for (final order in (orders as List)) {
          final map = order as Map<String, dynamic>;
          final status = map['status'] as String? ?? 'Unknown';
          final vendorName = map['vendorName'] as String? ?? 'Restaurant';
          final orderId = map['orderId'] as String? ?? map['id'] as String? ?? '';
          items.add(NotificationItem(
            id: 'food_$orderId',
            type: NotificationType.foodOrder,
            title: '$vendorName order $status',
            subtitle: 'Order #${orderId.substring(0, 8).toUpperCase()}',
            icon: Icons.restaurant,
            color: _statusColor(status),
            route: '/food/orders/$orderId',
            timestamp: map['createdAt'] as String? ?? map['orderedAt'] as String?,
          ));
        }
      } catch (_) {}

      // Load recent rides
      try {
        final rides = await api.get('/api/rides', queryParameters: {'page': 1, 'pageSize': 5});
        for (final ride in (rides as List)) {
          final map = ride as Map<String, dynamic>;
          final status = map['status'] as String? ?? 'Unknown';
          final rideId = map['rideId'] as String? ?? map['id'] as String? ?? '';
          final fare = map['fare'] ?? map['actualFare'] ?? 0;
          items.add(NotificationItem(
            id: 'ride_$rideId',
            type: NotificationType.ride,
            title: 'Ride $status',
            subtitle: 'Fare: \u20B9$fare',
            icon: Icons.directions_car,
            color: _statusColor(status),
            route: '/rides/history',
            timestamp: map['createdAt'] as String? ?? map['requestedAt'] as String?,
          ));
        }
      } catch (_) {}

      // Sort by timestamp descending
      items.sort((a, b) {
        final aTime = DateTime.tryParse(a.timestamp ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b.timestamp ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed' || s == 'ready') return AppTheme.emerald;
    if (s == 'cancelled' || s == 'failed') return AppTheme.danger;
    if (s == 'pending' || s == 'preparing' || s == 'accepted') return AppTheme.warning;
    return AppTheme.info;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              _loadNotifications();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                      const SizedBox(height: 12),
                      Text('Could not load notifications', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: AppTheme.slate.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text('No notifications yet', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Your recent orders and rides will appear here.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return FadeSlideIn(
                            delay: Duration(milliseconds: index * 50),
                            child: _NotificationCard(item: item),
                          );
                        },
                      ),
                    ),
    );
  }
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.timestamp,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String? timestamp;
}

enum NotificationType { foodOrder, ride, booking, promo, system }

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          AppHaptics.light();
          context.push(item.route);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
