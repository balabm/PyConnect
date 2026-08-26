import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Real-time food order update events received via SignalR VendorHub.
/// The backend broadcasts "OrderUpdated" when a food order's status changes
/// (accepted, preparing, ready, out_for_delivery, delivered, cancelled).
class FoodOrderSignalRProvider {
  FoodOrderSignalRProvider(this._ref);
  final Ref _ref;

  bool _connected = false;

  /// Connect to the VendorHub to receive order update events.
  Future<void> connect() async {
    if (_connected) return;
    final hub = _ref.read(vendorStatusHubProvider);
    try {
      await hub.connect();
      _connected = true;
    } catch (_) {
      // Non-fatal — the food order detail screen falls back to polling.
    }
  }

  /// Stream of order status update events.
  /// Each event contains: { orderId, status, vendorId }
  Stream<List<Object?>> get orderUpdatedStream {
    connect();
    return _ref.read(vendorStatusHubProvider).on('OrderUpdated');
  }

  /// Stream of new order events (for vendor KDS).
  Stream<List<Object?>> get newOrderStream {
    connect();
    return _ref.read(vendorStatusHubProvider).on('NewOrder');
  }

  /// Disconnect from the hub.
  Future<void> disconnect() async {
    if (!_connected) return;
    _connected = false;
    await _ref.read(vendorStatusHubProvider).disconnect();
  }
}

final foodOrderSignalRProvider = Provider<FoodOrderSignalRProvider>((ref) {
  return FoodOrderSignalRProvider(ref);
});

/// Provider that exposes a broadcast stream of order IDs that have been
/// updated via SignalR. The food order detail screen listens to this and
/// refreshes its data when it sees its own order ID.
final foodOrderUpdateStreamProvider = StreamProvider<String>((ref) async* {
  final signalR = ref.read(foodOrderSignalRProvider);
  await signalR.connect();

  final controller = StreamController<String>.broadcast();
  final sub = signalR.orderUpdatedStream.listen((args) {
    if (args.isNotEmpty) {
      final data = args.first;
      if (data is Map) {
        final orderId = data['orderId']?.toString();
        if (orderId != null && orderId.isNotEmpty) {
          controller.add(orderId);
        }
      }
    }
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  yield* controller.stream;
});
