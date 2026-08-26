import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers.dart';
import '../application/food_order_signalr_provider.dart';
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
  StreamSubscription<String>? _signalRSub;

  /// Statuses that are considered "active" — the order is still in progress
  /// and the screen should listen for live updates.
  static const _activeStatuses = {
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'outfordelivery',
    'out_for_delivery',
  };

  @override
  void initState() {
    super.initState();
    _initSignalR();
  }

  void _initSignalR() {
    // Listen for real-time order updates via SignalR (VendorHub broadcasts
    // "OrderUpdated" events). When we receive an update for our order ID,
    // invalidate the provider to refresh the data immediately.
    _signalRSub = ref.read(foodOrderUpdateStreamProvider.stream).listen((updatedOrderId) {
      if (mounted && updatedOrderId == widget.orderId) {
        ref.invalidate(foodOrderDetailProvider(widget.orderId));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _signalRSub?.cancel();
    super.dispose();
  }

  /// Starts or stops the fallback polling timer based on the current order
  /// status. SignalR is the primary update mechanism, but we keep a slower
  /// polling fallback (every 30s) in case the WebSocket connection drops.
  void _updatePolling(String status) {
    final isActive = _activeStatuses.contains(status.toLowerCase());

    if (isActive && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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

    // Manage the fallback polling timer based on the latest order status.
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
          return _OrderDetailBody(order: order, orderId: widget.orderId);
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

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order, required this.orderId});
  final Map<String, dynamic> order;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order['status'] as String? ?? 'Unknown';
    final items = order['items'] as List<dynamic>? ?? [];
    final statusLower = status.toLowerCase();
    final canCancel = statusLower == 'pending';
    final isCancelled = statusLower == 'cancelled';
    final isPreparing = statusLower == 'preparing' || statusLower == 'confirmed';

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
        const SizedBox(height: 24),
        // Dynamic cancellation button
        if (!isCancelled) _CancelButton(
          canCancel: canCancel,
          isPreparing: isPreparing,
          orderId: orderId,
        ),
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

/// Dynamic cancellation button that adapts based on the order status.
///
/// - **Pending**: Active cancel button → instant 100% refund
/// - **Preparing/Confirmed**: Greyed out → shows toast explaining why
/// - **Other active**: Hidden
class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({
    required this.canCancel,
    required this.isPreparing,
    required this.orderId,
  });

  final bool canCancel;
  final bool isPreparing;
  final String orderId;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _cancelling = false;

  Future<void> _cancelOrder() async {
    // Confirm before cancelling
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Your order is still pending. You\'ll receive a full refund to your original payment method within 5-7 business days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(foodApiProvider).cancelOrder(widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled. Full refund initiated.'),
            backgroundColor: AppTheme.emerald,
          ),
        );
        // Refresh the order detail
        ref.invalidate(foodOrderDetailProvider(widget.orderId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.canCancel) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _cancelling ? null : _cancelOrder,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.danger,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: _cancelling
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cancel_outlined),
          label: Text(_cancelling ? 'Cancelling...' : 'Cancel Order (Full Refund)'),
        ),
      );
    }

    if (widget.isPreparing) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'The kitchen has already started preparing your food. Cancellation is no longer possible.',
                ),
                backgroundColor: AppTheme.slate,
                duration: Duration(seconds: 4),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.slate,
            side: BorderSide(color: AppTheme.slate.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Cancellation Locked — Kitchen is Preparing'),
        ),
      );
    }

    return const SizedBox.shrink();
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
