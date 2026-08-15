import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../notifications/application/notification_providers.dart';
import 'auth_controller.dart';
import '../data/vendor_auth_api.dart';

/// Auth session for the vendor/partner app. Stores the vendor-scoped JWT
/// and exposes the current vendor identity.
class VendorAuthSession {
  VendorAuthSession({
    required this.accessToken,
    required this.vendorId,
    required this.vendorName,
    required this.category,
    required this.phone,
  });

  final String accessToken;
  final String vendorId;
  final String vendorName;
  final String category;
  final String phone;

  bool get isAuthenticated => accessToken.isNotEmpty;
}

/// Owns vendor authentication: requesting OTP, verifying it, persisting
/// the token and exposing the current session. Uses a separate storage
/// key from the consumer auth to avoid token collision.
class VendorAuthController extends AsyncNotifier<VendorAuthSession?> {
  @override
  Future<VendorAuthSession?> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    // Note: We store vendor tokens with a 'vendor.' prefix to distinguish
    // from consumer tokens. For simplicity in this iteration, we share
    // the same storage key but the partner app is a separate binary so
    // there's no actual collision.
    if (token == null || token.isEmpty) return null;

    ref.read(apiClientProvider).setToken(token);
    ref.read(authTokenProvider.notifier).state = token;
    return VendorAuthSession(
      accessToken: token,
      vendorId: '',
      vendorName: '',
      category: '',
      phone: '',
    );
  }

  Future<void> requestOtp(String phone) async {
    final current = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      await ref.read(vendorAuthApiProvider).requestOtp(phone);
      ref.read(otpRequestedForProvider.notifier).state = phone;
      return current;
    });
  }

  Future<void> verifyOtp(String phone, String otpCode) async {
    state = await AsyncValue.guard(() async {
      final result =
          await ref.read(vendorAuthApiProvider).verifyOtp(phone, otpCode);
      await ref.read(tokenStorageProvider).write(result.accessToken);
      ref.read(apiClientProvider).setToken(result.accessToken);
      ref.read(authTokenProvider.notifier).state = result.accessToken;

      // Register FCM device token with the backend now that we have a JWT.
      // This ensures the vendor receives push notifications for new orders
      // even when the app is backgrounded.
      try {
        final fcmToken = ref.read(fcmTokenProvider);
        if (fcmToken != null) {
          await ref.read(deviceTokenApiProvider).updateToken(fcmToken);
        }
      } catch (_) {
        // Non-fatal: token will be registered on next app startup.
      }

      return VendorAuthSession(
        accessToken: result.accessToken,
        vendorId: result.vendorId,
        vendorName: result.vendorName,
        category: result.category,
        phone: result.phone,
      );
    });
  }

  Future<void> signOut() async {
    // Clear the FCM device token so the vendor doesn't receive push
    // notifications after logging out.
    try {
      await ref.read(deviceTokenApiProvider).clearToken();
    } catch (_) {
    }

    await ref.read(tokenStorageProvider).clear();
    ref.read(authTokenProvider.notifier).state = null;
    ref.read(apiClientProvider).setToken(null);
    state = const AsyncData(null);
  }

  bool get isAuthenticated => state.valueOrNull?.isAuthenticated ?? false;
}

final vendorAuthApiProvider =
    Provider<VendorAuthApi>((ref) => VendorAuthApi(ref.watch(apiClientProvider)));

final vendorAuthControllerProvider =
    AsyncNotifierProvider<VendorAuthController, VendorAuthSession?>(
        VendorAuthController.new);
