import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_flavor.dart';
import '../../../core/providers.dart';
import '../data/device_token_api.dart';
import '../data/fcm_service.dart';

/// Flavor-aware device token API. The partner app uses the vendor endpoint
/// (/api/vendor/device-token), while consumer and driver apps use the user
/// endpoint (/api/user/device-token).
final deviceTokenApiProvider = Provider<DeviceTokenApi>((ref) {
  final flavor = ref.watch(appFlavorProvider);
  return DeviceTokenApi(
    ref.watch(apiClientProvider),
    useVendorEndpoint: flavor == AppFlavor.partner,
  );
});

final fcmServiceProvider = Provider<FcmService?>((ref) {
  return null;
});

final fcmTokenProvider = StateProvider<String?>((ref) => null);

final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

final fcmInitializationProvider = FutureProvider<FcmService?>((ref) async {
  if (kIsWeb) return null;

  final service = await FcmService.initialize();

  final token = await service.getToken();
  if (token != null) {
    ref.read(fcmTokenProvider.notifier).state = token;
    try {
      await ref.read(deviceTokenApiProvider).updateToken(token);
    } catch (_) {
    }
  }

  service.onTokenRefresh.listen((newToken) {
    ref.read(fcmTokenProvider.notifier).state = newToken;
    try {
      ref.read(deviceTokenApiProvider).updateToken(newToken);
    } catch (_) {
    }
  });

  service.onNotificationTap.listen((route) {
    ref.read(pendingDeepLinkProvider.notifier).state = route;
  });

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
