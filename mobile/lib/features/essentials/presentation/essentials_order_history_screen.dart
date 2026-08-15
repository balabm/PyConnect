import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';

final essentialsOrdersProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(essentialsApiProvider);
  return await api.listOrders();
});

class EssentialsOrderHistoryScreen extends ConsumerWidget {
  const EssentialsOrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(essentialsOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: RefreshIndicator(
        onRefresh: () {
          AppHaptics.light();
          return ref.refresh(essentialsOrdersProvider.future);
        },
        child: ordersAsync.when(
          loading: () => const ShimmerList(withImage: false, count: 5),
          error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(essentialsOrdersProvider),
          ),
          data: (orders) => orders.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  subtitle: 'Your essentials orders will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index] as Map<String, dynamic>;
                    return _OrderCard(order: order);
                  },
                ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'Unknown';
    final totalAmount = order['totalAmount'] ?? 0;
    final orderId = order['orderId'] as String? ?? order['id'] as String? ?? '';

    return AppCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _statusVariant(status).foreground.withValues(alpha: 0.15),
            child: Icon(_statusIcon(status), color: _statusVariant(status).foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${orderId.substring(0, 8).toUpperCase()}'),
                Text(status, style: TextStyle(color: _statusVariant(status).foreground)),
              ],
            ),
          ),
          Text(
            '\u20B9$totalAmount',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  BadgeVariant _statusVariant(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return BadgeVariant.warning;
      case 'preparing':
        return BadgeVariant.info;
      case 'outfordelivery':
      case 'out_for_delivery':
        return BadgeVariant.info;
      case 'delivered':
        return BadgeVariant.success;
      case 'cancelled':
        return BadgeVariant.danger;
      default:
        return BadgeVariant.neutral;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.shopping_bag;
    }
  }
}
