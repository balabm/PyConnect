import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// OSM Nominatim geocoding service. Converts addresses to coordinates
/// and coordinates to addresses. Uses the free Nominatim API.
/// Rate limited to 1 req/sec — suitable for user-initiated searches.
class OsmGeocodingService {
  OsmGeocodingService();

  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'PondyConnect/1.0 (ride-hailing app)',
    },
  ));

  /// Search for addresses by query string. Returns ranked results.
  /// Optional [countryCodes] limits results (e.g. ['in'] for India).
  Future<List<GeocodingResult>> search(String query, {List<String>? countryCodes, int limit = 5}) async {
    if (query.trim().length < 3) return [];

    try {
      final response = await _dio.get('/search', queryParameters: {
        'q': query,
        'format': 'json',
        'limit': limit,
        'addressdetails': 1,
        if (countryCodes != null) 'countrycodes': countryCodes.join(','),
      });

      final results = response.data as List;
      return results.map((e) => GeocodingResult.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocode: convert coordinates to an address.
  Future<GeocodingResult?> reverse(double lat, double lng) async {
    try {
      final response = await _dio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'json',
        'addressdetails': 1,
      });

      if (response.data is Map<String, dynamic>) {
        return GeocodingResult.fromReverseJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}

/// A geocoding result with coordinates and display address.
class GeocodingResult {
  GeocodingResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.type,
    this.address,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final int? placeId;
  final String? type;
  final Map<String, dynamic>? address;

  LatLng get location => LatLng(latitude, longitude);

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      displayName: json['display_name'] as String? ?? '',
      latitude: double.parse(json['lat'].toString()),
      longitude: double.parse(json['lon'].toString()),
      placeId: json['place_id'] as int?,
      type: json['type'] as String?,
      address: json['address'] as Map<String, dynamic>?,
    );
  }

  factory GeocodingResult.fromReverseJson(Map<String, dynamic> json) {
    return GeocodingResult(
      displayName: json['display_name'] as String? ?? '',
      latitude: double.parse(json['lat'].toString()),
      longitude: double.parse(json['lon'].toString()),
      placeId: json['place_id'] as int?,
      type: json['type'] as String?,
      address: json['address'] as Map<String, dynamic>?,
    );
  }
}
