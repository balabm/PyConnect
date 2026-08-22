import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A dedicated notification service for order/ride progress
/// notifications with Android progress bars and ongoing notification
/// support.
///
/// Uses `flutter_local_notifications` to update an active notification
/// ID instead of spawning a new one. The user sees a visual progress
/// bar (e.g., 50% for Preparing, 90% for Arriving) directly in their
/// Android notification drawer.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Channel for order/ride progress notifications.
  static const _kProgressChannelId = 'order_progress';
  static const _kProgressChannelName = 'Order Progress';
  static const _kProgressChannelDesc =
      'Live progress updates for active orders and rides';

  /// Stable notification IDs for ongoing tracking.
  /// Uses a hash of the entity ID so each order/ride gets a unique
  /// but deterministic notification ID.
  int _notificationIdFor(String entityId) {
    return entityId.hashCode & 0x7FFFFFFF; // Ensure positive int
  }

  /// Initialize the progress notification channel. Call once at app
  /// startup alongside the existing FCM initialization.
  Future<void> initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kProgressChannelId,
          _kProgressChannelName,
          description: _kProgressChannelDesc,
          importance: Importance.low,
          showBadge: false,
        ));
  }

  /// Shows or updates an ongoing progress notification for an order/ride.
  ///
  /// [entityId] — The order or ride ID (used for stable notification ID).
  /// [title] — Notification title (e.g., "Order #12345").
  /// [statusText] — Current status text (e.g., "Preparing your food").
  /// [progressPercent] — Progress 0-100 (e.g., 50 for Preparing, 90 for Arriving).
  /// [route] — Deep-link route for tap navigation (e.g., "/food/orders/12345").
  /// [isComplete] — When true, removes the ongoing flag and allows auto-cancel.
  Future<void> showProgressNotification({
    required String entityId,
    required String title,
    required String statusText,
    required int progressPercent,
    String? route,
    bool isComplete = false,
  }) async {
    final notificationId = _notificationIdFor(entityId);

    final androidDetails = AndroidNotificationDetails(
      _kProgressChannelId,
      _kProgressChannelName,
      channelDescription: _kProgressChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: !isComplete,
      autoCancel: isComplete,
      showProgress: !isComplete && progressPercent > 0 && progressPercent < 100,
      maxProgress: 100,
      progress: progressPercent,
      indeterminate: false,
      playSound: isComplete,
      enableVibration: isComplete,
      category: AndroidNotificationCategory.progress,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      notificationId,
      title,
      statusText,
      details,
      payload: route,
    );
  }

  /// Cancels the progress notification for a specific entity.
  Future<void> cancelProgressNotification(String entityId) async {
    final notificationId = _notificationIdFor(entityId);
    await _plugin.cancel(notificationId);
  }

  /// Maps an order status string to a progress percentage.
  static int progressForStatus(String status) {
    final s = status.toLowerCase().replaceAll('_', '');
    if (s.contains('placed') || s.contains('pending')) return 10;
    if (s.contains('confirmed') || s.contains('accepted')) return 25;
    if (s.contains('preparing')) return 50;
    if (s.contains('ready')) return 70;
    if (s.contains('outfordelivery') || s.contains('enroute')) return 85;
    if (s.contains('arrived') || s.contains('arriving')) return 90;
    if (s.contains('delivered') || s.contains('completed')) return 100;
    if (s.contains('cancelled')) return 0;
    return 0;
  }

  /// Maps a ride status string to a progress percentage.
  static int progressForRideStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('requested')) return 5;
    if (s.contains('searching')) return 15;
    if (s.contains('driverassigned') || s.contains('assigned')) return 30;
    if (s.contains('arrivedatpickup') || s.contains('arrived')) return 45;
    if (s.contains('enroute') || s.contains('started')) return 70;
    if (s.contains('completed')) return 100;
    if (s.contains('cancelled')) return 0;
    return 0;
  }

  /// Generates a user-friendly status text for notifications.
  static String statusTextForOrder(String status, {int? etaMinutes}) {
    final s = status.toLowerCase().replaceAll('_', '');
    if (s.contains('placed') || s.contains('pending')) {
      return 'Order received — confirming with restaurant';
    }
    if (s.contains('confirmed') || s.contains('accepted')) {
      return 'Order confirmed — preparing soon';
    }
    if (s.contains('preparing')) {
      return 'Preparing your food in the kitchen';
    }
    if (s.contains('ready')) {
      return 'Order ready — waiting for captain';
    }
    if (s.contains('outfordelivery')) {
      return etaMinutes != null
          ? 'On the way — arriving in $etaMinutes mins'
          : 'Your captain is on the way';
    }
    if (s.contains('delivered')) {
      return 'Delivered — enjoy your meal!';
    }
    if (s.contains('cancelled')) {
      return 'Order cancelled';
    }
    return 'Status: $status';
  }

  /// Generates a user-friendly status text for ride notifications.
  static String statusTextForRide(String status, {int? etaMinutes}) {
    final s = status.toLowerCase();
    if (s.contains('searching')) {
      return 'Finding your captain...';
    }
    if (s.contains('assigned')) {
      return etaMinutes != null
          ? 'Captain assigned — $etaMinutes mins away'
          : 'Captain assigned — heading to pickup';
    }
    if (s.contains('arrived')) {
      return 'Captain has arrived at pickup';
    }
    if (s.contains('enroute') || s.contains('started')) {
      return etaMinutes != null
          ? 'En route — $etaMinutes mins to destination'
          : 'En route to destination';
    }
    if (s.contains('completed')) {
      return 'Ride completed — thank you!';
    }
    if (s.contains('cancelled')) {
      return 'Ride cancelled';
    }
    return 'Status: $status';
  }
}
