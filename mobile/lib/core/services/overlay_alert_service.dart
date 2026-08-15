import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages high-priority full-screen overlay alerts for the Driver app.
/// Shows an incoming-call-style ringing notification when a ride/delivery offer arrives.
class OverlayAlertService {
  OverlayAlertService._();

  static final _instance = OverlayAlertService._();
  static OverlayAlertService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const _channelId = 'ride_offers';
  static const _channelName = 'Ride Offers';
  static const _notificationId = 9999;

  /// Initialize notification channels. Call once at app startup (driver flavor only).
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid || _initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create high-importance channel for ride offers
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Incoming ride and delivery offers',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Show a full-screen ringing alert for an incoming ride offer.
  Future<void> showRideOfferAlert({
    required String title,
    required String body,
    required String rideId,
    String? payload,
  }) async {
    if (kIsWeb || !Platform.isAndroid || !_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      actions: [
        AndroidNotificationAction('accept', 'Accept', showsUserInterface: true),
        AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
      ],
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      title,
      body,
      notificationDetails,
      payload: payload ?? rideId,
    );
  }

  /// Cancel the ringing alert (e.g., after driver accepts or declines).
  Future<void> cancelAlert() async {
    if (kIsWeb || !_initialized) return;
    await _notifications.cancel(_notificationId);
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification action (accept/decline) — the app's main isolate
    // will receive this and route accordingly.
    final actionId = response.actionId;
    final payload = response.payload;

    // Emit via a stream that the app can listen to
    _actionController.add(OverlayAlertAction(
      actionId: actionId,
      payload: payload,
    ));
  }

  final _actionController = StreamController<OverlayAlertAction>.broadcast();
  Stream<OverlayAlertAction> get onAction => _actionController.stream;
}

/// Represents a user action on an overlay alert notification.
class OverlayAlertAction {
  final String? actionId;
  final String? payload;

  OverlayAlertAction({this.actionId, this.payload});

  bool get isAccept => actionId == 'accept';
  bool get isDecline => actionId == 'decline';
}

/// Riverpod provider for the overlay alert service.
final overlayAlertServiceProvider =
    Provider<OverlayAlertService>((ref) => OverlayAlertService.instance);
