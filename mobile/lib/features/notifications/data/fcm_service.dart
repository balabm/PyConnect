import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler. Must be a top-level function and
/// annotated with `@pragma('vm:entry-point')` so the Dart compiler keeps it
/// alive for background isolate execution.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _showLocalNotificationFromPayload(message);
}

const String _kRideOffersChannelId = 'ride_offers';
const String _kNewOrdersChannelId = 'new_orders';
const String _kGeneralChannelId = 'general_notifications';

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await _localNotificationsPlugin.initialize(settings);

  // Create high-priority channels for Android
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kRideOffersChannelId,
          'Ride Offers',
          description: 'High-priority alerts for incoming ride requests',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kNewOrdersChannelId,
          'New Orders',
          description: 'Alerts when a new food/order is received',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kGeneralChannelId,
          'General Notifications',
          description: 'General app notifications',
          importance: Importance.defaultImportance,
        ));
  }
}

/// Resolves the notification payload to a deep-link route.
///
/// The backend sends a `type` field (e.g. `ride_accepted`, `order_ready`)
/// together with an `id`/`rideId`/`orderId` field. This maps the combination
/// to the correct in-app route. If the backend already includes an explicit
/// `route` field, that is used as a fallback / override.
String? _resolveRoute(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final id = data['id'] as String? ??
      data['rideId'] as String? ??
      data['orderId'] as String?;
  switch (type) {
    case 'ride_accepted':
    case 'ride_started':
      return id != null ? '/rides/$id' : null;
    case 'ride_completed':
      return id != null ? '/rides/$id/receipt' : null;
    case 'order_ready':
    case 'order_delivered':
      return id != null ? '/food/orders/$id' : null;
    case 'booking_confirmed':
      return '/activity';
    case 'driver_approved':
      // Admin has approved the driver's KYC — route to the shell so the
      // driver router can refresh the profile and unlock the dashboard.
      return '/';
    default:
      return data['route'] as String?;
  }
}

void _showLocalNotificationFromPayload(RemoteMessage message) {
  final type = message.data['type'] as String? ?? '';
  final title = message.notification?.title ?? message.data['title'] as String? ?? _defaultTitle(type);
  final body = message.notification?.body ?? message.data['body'] as String? ?? '';

  String channelId;
  int priority = 2;

  switch (type) {
    case 'ride_request':
      channelId = _kRideOffersChannelId;
      priority = 4; // max
      break;
    case 'new_order':
      channelId = _kNewOrdersChannelId;
      priority = 4;
      break;
    default:
      channelId = _kGeneralChannelId;
      priority = 2;
  }

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelId == _kRideOffersChannelId
        ? 'Ride Offers'
        : channelId == _kNewOrdersChannelId
            ? 'New Orders'
            : 'General Notifications',
    channelDescription: 'PY Connect push notification',
    importance: priority >= 4 ? Importance.max : Importance.defaultImportance,
    priority: priority >= 4 ? Priority.max : Priority.defaultPriority,
    playSound: true,
    enableVibration: true,
    autoCancel: true,
    category: AndroidNotificationCategory.call,
    fullScreenIntent: priority >= 4,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  // Use a hash of the message id for a unique notification id
  final notificationId = message.hashCode;

  _localNotificationsPlugin.show(notificationId, title, body, details,
      payload: _resolveRoute(message.data));
}

String _defaultTitle(String type) {
  switch (type) {
    case 'ride_request':
      return 'New Ride Request';
    case 'new_order':
      return 'New Order Received';
    case 'ride_assigned':
      return 'Driver Assigned';
    case 'ride_completed':
      return 'Ride Completed';
    case 'order_status':
      return 'Order Update';
    default:
      return 'PY Connect';
  }
}

class FcmService {
  FcmService._();

  final _tokenController = StreamController<String>.broadcast();
  final _messageController = StreamController<RemoteMessage>.broadcast();
  final _tapController = StreamController<String>.broadcast();

  Stream<String> get onTokenRefresh => _tokenController.stream;
  Stream<RemoteMessage> get onForegroundMessage => _messageController.stream;
  Stream<String> get onNotificationTap => _tapController.stream;

  static Future<FcmService> initialize({FirebaseOptions? options}) async {
    await Firebase.initializeApp(options: options);
    await _initLocalNotifications();

    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final service = FcmService._();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    // Subscribe to topics for broadcast notifications
    await FirebaseMessaging.instance.subscribeToTopic('all_users');

    FirebaseMessaging.instance.onTokenRefresh.listen(service._tokenController.add);

    // Foreground messages — show local notification since FCM doesn't show
    // system notifications when the app is in the foreground
    FirebaseMessaging.onMessage.listen((message) {
      service._messageController.add(message);
      _showLocalNotificationFromPayload(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = _resolveRoute(message.data);
      if (route != null) {
        service._tapController.add(route);
      }
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final route = _resolveRoute(initialMessage.data);
      if (route != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          service._tapController.add(route);
        });
      }
    }

    return service;
  }

  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  Future<void> dispose() async {
    await _tokenController.close();
    await _messageController.close();
    await _tapController.close();
  }
}
