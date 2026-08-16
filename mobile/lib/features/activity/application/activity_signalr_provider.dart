import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// A unified real-time status update for any activity item (ride, food, etc.).
class ActivityStatusUpdate {
  ActivityStatusUpdate({
    required this.entityId,
    required this.entityType,
    required this.newStatus,
    this.payload,
  });

  /// The ID of the ride/order/booking that changed.
  final String entityId;

  /// 'ride', 'food', 'stay', or 'rental'.
  final String entityType;

  /// The new status string (e.g. 'accepted', 'completed', 'delivered').
  final String newStatus;

  /// The raw event payload from the hub (may contain additional fields).
  final Map<String, dynamic>? payload;
}

/// SignalR-based live status listener for the Activity Hub.
///
/// The backend currently exposes a RideHub (`/hubs/ride`) that broadcasts
/// ride lifecycle events (DriverAssigned, RideStarted, RideCompleted,
/// RideCancelled, etc.). There is **no** dedicated food-order hub and the
/// backend does not send `OrderStatusChanged` events for food orders —
/// food order detail screens should use periodic polling instead.
///
/// This provider:
/// 1. Connects to the RideHub.
/// 2. Joins a ride-specific group for the ride being tracked.
/// 3. Listens for all ride lifecycle events and normalises them into a
///    single [ActivityStatusUpdate] stream that the activity hub and ride
///    detail screens can subscribe to.
class ActivitySignalRProvider {
  ActivitySignalRProvider(this._ref);
  final Ref _ref;

  StreamController<ActivityStatusUpdate>? _controller;
  StreamSubscription? _driverAssignedSub;
  StreamSubscription? _rideStartedSub;
  StreamSubscription? _rideCompletedSub;
  StreamSubscription? _rideCancelledSub;
  StreamSubscription? _driverArrivedSub;

  /// Connect to the RideHub and begin listening for status events.
  Future<void> connect() async {
    if (_controller != null) return; // already connected

    _controller = StreamController<ActivityStatusUpdate>.broadcast();
    final hub = _ref.read(rideHubProvider);
    await hub.connect();

    // DriverAssigned → status 'accepted'
    _driverAssignedSub = hub.on('DriverAssigned').listen((args) {
      final rideId = _extractRideId(args);
      if (rideId == null) return;
      _controller?.add(ActivityStatusUpdate(
        entityId: rideId,
        entityType: 'ride',
        newStatus: 'accepted',
        payload: _extractPayload(args),
      ));
    });

    // DriverArrived → status 'arrivedatpickup'
    _driverArrivedSub = hub.on('DriverArrived').listen((args) {
      final rideId = _extractRideId(args);
      if (rideId == null) return;
      _controller?.add(ActivityStatusUpdate(
        entityId: rideId,
        entityType: 'ride',
        newStatus: 'arrivedatpickup',
        payload: _extractPayload(args),
      ));
    });

    // RideStarted → status 'inprogress'
    _rideStartedSub = hub.on('RideStarted').listen((args) {
      final rideId = _extractRideId(args);
      if (rideId == null) return;
      _controller?.add(ActivityStatusUpdate(
        entityId: rideId,
        entityType: 'ride',
        newStatus: 'inprogress',
        payload: _extractPayload(args),
      ));
    });

    // RideCompleted → status 'completed'
    _rideCompletedSub = hub.on('RideCompleted').listen((args) {
      final rideId = _extractRideId(args);
      if (rideId == null) return;
      _controller?.add(ActivityStatusUpdate(
        entityId: rideId,
        entityType: 'ride',
        newStatus: 'completed',
        payload: _extractPayload(args),
      ));
    });

    // RideCancelled → status 'cancelled'
    _rideCancelledSub = hub.on('RideCancelled').listen((args) {
      final rideId = _extractRideId(args);
      if (rideId == null) return;
      _controller?.add(ActivityStatusUpdate(
        entityId: rideId,
        entityType: 'ride',
        newStatus: 'cancelled',
        payload: _extractPayload(args),
      ));
    });
  }

  /// Join the ride-specific group so we receive updates for that ride.
  Future<void> joinRide(String rideId) async {
    final hub = _ref.read(rideHubProvider);
    await hub.connect();
    await hub.invoke('JoinRide', [rideId]);
  }

  /// Leave the ride group when no longer tracking.
  Future<void> leaveRide(String rideId) async {
    final hub = _ref.read(rideHubProvider);
    await hub.invoke('LeaveRide', [rideId]);
  }

  /// The unified stream of status updates. Screens call [connect] first,
  /// then listen to this stream.
  Stream<ActivityStatusUpdate> get statusUpdateStream =>
      _controller?.stream ?? const Stream.empty();

  /// Disconnect and clean up all subscriptions.
  Future<void> disconnect() async {
    await _driverAssignedSub?.cancel();
    await _driverArrivedSub?.cancel();
    await _rideStartedSub?.cancel();
    await _rideCompletedSub?.cancel();
    await _rideCancelledSub?.cancel();
    _driverAssignedSub = null;
    _driverArrivedSub = null;
    _rideStartedSub = null;
    _rideCompletedSub = null;
    _rideCancelledSub = null;
    await _controller?.close();
    _controller = null;
    await _ref.read(rideHubProvider).disconnect();
  }

  /// Attempts to extract the ride ID from a SignalR event payload.
  /// The backend typically sends the ride ID as the first argument or
  /// inside a payload object with a 'rideId' key.
  String? _extractRideId(List<Object?> args) {
    if (args.isEmpty) return null;
    final first = args.first;
    if (first is String) return first;
    if (first is Map<String, dynamic>) {
      return first['rideId'] as String? ?? first['id'] as String?;
    }
    return null;
  }

  /// Extracts the full payload map if the event argument is a JSON object.
  Map<String, dynamic>? _extractPayload(List<Object?> args) {
    if (args.isEmpty) return null;
    final first = args.first;
    if (first is Map<String, dynamic>) return first;
    return null;
  }
}

/// Provider for the activity SignalR connection.
final activitySignalRProvider = Provider<ActivitySignalRProvider>((ref) {
  return ActivitySignalRProvider(ref);
});
