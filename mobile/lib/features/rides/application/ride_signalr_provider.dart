import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Real-time ride update events received via SignalR RideHub.
class RideSignalRProvider {
  RideSignalRProvider(this._ref);
  final Ref _ref;

  /// Connect to RideHub and join a ride-specific group for updates.
  Future<void> joinRide(String rideId) async {
    final client = _ref.read(rideHubProvider);
    await client.connect();
    await client.invoke('JoinRide', [rideId]);
  }

  /// Leave the ride group and disconnect.
  Future<void> leaveRide(String rideId) async {
    final client = _ref.read(rideHubProvider);
    await client.invoke('LeaveRide', [rideId]);
    await client.disconnect();
  }

  /// Stream of driver assigned events.
  Stream<List<Object?>> get driverAssignedStream => _ref.read(rideHubProvider).on('DriverAssigned');

  /// Stream of driver location updates for live tracking.
  Stream<List<Object?>> get driverLocationUpdateStream => _ref.read(rideHubProvider).on('DriverLocationUpdate');

  /// Stream of driver arrived events.
  Stream<List<Object?>> get driverArrivedStream => _ref.read(rideHubProvider).on('DriverArrived');

  /// Stream of ride started events.
  Stream<List<Object?>> get rideStartedStream => _ref.read(rideHubProvider).on('RideStarted');

  /// Stream of ride completed events.
  Stream<List<Object?>> get rideCompletedStream => _ref.read(rideHubProvider).on('RideCompleted');

  /// Stream of ride cancelled events.
  Stream<List<Object?>> get rideCancelledStream => _ref.read(rideHubProvider).on('RideCancelled');

  /// Stream of SOS alert events.
  Stream<List<Object?>> get sosAlertStream => _ref.read(rideHubProvider).on('SosAlert');
}

/// Provider for the ride SignalR connection.
final rideSignalRProvider = Provider<RideSignalRProvider>((ref) {
  return RideSignalRProvider(ref);
});

/// State notifier that tracks the live driver location for a ride.
final liveDriverLocationProvider = StateProvider<DriverLocationUpdate?>((ref) => null);

class DriverLocationUpdate {
  DriverLocationUpdate({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.distanceToPickupKm,
    this.etaToPickupMin,
  });

  final double latitude;
  final double longitude;
  final double? heading;
  final double? distanceToPickupKm;
  final int? etaToPickupMin;
}
