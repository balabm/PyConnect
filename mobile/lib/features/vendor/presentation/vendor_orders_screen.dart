import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.read(vendorOrdersProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(vendorOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Live Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              ref.read(vendorOrdersProvider.notifier).load();
            },
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e.toString()),
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmpty();
          }
          final active = orders.where((o) =>
              o.status != 'Delivered' && o.status != 'Cancelled').toList();
          final completed = orders.where((o) =>
              o.status == 'Delivered' || o.status == 'Cancelled').toList();

          return CustomScrollView(
            slivers: [
              if (active.isNotEmpty) ...[
                SliverToBoxAdapter(child: _buildSectionHeader('Active Orders', active.length)),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (context, i) => _OrderCard(
                    order: active[i],
                    onAdvance: (status) => _advanceOrder(active[i], status),
                  ),
                  childCount: active.length,
                )),
              ],
              if (completed.isNotEmpty) ...[
                SliverToBoxAdapter(child: _buildSectionHeader('Completed', completed.length)),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (context, i) => _CompletedOrderCard(order: completed[i]),
                  childCount: completed.length,
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.coral.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppTheme.coral,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.coral),
          const SizedBox(height: 16),
          Text('Loading orders...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Could not load orders',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18)),
            const SizedBox(height: 8),
            Text(error,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () => ref.read(vendorOrdersProvider.notifier).load(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No orders yet',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('New food delivery orders will appear here',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _advanceOrder(VendorOrderModel order, String newStatus) async {
    AppHaptics.medium();
    try {
      await ref.read(vendorOrdersProvider.notifier).updateStatus(order.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order moved to ${_statusLabel(newStatus)}'),
            backgroundColor: AppTheme.lagoon,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.coral,
          ),
        );
      }
    }
  }

  String _statusLabel(String status) {
    return switch (status) {
      'Accepted' => 'Accepted',
      'Preparing' => 'Preparing',
      'OutForDelivery' => 'Out for Delivery',
      'Delivered' => 'Delivered',
      'Cancelled' => 'Cancelled',
      _ => status,
    };
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onAdvance});
  final VendorOrderModel order;
  final void Function(String status) onAdvance;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final nextAction = _nextAction(order.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.id.substring(0, 8)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\u20B9${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.lagoon,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (order.placedAt.isNotEmpty)
                Text(
                  _formatTime(order.placedAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (nextAction != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: nextAction.color.withValues(alpha: 0.15),
                      foregroundColor: nextAction.color,
                    ),
                    icon: Icon(nextAction.icon),
                    label: Text(nextAction.label),
                    onPressed: () => onAdvance(nextAction.status),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => onAdvance('Cancelled'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.coral),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'Pending' => 'Pending',
        'Accepted' => 'Accepted',
        'Preparing' => 'Preparing',
        'OutForDelivery' => 'Out for Delivery',
        'Delivered' => 'Delivered',
        'Cancelled' => 'Cancelled',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'Pending' => AppTheme.warning,
        'Accepted' => AppTheme.info,
        'Preparing' => AppTheme.coral,
        'OutForDelivery' => AppTheme.lagoon,
        'Delivered' => AppTheme.success,
        'Cancelled' => AppTheme.danger,
        _ => Colors.white.withValues(alpha: 0.5),
      };

  _NextAction? _nextAction(String status) => switch (status) {
        'Pending' => _NextAction('Accept Order', 'Accepted', Icons.check, AppTheme.info),
        'Accepted' => _NextAction('Start Preparing', 'Preparing', Icons.kitchen, AppTheme.coral),
        'Preparing' => _NextAction('Send Out for Delivery', 'OutForDelivery', Icons.delivery_dining, AppTheme.lagoon),
        'OutForDelivery' => _NextAction('Mark Delivered', 'Delivered', Icons.check_circle, AppTheme.success),
        _ => null,
      };

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _CompletedOrderCard extends StatelessWidget {
  const _CompletedOrderCard({required this.order});
  final VendorOrderModel order;

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.status == 'Delivered';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isDelivered ? Icons.check_circle : Icons.cancel,
            color: isDelivered ? AppTheme.success : AppTheme.danger,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '#${order.id.substring(0, 8)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '\u20B9${order.totalAmount.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextAction {
  final String label;
  final String status;
  final IconData icon;
  final Color color;
  _NextAction(this.label, this.status, this.icon, this.color);
}
