import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// A nearby driver resolved from the backend `/api/rides/nearby-drivers`
/// endpoint. Carries the geographic coordinates required to render the driver
/// as a map marker, plus the vehicle type used to pick the correct icon and
/// the driver id used to key the animated marker so movement glides smoothly
/// between polling refreshes instead of teleporting.
class NearbyDriver {
  NearbyDriver({
    required this.id,
    required this.name,
    required this.vehicleType,
    required this.location,
    this.distanceKm,
    this.rating,
    this.totalRides,
  });

  final String id;
  final String name;
  final String vehicleType;
  final LatLng location;
  final double? distanceKm;
  final double? rating;
  final int? totalRides;

  /// Material icon used for the map marker and list card.
  IconData get icon => NearbyDriver.iconFor(vehicleType);

  /// Resolves a vehicle-type string (e.g. "Bike", "Auto", "Car") to a Material
  /// icon. Falls back to a generic directions icon for unknown types.
  static IconData iconFor(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.local_taxi;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.directions;
    }
  }

  /// Parses a single driver entry from the backend JSON response.
  static NearbyDriver? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final lat = (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble();
    if (id == null || lat == null || lng == null) return null;
    return NearbyDriver(
      id: id,
      name: json['name'] as String? ?? 'Driver',
      vehicleType: json['vehicleType'] as String? ?? 'Bike',
      location: LatLng(lat, lng),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      totalRides: (json['totalRides'] as num?)?.toInt(),
    );
  }

  /// Parses a list of driver entries, dropping any that lack coordinates.
  static List<NearbyDriver> fromJsonList(List<dynamic> list) {
    return list
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .whereType<NearbyDriver>()
        .toList();
  }
}
