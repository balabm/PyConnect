import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/modern_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../domain/kds_models.dart';

/// Kitchen Display System screen — dark Kanban-style order board with
/// stage progression. Uses kdsApiProvider for authenticated API access.
class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<KdsOrder> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  int _previousOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadOrders());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await ref.read(kdsApiProvider).getOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
          _error = null;
        });

        // Play chime if new orders arrived
        if (orders.length > _previousOrderCount && _previousOrderCount > 0) {
          _playChime();
        }
        _previousOrderCount = orders.length;
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

  Future<void> _playChime() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (_) {}
  }

  Future<void> _advanceOrder(KdsOrder order) async {
    if (order.stage.next == null) return;
    AppHaptics.medium();
    try {
      await ref.read(kdsApiProvider).advanceStage(order.id);
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to advance order: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Color _urgencyColor(KdsUrgency urgency) => switch (urgency) {
        KdsUrgency.normal => AppTheme.success,
        KdsUrgency.warning => AppTheme.warning,
        KdsUrgency.critical => AppTheme.danger,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildBoard(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.coral),
          const SizedBox(height: 16),
          Text('Loading kitchen board...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildError() {
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
            Text(_error!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () {
                AppHaptics.light();
                setState(() => _loading = true);
                _loadOrders();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final activeOrders = _orders.where((o) => o.stage != KdsStage.completed).toList();

    if (activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.kitchen, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No active orders',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('New orders will appear here automatically',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
          ],
        ),
      );
    }

    final incoming = activeOrders.where((o) => o.stage == KdsStage.incoming).toList();
    final preparing = activeOrders.where((o) => o.stage == KdsStage.preparing).toList();
    final ready = activeOrders.where((o) => o.stage == KdsStage.ready).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: MediaQuery.of(context).size.width < 900
            ? MediaQuery.of(context).size.width
            : 900,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildColumn('Incoming', incoming, AppTheme.info)),
            const SizedBox(width: 8),
            Expanded(child: _buildColumn('Preparing', preparing, AppTheme.coral)),
            const SizedBox(width: 8),
            Expanded(child: _buildColumn('Ready', ready, AppTheme.success)),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(String title, List<KdsOrder> orders, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Row(
            children: [
              Container(
                width: 4, height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${orders.length}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...orders.map((order) => _buildOrderCard(order, accent)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(KdsOrder order, Color columnAccent) {
    final urgency = order.urgency;
    final urgencyColor = _urgencyColor(urgency);

    return BounceIn(
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: urgencyColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: () => _advanceOrder(order),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order number + elapsed time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.orderNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 12, color: urgencyColor),
                        const SizedBox(width: 4),
                        Text(
                          '${order.elapsedMinutes}m',
                          style: TextStyle(
                            color: urgencyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                order.customerName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              // Item pills
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: order.items.map((item) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.quantity}x ${item.name}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
              // Special instructions
              if (order.items.any((i) => i.specialInstructions != null)) ...[
                const SizedBox(height: 6),
                ...order.items.where((i) => i.specialInstructions != null).map((item) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '* ${item.specialInstructions}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.warning.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )),
              ],
              // Delivery address
              if (order.deliveryAddress != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.deliveryAddress!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Advance button
              if (order.stage.next != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: columnAccent.withValues(alpha: 0.15),
                      foregroundColor: columnAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => _advanceOrder(order),
                    child: Text('Advance to ${order.stage.next!.label}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
