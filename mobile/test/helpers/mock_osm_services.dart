import 'package:latlong2/latlong.dart';

import 'package:pondyconnect/core/network/osm_geocoding_service.dart';
import 'package:pondyconnect/core/network/osrm_routing_service.dart';

/// Mock geocoding service that returns canned results without hitting the network.
class MockGeocodingService implements OsmGeocodingService {
  @override
  Future<List<GeocodingResult>> search(String query, {List<String>? countryCodes, int limit = 5}) async {
    return [
      GeocodingResult(
        displayName: '$query, Pondicherry, India',
        latitude: 11.9356,
        longitude: 79.8301,
      ),
      GeocodingResult(
        displayName: '$query, Chennai, India',
        latitude: 13.0827,
        longitude: 80.2707,
      ),
    ];
  }

  @override
  Future<GeocodingResult?> reverse(double lat, double lng) async {
    return GeocodingResult(
      displayName: 'Mock Address, Pondicherry, India',
      latitude: lat,
      longitude: lng,
    );
  }
}

/// Mock routing service that returns a canned route without hitting the network.
/// Computes a simple straight-line distance for fare calculations.
class MockRoutingService implements OsrmRoutingService {
  @override
  Future<RouteResult?> getRoute(LatLng start, LatLng end) async {
    // Simple distance approximation for tests
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    final distanceKm = (dLat * dLat + dLng * dLng) * 111; // rough km
    final durationMin = (distanceKm * 2).round().clamp(1, 60); // ~2 min/km

    return RouteResult(
      distanceKm: distanceKm.abs() < 0.1 ? 1.5 : distanceKm.abs(),
      durationMin: durationMin < 1 ? 4 : durationMin,
      points: [start, end],
    );
  }
}
