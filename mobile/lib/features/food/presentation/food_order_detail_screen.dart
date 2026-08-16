import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers.dart';
import '../../activity/presentation/post_completion_sheet.dart';

final foodOrderDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, orderId) async {
  final api = ref.watch(foodApiProvider);
  return await api.getOrder(orderId);
});

class FoodOrderDetailScreen extends ConsumerStatefulWidget {
  const FoodOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<FoodOrderDetailScreen> createState() => _FoodOrderDetailScreenState();
}

class _FoodOrderDetailScreenState extends ConsumerState<FoodOrderDetailScreen> {
  bool _completionSheetShown = false;
  Timer? _pollTimer;

  /// Statuses that are considered "active" — the order is still in progress
  /// and the screen should poll for live updates.
  static const _activeStatuses = {
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'outfordelivery',
    'out_for_delivery',
  };

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Starts or stops the polling timer based on the current order status.
  /// The backend does not yet have a SignalR hub for food orders, so we poll
  /// every 10 seconds while the order is in an active state. Once the order
  /// reaches a terminal state (delivered, cancelled), polling stops.
  void _updatePolling(String status) {
    final isActive = _activeStatuses.contains(status.toLowerCase());

    if (isActive && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          ref.invalidate(foodOrderDetailProvider(widget.orderId));
        }
      });
    } else if (!isActive && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(foodOrderDetailProvider(widget.orderId));

    // Manage the polling timer based on the latest order status.
    orderAsync.whenData((order) {
      final status = (order['status'] as String?) ?? '';
      _updatePolling(status);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(foodOrderDetailProvider(widget.orderId)),
        ),
        data: (order) {
          _maybeShowCompletionSheet(order);
          return _OrderDetailBody(order: order);
        },
      ),
    );
  }

  void _maybeShowCompletionSheet(Map<String, dynamic> order) {
    final status = (order['status'] as String?)?.toLowerCase() ?? '';
    if (status != 'delivered' || _completionSheetShown) return;
    _completionSheetShown = true;

    final vendorId = order['vendorId']?.toString();
    final orderId = order['id']?.toString();
    final vendorName = order['vendorName'] as String? ?? 'the restaurant';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PostCompletionSheet.show(
        context,
        title: vendorName,
        subtitle: 'How was your order?',
        vendorId: vendorId,
        orderId: orderId,
      );
    });
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'Unknown';
    final items = order['items'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusTimeline(status: status),
        const SizedBox(height: 24),
        Text('Items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in items)
          _ItemRow(item: item as Map<String, dynamic>),
        const Divider(height: 32),
        _PricingSection(order: order),
        const SizedBox(height: 16),
        if (order['deliveryAddress'] != null) ...[
          Text('Delivery Address', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(order['deliveryAddress'] as String, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});
  final String status;

  static const _stages = ['Pending', 'Preparing', 'Ready', 'OutForDelivery', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexWhere((s) => s.toLowerCase() == status.toLowerCase());
    final isCancelled = status.toLowerCase() == 'cancelled';

    if (isCancelled) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.cancel, color: AppTheme.danger),
            const SizedBox(width: 12),
            const Text('Order Cancelled', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Status', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                final reached = i ~/ 2 < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: reached ? AppTheme.emerald : Theme.of(context).dividerColor,
                  ),
                );
              }
              final stageIndex = i ~/ 2;
              final reached = stageIndex <= currentIndex;
              return Icon(
                reached ? Icons.check_circle : Icons.radio_button_unchecked,
                color: reached ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _stages.map((s) {
              final reached = _stages.indexOf(s) <= currentIndex;
              return Text(
                s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}').trim(),
                style: TextStyle(fontSize: 9, color: reached ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: reached ? FontWeight.bold : FontWeight.normal),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                if (item['specialInstructions'] != null)
                  Text(item['specialInstructions'] as String, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('x${item['quantity'] ?? 1}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Text('\u20B9${item['unitPrice'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  const _PricingSection({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          FareRow(label: 'Subtotal', value: '\u20B9${order['subTotal']}'),
          FareRow(label: 'Delivery Fee', value: '\u20B9${order['deliveryFee']}'),
          if ((order['lateNightDriverBonus'] ?? 0) != 0)
            FareRow(label: 'Late Night Bonus', value: '\u20B9${order['lateNightDriverBonus']}'),
          FareRow(label: 'Platform Fee', value: '\u20B9${order['platformFee']}'),
          const Divider(),
          FareRow(label: 'Total', value: '\u20B9${order['totalAmount']}', bold: true),
        ],
      ),
    );
  }
}
