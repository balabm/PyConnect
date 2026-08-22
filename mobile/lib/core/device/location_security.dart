import 'package:geolocator/geolocator.dart';

/// GPS spoofing detection for the Captain app.
///
/// Every `Position` update from `Geolocator` is checked against the
/// platform's mock-location flag. When a mocked position is detected:
///
/// 1. The GPS ping is dropped (never sent to the backend).
/// 2. The driver is forced offline.
/// 3. A permanent red warning screen is shown.
/// 4. The anomaly is logged to the backend for fraud/suspension review.
class LocationSecurity {
  LocationSecurity._();

  /// Checks whether a [Position] is from a mock-location source.
  /// On iOS and Android, `Position.isMocked` is set by the OS when the
  /// location is coming from a mock/fake GPS app rather than real hardware.
  static bool isMocked(Position position) {
    return position.isMocked;
  }
}
