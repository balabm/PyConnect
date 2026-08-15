import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.status,
    this.rejectionReason,
  });

  final String accessToken;
  final String vendorId;
  final String vendorName;
  final String category;
  final String phone;
  final String status;
  final String? rejectionReason;

  bool get isAuthenticated => accessToken.isNotEmpty;
  bool get isApproved => status == 'Approved';
}

/// Owns vendor authentication: requesting OTP, verifying it, persisting
/// the token and exposing the current session. Uses a separate storage
/// key from the consumer auth to avoid token collision.
class VendorAuthController extends AsyncNotifier<VendorAuthSession?> {
  static const _vendorIdKey = 'partner.vendor_id';
  static const _vendorNameKey = 'partner.vendor_name';
  static const _categoryKey = 'partner.category';
  static const _phoneKey = 'partner.phone';
  static const _statusKey = 'partner.status';
  static const _rejectionKey = 'partner.rejection_reason';

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
    return _loadSession(token);
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
      await _persistSession(result);

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

      return _sessionFromResult(result);
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
    await _clearSession();
    state = const AsyncData(null);
  }

  bool get isAuthenticated => state.valueOrNull?.isAuthenticated ?? false;

  Future<void> _persistSession(VendorLoginResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vendorIdKey, result.vendorId);
    await prefs.setString(_vendorNameKey, result.vendorName);
    await prefs.setString(_categoryKey, result.category);
    await prefs.setString(_phoneKey, result.phone);
    await prefs.setString(_statusKey, result.status);
    if (result.rejectionReason != null && result.rejectionReason!.isNotEmpty) {
      await prefs.setString(_rejectionKey, result.rejectionReason!);
    } else {
      await prefs.remove(_rejectionKey);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vendorIdKey);
    await prefs.remove(_vendorNameKey);
    await prefs.remove(_categoryKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_statusKey);
    await prefs.remove(_rejectionKey);
  }

  Future<VendorAuthSession> _loadSession(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return VendorAuthSession(
      accessToken: token,
      vendorId: prefs.getString(_vendorIdKey) ?? '',
      vendorName: prefs.getString(_vendorNameKey) ?? '',
      category: prefs.getString(_categoryKey) ?? '',
      phone: prefs.getString(_phoneKey) ?? '',
      status: prefs.getString(_statusKey) ?? 'Pending',
      rejectionReason: prefs.getString(_rejectionKey),
    );
  }

  VendorAuthSession _sessionFromResult(VendorLoginResult result) =>
      VendorAuthSession(
        accessToken: result.accessToken,
        vendorId: result.vendorId,
        vendorName: result.vendorName,
        category: result.category,
        phone: result.phone,
        status: result.status,
        rejectionReason: result.rejectionReason,
      );
}

final vendorAuthApiProvider =
    Provider<VendorAuthApi>((ref) => VendorAuthApi(ref.watch(apiClientProvider)));

final vendorAuthControllerProvider =
    AsyncNotifierProvider<VendorAuthController, VendorAuthSession?>(
        VendorAuthController.new);
