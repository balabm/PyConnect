import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/modern_animations.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/vendor_auth_controller.dart';
import '../application/vendor_providers.dart';
import '../domain/kds_models.dart';
import '../services/thermal_printer_service.dart';
import 'quick_toggles_sheet.dart';

/// Kitchen Display System screen — dark Kanban-style order board with
/// stage progression. Uses kdsApiProvider for authenticated API access.
///
/// Audio/Visual alarm: when a new order arrives in the "Incoming" column,
/// a loud chime repeats every 3 seconds until the merchant physically taps
/// "Accept Order" (advances the order to "Preparing"). The incoming card
/// also flashes with a highlight border. If the audio asset is missing,
/// falls back to [SystemSound.play] with [SystemSoundType.alert].
class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<KdsOrder> _orders = [];
  bool _loading = true;
  bool _firstLoad = true;
  bool _isFetching = false; // Guard against duplicate concurrent API calls
  String? _error;
  Timer? _refreshTimer;
  int _previousOrderCount = 0;
  StreamSubscription<List<Object?>>? _newOrderSub;

  /// Whether the looping KDS alarm is currently playing. The audio player is
  /// configured in [initState] with [ReleaseMode.loop], so a single play
  /// call will keep the chime going until it is stopped.
  bool _isChimePlaying = false;

  /// Whether the bundled audio asset loaded successfully. Once a play call
  /// fails, we switch to [SystemSound.play] as a fallback and stop trying
  /// the asset to avoid repeated exceptions on every chime tick.
  bool _audioAssetFailed = false;

  /// Flash animation controller for highlighting incoming (new) order cards.
  late final AnimationController _flashController;

  /// Order IDs that have already been auto-printed (to avoid duplicates).
  final Set<String> _printedOrderIds = {};

  /// Order IDs currently being printed (for the "Printing..." indicator).
  final Set<String> _printingOrderIds = {};

  /// Order IDs whose printing failed (paper jam, out of paper, Bluetooth
  /// disconnect, etc.). These are shown in a prominent yellow banner at the
  /// top of the KDS with a manual [ Reprint ] button so the merchant can
  /// retry once the paper is fixed.
  final Set<String> _printerErrorOrderIds = {};

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(1.0);
    _loadOrders();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadOrders());
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSignalR());
  }

  Future<void> _initSignalR() async {
    final session = ref.read(vendorAuthControllerProvider).valueOrNull;
    final vendorId = session?.vendorId;
    if (vendorId == null || vendorId.isEmpty) return;

    final hub = ref.read(vendorStatusHubProvider);
    try {
      await hub.connect();
      await hub.invoke('JoinVendorChannel', [vendorId]);
    } catch (_) {
      // Connection can retry in the background.
    }

    _newOrderSub = hub.on('NewOrder').listen((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _newOrderSub?.cancel();
    _flashController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (_isFetching) return; // Prevent duplicate concurrent API calls
    _isFetching = true;
    setState(() => _loading = true);
    try {
      // Add an explicit timeout so the loading state never hangs indefinitely.
      final orders = await ref
          .read(kdsApiProvider)
          .getOrders()
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
          _error = null;
        });

        // On first load just record the baseline; on subsequent loads a count
        // increase means a brand-new order has arrived (via polling or SignalR).
        if (_firstLoad) {
          _firstLoad = false;
        } else if (orders.length > _previousOrderCount) {
          _startChime();
          // Auto-print newly arrived orders
          _autoPrintNewOrders(orders);
        }
        _previousOrderCount = orders.length;

        // If there are no longer any incoming orders, stop the chime.
        _syncChime();
      }
    } on Exception catch (e) {
      if (mounted) {
        // Show the real error. No mock data — the kitchen staff needs to
        // know the backend is unreachable, not be misled by fake orders.
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  /// Returns the list of orders still in the "Incoming" stage (not yet
  /// accepted by the merchant).
  List<KdsOrder> get _incomingOrders =>
      _orders.where((o) => o.stage == KdsStage.incoming).toList();

  /// Starts the looping alarm when there are unaccepted incoming orders.
  /// [AudioPlayer] is already configured to [ReleaseMode.loop] in [initState],
  /// so one play call keeps ringing continuously.
  void _startChime() {
    if (_incomingOrders.isEmpty || _isChimePlaying) return;
    _playChime();
  }

  /// Stops the looping alarm. Safe to call even if it is not playing.
  void _stopChime() {
    if (!_isChimePlaying) return;
    _isChimePlaying = false;
    unawaited(_audioPlayer.stop());
  }

  /// Ensures the alarm state matches the presence of incoming orders.
  void _syncChime() {
    if (_incomingOrders.isEmpty) {
      _stopChime();
    } else if (!_isChimePlaying) {
      _startChime();
    }
  }

  /// Plays the order chime in a loop. [AudioPlayer] is already set to
  /// [ReleaseMode.loop], so it will repeat until [_stopChime] is called.
  /// Uses the bundled audio asset (`assets/sounds/order_chime.mp3`); if the
  /// asset is missing or playback fails, falls back to [SystemSound.play].
  Future<void> _playChime() async {
    _isChimePlaying = true;
    if (_audioAssetFailed) {
      _isChimePlaying = false;
      await SystemSound.play(SystemSoundType.alert);
      return;
    }
    try {
      await _audioPlayer.play(AssetSource('sounds/order_chime.mp3'));
    } catch (_) {
      _audioAssetFailed = true;
      _isChimePlaying = false;
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        AppHaptics.heavy();
      }
    }
  }

  /// Auto-prints tickets for orders that have not been printed yet.
  /// Called when new orders are detected during polling.
  void _autoPrintNewOrders(List<KdsOrder> orders) {
    for (final order in orders) {
      if (!_printedOrderIds.contains(order.id)) {
        _printOrder(order);
      }
    }
  }

  /// Converts a [KdsOrder] into an [OrderTicket] for the thermal printer.
  OrderTicket _buildOrderTicket(KdsOrder order) {
    return OrderTicket(
      orderId: order.orderNumber.isNotEmpty ? order.orderNumber : order.id,
      customerName: order.customerName,
      items: order.items
          .map((item) => OrderTicketItem(
                name: item.name,
                quantity: item.quantity,
                modifiers: item.specialInstructions != null &&
                        item.specialInstructions!.isNotEmpty
                    ? [item.specialInstructions!]
                    : [],
              ))
          .toList(),
      total: 0, // KDS model does not carry the total; footer still prints.
      paymentType: TicketPaymentType
          .paid, // Default to paid; KDS doesn't expose payment type.
      timestamp: order.placedAt,
    );
  }

  /// Prints [order] to the connected thermal printer. Shows a "Printing..."
  /// indicator on the card while in progress and a SnackBar with retry on
  /// failure.
  Future<void> _printOrder(KdsOrder order) async {
    if (_printingOrderIds.contains(order.id)) return;

    setState(() => _printingOrderIds.add(order.id));

    try {
      final service = ref.read(thermalPrinterProvider);
      final ticket = _buildOrderTicket(order);
      final success = await service.printOrderTicket(ticket);

      if (success) {
        _printedOrderIds.add(order.id);
        // Clear any previous printer error for this order on success.
        if (mounted) setState(() => _printerErrorOrderIds.remove(order.id));
      } else if (mounted) {
        // Mark this order as having a printer error so the yellow banner
        // appears at the top of the KDS with a manual reprint button.
        setState(() => _printerErrorOrderIds.add(order.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed for order #${order.orderNumber}'),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _printOrder(order),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Mark this order as having a printer error so the yellow banner
        // appears at the top of the KDS with a manual reprint button.
        setState(() => _printerErrorOrderIds.add(order.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _printOrder(order),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _printingOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _advanceOrder(KdsOrder order) async {
    if (order.stage.next == null) return;
    AppHaptics.medium();
    // Accepting an incoming order stops the alarm for that order. The
    // [_syncChime] call after reload will stop the loop entirely once no
    // incoming orders remain.
    if (order.stage == KdsStage.incoming) {
      _stopChime();
    }
    try {
      await ref.read(kdsApiProvider).advanceStage(order.id);
      _loadOrders();
    } catch (e) {
      // Alarm may still be needed if the advance failed — re-sync.
      _syncChime();
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

  /// Reject an incoming order by cancelling it. This also stops the alarm.
  Future<void> _rejectOrder(KdsOrder order) async {
    if (order.stage != KdsStage.incoming) return;
    AppHaptics.heavy();
    _stopChime();
    try {
      await ref.read(vendorDashboardApiProvider).updateOrderStatus(order.id, 'Cancelled');
      _loadOrders();
    } catch (e) {
      _syncChime();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject order: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  /// Partial fulfillment: marks a single item unavailable on an active order
  /// and issues a partial refund to the customer. Triggered by tapping an
  /// item pill on a KDS order card.
  Future<void> _markItemUnavailable(KdsOrder order, KdsOrderItem item) async {
    if (item.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This item cannot be refunded (missing item ID).'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
      return;
    }
    AppHaptics.heavy();
    final refundAmount = item.price * item.quantity;
    final confirmed = await _showRefundBottomSheet(item, refundAmount);
    if (confirmed != true) return;

    try {
      final result = await ref
          .read(vendorDashboardApiProvider)
          .partialRefund(order.id, item.id);
      if (mounted) {
        final returnedAmount = (result['RefundAmount'] as num?)?.toDouble() ??
            (result['refundAmount'] as num?)?.toDouble() ??
            refundAmount;
        final amountStr = '\u20B9${returnedAmount.toStringAsFixed(0)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund of $amountStr issued.'),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  /// Shows a red-themed bottom sheet to confirm marking an item unavailable.
  Future<bool?> _showRefundBottomSheet(KdsOrderItem item, double refundAmount) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark Unavailable & Refund?',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will refund \u20B9${refundAmount.toStringAsFixed(0)} to the customer for ${item.name} and remove it from the order.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Confirm Refund'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _urgencyColor(KdsUrgency urgency) => switch (urgency) {
        KdsUrgency.normal => AppTheme.success,
        KdsUrgency.warning => AppTheme.warning,
        KdsUrgency.critical => AppTheme.danger,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
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
          const CircularProgressIndicator(color: AppTheme.emerald),
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
              style: FilledButton.styleFrom(),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
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

  /// Marks a "preparing" order as ready via the status endpoint and reloads
  /// the board. Called when a card is dropped on the Ready column.
  Future<void> _setOrderReady(KdsOrder order) async {
    if (order.stage != KdsStage.preparing) return;
    try {
      await ref.read(vendorDashboardApiProvider).updateOrderStatus(order.id, 'Ready');
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark ready: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Widget _buildBoard() {
    final activeOrders = _orders.where((o) => o.stage != KdsStage.completed).toList();

    // Build the printer error banner if there are any failed prints.
    // This is a prominent yellow banner at the top of the KDS so the
    // merchant knows to fix the paper jam and reprint.
    final printerErrorBanner = _printerErrorOrderIds.isNotEmpty
        ? _buildPrinterErrorBanner()
        : const SizedBox.shrink();

    // Quick-toggles gear button in the top-right corner.
    final quickTogglesBtn = Positioned(
      top: 8, right: 8,
      child: IconButton(
        icon: Icon(Icons.tune, color: Colors.white.withValues(alpha: 0.6)),
        onPressed: () {
          AppHaptics.light();
          showQuickTogglesSheet(context, ref);
        },
        tooltip: 'Quick Toggles',
      ),
    );

    if (activeOrders.isEmpty) {
      // No active orders — ensure any lingering chime is stopped.
      _stopChime();
      return Stack(
        children: [
          Column(
            children: [
              printerErrorBanner,
              Expanded(
                child: Center(
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
                ),
              ),
            ],
          ),
          quickTogglesBtn,
        ],
      );
    }

    final incoming = activeOrders.where((o) => o.stage == KdsStage.incoming).toList();
    final preparing = activeOrders.where((o) => o.stage == KdsStage.preparing).toList();
    final ready = activeOrders.where((o) => o.stage == KdsStage.ready).toList();

    return Stack(
      children: [
        Column(
          children: [
            printerErrorBanner,
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width < 900
                      ? MediaQuery.of(context).size.width
                      : 900,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildColumn('New', incoming, AppTheme.info)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildColumn('Preparing', preparing, AppTheme.emerald)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildColumn('Ready / Waiting for Driver', ready, AppTheme.success, isDropTarget: true)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        quickTogglesBtn,
      ],
    );
  }

  /// Builds the prominent yellow printer error banner shown at the top of
  /// the KDS when one or more orders failed to print (paper jam, out of
  /// paper, Bluetooth disconnect, etc.). Each failed order has a
  /// [ Reprint ] button so the merchant can retry once the paper is fixed.
  Widget _buildPrinterErrorBanner() {
    final failedOrders = _orders.where((o) => _printerErrorOrderIds.contains(o.id)).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.warning,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.print_disabled, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Printer Error: ${failedOrders.length} order(s) could not be printed. Please check paper.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: failedOrders.map((order) {
                return ActionChip(
                  label: Text(
                    'Reprint #${order.orderNumber}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  avatar: Icon(Icons.print, size: 16, color: Colors.white),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  onPressed: () => _printOrder(order),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(String title, List<KdsOrder> orders, Color accent, {bool isDropTarget = false}) {
    final column = Container(
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

    if (!isDropTarget) return column;

    return DragTarget<KdsOrder>(
      onWillAccept: (order) => order != null && order.stage == KdsStage.preparing,
      onAccept: (order) {
        if (order != null) _setOrderReady(order);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHighlighted ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: column,
        );
      },
    );
  }

  Widget _buildOrderCard(KdsOrder order, Color columnAccent) {
    final urgency = order.urgency;
    final urgencyColor = _urgencyColor(urgency);
    final isIncoming = order.stage == KdsStage.incoming;

    // Visual alarm: incoming (new) orders flash with a pulsing highlight
    // border while unaccepted. Accepted/preparing/ready orders use the
    // steady urgency-colored border as before.
    final borderWidget = isIncoming
        ? AnimatedBuilder(
            animation: _flashController,
            builder: (context, child) {
              final t = _flashController.value;
              final flashColor = Color.lerp(
                AppTheme.warning.withValues(alpha: 0.3),
                AppTheme.warning,
                t,
              )!;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: flashColor, width: 2 + t),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warning.withValues(alpha: 0.3 * t),
                      blurRadius: 12 * t,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: _buildOrderCardContent(order, columnAccent, urgencyColor),
          )
        : Container(
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
            child: _buildOrderCardContent(order, columnAccent, urgencyColor),
          );

    final card = BounceIn(
      duration: const Duration(milliseconds: 300),
      child: borderWidget,
    );

    if (order.stage == KdsStage.preparing) {
      return Draggable<KdsOrder>(
        data: order,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: borderWidget,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: borderWidget,
        ),
        child: card,
      );
    }

    return card;
  }

  /// Builds the inner content of an order card (shared by the flashing and
  /// non-flashing variants).
  Widget _buildOrderCardContent(KdsOrder order, Color columnAccent, Color urgencyColor) {
    return InkWell(
      onTap: order.stage == KdsStage.incoming ? null : () => _advanceOrder(order),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order number + elapsed time + print button
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Manual reprint button
                  if (_printingOrderIds.contains(order.id))
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.info,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => _printOrder(order),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.print,
                          size: 14,
                          color: AppTheme.info,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
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
            ],
          ),
          // "Printing..." indicator
          if (_printingOrderIds.contains(order.id)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.print, size: 12, color: AppTheme.info.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  'Printing...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.info.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            order.customerName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          // Item pills — tap to mark an item unavailable (partial refund)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: order.items.map((item) => GestureDetector(
              onTap: () => _markItemUnavailable(order, item),
              child: Container(
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
          // Action buttons
          if (order.stage == KdsStage.incoming)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _rejectOrder(order),
                  child: Text('Reject'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: columnAccent.withValues(alpha: 0.15),
                    foregroundColor: columnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _advanceOrder(order),
                  child: Text('Accept Order'),
                ),
              ],
            )
          else if (order.stage.next != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Reprint button
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.info,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    iconSize: 14,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: _printingOrderIds.contains(order.id)
                      ? null
                      : () => _printOrder(order),
                  icon: Icon(Icons.print),
                  label: Text('Reprint'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: columnAccent.withValues(alpha: 0.15),
                    foregroundColor: columnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _advanceOrder(order),
                  child: Text('Advance to ${order.stage.next!.label}'),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.info,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  iconSize: 14,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: _printingOrderIds.contains(order.id)
                    ? null
                    : () => _printOrder(order),
                icon: Icon(Icons.print),
                label: Text('Reprint'),
              ),
            ),
        ],
      ),
    );
  }
}
