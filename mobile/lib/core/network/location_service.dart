import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../features/location/presentation/location_permission_interceptor.dart';

/// Service for fetching the device's current GPS location.
/// Handles permission requests and falls back gracefully on web.
///
/// Before calling the system-level location permission prompt, a full-screen
/// custom UI interceptor is shown with human-readable justification, as
/// required by Apple App Store and Google Play Protect policies.
class LocationService {
  /// Fetches the current location. If [context] is provided and permission
  /// has not been granted, shows the custom permission interceptor UI
  /// before requesting the system permission.
  Future<LatLng?> getCurrentLocation({BuildContext? context, bool isDriver = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();

      // If permission is denied, show the interceptor UI before requesting
      // the system permission (if a context is available).
      if (permission == LocationPermission.denied && context != null) {
        final granted = await LocationPermissionInterceptor.showAndRequest(
          context,
          isDriver: isDriver,
        );
        if (!granted) return null;
        permission = await Geolocator.checkPermission();
      } else if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
