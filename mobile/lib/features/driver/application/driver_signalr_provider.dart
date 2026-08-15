import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/driver_models.dart';

/// Real-time driver hub provider for receiving ride offers and sending
/// location updates, accept/decline, arrive, OTP verification, complete.
class DriverSignalRProvider {
  DriverSignalRProvider(this._ref);
  final Ref _ref;

  /// Connect to DriverHub and join the driver channel for targeted offers.
  Future<void> connect(String driverId) async {
    final client = _ref.read(driverHubProvider);
    await client.connect();
    await client.invoke('JoinDriverGroup', []);
    await client.invoke('JoinDriverChannel', [driverId]);
  }

  /// Disconnect from DriverHub.
  Future<void> disconnect() async {
    final client = _ref.read(driverHubProvider);
    await client.disconnect();
  }

  /// Update driver location in real-time (called every 3-5 seconds while online).
  Future<void> updateLocation(double lat, double lng, {double? heading}) async {
    final client = _ref.read(driverHubProvider);
    await client.invoke('UpdateLocation', [lat, lng, heading]);
  }

  /// Stream of incoming ride offers.
  Stream<List<Object?>> get rideOfferStream => _ref.read(driverHubProvider).on('RideOffer');

  /// Stream of ride accepted notifications (when another driver wins).
  Stream<List<Object?>> get rideAcceptedStream => _ref.read(driverHubProvider).on('RideAccepted');

  /// Stream of food delivery pickup offers.
  Stream<List<Object?>> get foodDeliveryOfferStream => _ref.read(driverHubProvider).on('FoodDeliveryOffer');

  /// Stream of dispatch tasks mapped from SignalR ride offers.
  /// Falls back to empty stream if SignalR is not connected.
  Stream<List<DispatchTaskModel>> get dispatchTaskStream {
    final controller = StreamController<List<DispatchTaskModel>>.broadcast();

    final subscription = rideOfferStream.listen((args) {
      try {
        final arg = args.isNotEmpty ? args[0] : null;
        if (arg is Map<String, dynamic>) {
          final offer = RideOfferModel.fromJson(arg);
          final task = DispatchTaskModel(
            id: offer.rideId,
            taskType: 'Ride',
            pickupAddress: offer.pickupAddress,
            dropoffAddress: offer.dropoffAddress,
            driverEarnings: offer.driverEarnings,
            status: 'Available',
          );
          if (!controller.isClosed) controller.add([task]);
        }
      } catch (_) {
        // Ignore malformed payloads
      }
    });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Stream of food delivery dispatch tasks mapped from SignalR food offers.
  Stream<List<DispatchTaskModel>> get foodDeliveryTaskStream {
    final controller = StreamController<List<DispatchTaskModel>>.broadcast();

    final subscription = foodDeliveryOfferStream.listen((args) {
      try {
        final arg = args.isNotEmpty ? args[0] : null;
        if (arg is Map<String, dynamic>) {
          final offer = FoodDeliveryOfferModel.fromJson(arg);
          final task = DispatchTaskModel(
            id: offer.orderId,
            taskType: 'Food Delivery',
            pickupAddress: offer.pickupAddress,
            dropoffAddress: offer.deliveryAddress,
            driverEarnings: offer.driverEarnings,
            status: 'Available',
          );
          if (!controller.isClosed) controller.add([task]);
        }
      } catch (_) {}
    });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Accept a ride offer.
  Future<void> acceptRide(String rideId) async {
    final client = _ref.read(driverHubProvider);
    await client.invoke('AcceptRide', [rideId]);
  }

  /// Decline a ride offer.
  Future<void> declineRide(String rideId) async {
    final client = _ref.read(driverHubProvider);
    await client.invoke('DeclineRide', [rideId]);
  }

  /// Mark driver as arrived at pickup location.
  Future<void> arriveAtPickup(String rideId) async {
    final client = _ref.read(driverHubProvider);
    await client.invoke('ArriveAtPickup', [rideId]);
  }

  /// Verify OTP and start the ride.
  Future<void> verifyOtpAndStart(String rideId, String otp) async {
    final client = _ref.read(driverHubProvider);
    await client.invoke('VerifyOtpAndStart', [rideId, otp]);
  }

  /// Complete the ride.
  Future<void> completeRide(String rideId) async {
    final client = _ref.read(driverHubProvider);
    await client.invoke('CompleteRide', [rideId]);
  }
}

final driverSignalRProvider = Provider<DriverSignalRProvider>((ref) {
  return DriverSignalRProvider(ref);
});

/// Model for a ride offer received by the driver.
class RideOfferModel {
  RideOfferModel({
    required this.rideId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.fare,
    required this.driverEarnings,
    required this.paymentMethod,
    required this.vehicleType,
    required this.isSos,
    required this.surgeMultiplier,
    required this.surgeReason,
    required this.expiresIn,
  });

  final String rideId;
  final String pickupAddress;
  final String dropoffAddress;
  final double distanceKm;
  final double fare;
  final double driverEarnings;
  final String paymentMethod;
  final String vehicleType;
  final bool isSos;
  final double surgeMultiplier;
  final String? surgeReason;
  final int expiresIn;

  factory RideOfferModel.fromJson(Map<String, dynamic> json) {
    return RideOfferModel(
      rideId: json['rideId'] as String,
      pickupAddress: json['pickupAddress'] as String? ?? '',
      dropoffAddress: json['dropoffAddress'] as String? ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      driverEarnings: (json['driverEarnings'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
      vehicleType: json['vehicleType'] as String? ?? 'Bike',
      isSos: json['isSos'] as bool? ?? false,
      surgeMultiplier: (json['surgeMultiplier'] as num?)?.toDouble() ?? 1.0,
      surgeReason: json['surgeReason'] as String?,
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 15,
    );
  }
}

/// Model for a food delivery offer received by the driver.
class FoodDeliveryOfferModel {
  FoodDeliveryOfferModel({
    required this.orderId,
    required this.vendorName,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.deliveryFee,
    required this.lateNightDriverBonus,
    required this.totalAmount,
    required this.paymentMethod,
    required this.expiresIn,
  });

  final String orderId;
  final String vendorName;
  final String pickupAddress;
  final String deliveryAddress;
  final double deliveryFee;
  final double lateNightDriverBonus;
  final double totalAmount;
  final String paymentMethod;
  final int expiresIn;

  /// Total driver earnings = delivery fee + late night bonus
  double get driverEarnings => deliveryFee + lateNightDriverBonus;

  factory FoodDeliveryOfferModel.fromJson(Map<String, dynamic> json) {
    return FoodDeliveryOfferModel(
      orderId: json['orderId'] as String,
      vendorName: json['vendorName'] as String? ?? '',
      pickupAddress: json['pickupAddress'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
      lateNightDriverBonus: (json['lateNightDriverBonus'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 20,
    );
  }
}
