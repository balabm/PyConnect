import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages background GPS tracking for the Driver app using a foreground service.
/// Sends location updates to the backend via SignalR every 3 seconds.
class BackgroundLocationService {
  BackgroundLocationService._();

  static final _instance = BackgroundLocationService._();
  static BackgroundLocationService get instance => _instance;

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Initialize the background service. Call once at app startup (driver flavor only).
  Future<void> initialize() async {
    if (kIsWeb) return;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'driver_location_tracking',
        initialNotificationTitle: 'PY Connect Captain',
        initialNotificationContent: 'Location tracking is active',
        foregroundServiceNotificationId: 8888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start tracking. Begins the foreground service and periodic GPS polling.
  Future<void> start() async {
    if (kIsWeb || _isRunning) return;
    _isRunning = true;

    final service = FlutterBackgroundService();
    await service.startService();
  }

  /// Stop tracking. Stops the foreground service.
  Future<void> stop() async {
    if (kIsWeb || !_isRunning) return;
    _isRunning = false;

    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    Timer? timer;

    service.on('stop').listen((event) {
      timer?.cancel();
      service.stopSelf();
    });

    timer = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );

        // Send location update via SignalR
        // The SignalR connection is managed by the app's main isolate.
        // We use the service instance to communicate back.
        service.invoke('locationUpdate', {
          'lat': position.latitude,
          'lng': position.longitude,
          'heading': position.heading,
        });
      } catch (_) {
        // Ignore GPS errors — keep the service alive
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }
}

/// Riverpod provider for the background location service.
final backgroundLocationServiceProvider =
    Provider<BackgroundLocationService>((ref) => BackgroundLocationService.instance);
