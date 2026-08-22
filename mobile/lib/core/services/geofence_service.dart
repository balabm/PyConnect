import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// A utility service for geofence proximity detection.
///
/// Used by the Captain app to automatically detect when the driver
/// arrives at the pickup or drop-off location (within a configurable
/// radius, default 50 meters), and unlock the next state without
/// requiring a manual button tap.
class GeofenceService {
  GeofenceService._();

  /// Default geofence radius in meters for arrival detection.
  static const double defaultArrivalRadius = 50.0;

  /// Calculates the distance between two coordinates in meters
  /// using the Haversine formula.
  static double distanceBetween(LatLng a, LatLng b) {
    const r = 6371000.0; // Earth radius in meters
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return r * c;
  }

  /// Returns true if [driverPosition] is within [radius] meters of
  /// [targetPosition].
  static bool isWithinGeofence(
    LatLng driverPosition,
    LatLng targetPosition, {
    double radius = defaultArrivalRadius,
  }) {
    return distanceBetween(driverPosition, targetPosition) <= radius;
  }

  /// Returns the distance in meters as a user-friendly string.
  /// e.g., "50 m", "1.2 km"
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
