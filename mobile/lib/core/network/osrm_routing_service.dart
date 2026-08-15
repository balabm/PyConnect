import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// OSRM routing service. Calculates road distance, duration, and
/// route polyline between two points. Uses the public OSRM demo server.
/// For production, self-host an OSRM instance with India OSM data.
class OsrmRoutingService {
  OsrmRoutingService();

  // OSRM public demo server. For production, replace with self-hosted instance.
  static const _baseUrl = 'https://router.project-osrm.org';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  /// Get route between two points. Returns road distance (km),
  /// duration (min), and decoded polyline points for map display.
  Future<RouteResult?> getRoute(LatLng start, LatLng end) async {
    try {
      final coords = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
      final response = await _dio.get('/route/v1/driving/$coords', queryParameters: {
        'overview': 'full',
        'geometries': 'polyline6',
        'steps': 'false',
      });

      final data = response.data as Map<String, dynamic>;
      final routes = data['routes'] as List;
      if (routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final distance = (route['distance'] as num).toDouble(); // meters
      final duration = (route['duration'] as num).toDouble(); // seconds
      final geometry = route['geometry'] as String;

      final points = _decodePolyline6(geometry);

      return RouteResult(
        distanceKm: distance / 1000.0,
        durationMin: (duration / 60.0).round(),
        points: points,
      );
    } catch (_) {
      return null;
    }
  }

  /// Decode OSRM polyline6 format (precision 6) into LatLng points.
  /// Algorithm: Google polyline format with 1e6 precision.
  List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e6, lng / 1e6));
    }

    return points;
  }
}

/// Route result with distance, duration, and polyline points.
class RouteResult {
  RouteResult({
    required this.distanceKm,
    required this.durationMin,
    required this.points,
  });

  final double distanceKm;
  final int durationMin;
  final List<LatLng> points;
}
