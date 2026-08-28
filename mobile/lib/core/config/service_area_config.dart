import 'package:latlong2/latlong.dart';

/// Centralized service-area configuration for Pondicherry.
///
/// All hardcoded Pondicherry coordinates across the app should reference
/// these constants instead of duplicating literal lat/lng values in
/// individual screens. This makes it easy to adjust the service area
/// or add new areas in one place.
class ServiceAreaConfig {
  const ServiceAreaConfig._();

  /// Pondicherry city center (White Town area).
  /// Used as the default map center, geocoding bias, and fallback location.
  static const LatLng defaultCenter = LatLng(11.9356, 79.8301);

  /// Service-area bounds for map framing and admin views.
  static const LatLng southWestBound = LatLng(11.88, 79.78);
  static const LatLng northEastBound = LatLng(11.99, 79.88);

  /// Known areas within the service area, used by driver preferences
  /// and location pickers. Coordinates are approximate centers.
  static const Map<String, LatLng> knownAreas = {
    'City Center': LatLng(11.9356, 79.8301),
    'White Town': LatLng(11.9310, 79.8350),
    'Rock Beach': LatLng(11.9380, 79.8450),
    'Auroville': LatLng(11.9620, 79.8330),
    'Lawspet': LatLng(11.9410, 79.8080),
    'Oulgaret': LatLng(11.9490, 79.8030),
  };

  /// Default pickup fallback (city center).
  static const LatLng defaultPickup = defaultCenter;

  /// Default dropoff fallback (nearby point used in tracking/route demos).
  static const LatLng defaultDropoff = LatLng(11.9370, 79.8338);

  /// Service-area radius in kilometers.
  static const double radiusKm = 50.0;
}
