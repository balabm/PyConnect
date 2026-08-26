import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../notifications/application/notification_providers.dart';
import '../../vendor/data/vendor_dashboard_api.dart';
import 'auth_controller.dart';
import '../data/vendor_auth_api.dart';

/// Auth session for the vendor/partner app. Stores the vendor-scoped JWT
/// and exposes the current vendor identity. Supports multi-business
/// partners via the [businesses] list and [activeVendorId].
class VendorAuthSession {
  VendorAuthSession({
    required this.accessToken,
    required this.vendorId,
    required this.vendorName,
    required this.category,
    required this.phone,
    required this.status,
    this.rejectionReason,
    this.businesses = const [],
  });

  final String accessToken;
  final String vendorId;
  final String vendorName;
  final String category;
  final String phone;
  final String status;
  final String? rejectionReason;
  final List<VendorBusinessSummary> businesses;

  bool get isAuthenticated => accessToken.isNotEmpty;
  bool get isApproved => status == 'Approved';
  bool get hasMultipleBusinesses => businesses.length > 1;
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

    final prefsSession = await _loadSession(token);
    try {
      final profile =
          await VendorDashboardApi(ref.read(apiClientProvider)).getProfile();
      if (kDebugMode) {
        print('DEBUG VendorProfile: id=${profile.id} name=${profile.name} '
            'category=${profile.category} isApproved=${profile.isApproved} '
            'isActive=${profile.isActive}');
      }
      final status = _statusFromProfile(profile);
      final updated = VendorAuthSession(
        accessToken: prefsSession.accessToken,
        vendorId: profile.id.isNotEmpty ? profile.id : prefsSession.vendorId,
        vendorName: profile.name.isNotEmpty ? profile.name : prefsSession.vendorName,
        category: profile.category.isNotEmpty ? profile.category : prefsSession.category,
        phone: prefsSession.phone,
        status: status,
        rejectionReason: status == 'Rejected'
            ? 'Account has been deactivated. Contact support for details.'
            : null,
        businesses: prefsSession.businesses,
      );
      await _persistSession(updated);
      return updated;
    } on AuthRequiredException {
      // 401 — the token is invalid/expired (e.g. after a DB purge that
      // re-seeded user IDs). Clear the token and force re-login instead of
      // falling back to a cached session with a dead token.
      if (kDebugMode) {
        print('DEBUG VendorAuth: 401 — token invalid, clearing session');
      }
      await ref.read(tokenStorageProvider).clear();
      ref.read(authTokenProvider.notifier).state = null;
      ref.read(apiClientProvider).setToken(null);
      await _clearSession();
      return null;
    } catch (e) {
      // Network/transient error — fall back to the locally cached session
      // so the partner can still use the app offline and re-check later.
      if (kDebugMode) {
        print('DEBUG VendorAuth: profile fetch failed (non-auth): $e');
      }
      return prefsSession;
    }
  }

  String _statusFromProfile(VendorProfile profile) {
    if (!profile.isApproved) return 'Pending';
    if (!profile.isActive) return 'Rejected';
    return 'Approved';
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
      if (kDebugMode) {
        print('DEBUG VendorLogin: vendorId=${result.vendorId} '
            'name=${result.vendorName} category=${result.category} '
            'status=${result.status}');
      }
      await ref.read(tokenStorageProvider).write(result.accessToken);
      ref.read(apiClientProvider).setToken(result.accessToken);
      ref.read(authTokenProvider.notifier).state = result.accessToken;
      await _persistSession(_sessionFromResult(result));

      // Register FCM device token with the backend now that we have a JWT.
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          ref.read(fcmTokenProvider.notifier).state = fcmToken;
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

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
    }

    await ref.read(tokenStorageProvider).clear();
    ref.read(authTokenProvider.notifier).state = null;
    ref.read(apiClientProvider).setToken(null);
    await _clearSession();
    state = const AsyncData(null);
  }

  /// Switches the active vendor context for multi-business partners.
  /// Updates the session's vendorId, vendorName, and category to the
  /// selected business and persists the change. The API client will
  /// use the new vendorId for subsequent vendor API calls.
  Future<void> switchVendor(VendorBusinessSummary business) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = VendorAuthSession(
      accessToken: current.accessToken,
      vendorId: business.vendorId,
      vendorName: business.name,
      category: business.category,
      phone: current.phone,
      status: current.status,
      rejectionReason: current.rejectionReason,
      businesses: current.businesses,
    );
    await _persistSession(updated);
    state = AsyncData(updated);
  }

  bool get isAuthenticated => state.valueOrNull?.isAuthenticated ?? false;

  Future<void> _persistSession(VendorAuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vendorIdKey, session.vendorId);
    await prefs.setString(_vendorNameKey, session.vendorName);
    await prefs.setString(_categoryKey, session.category);
    await prefs.setString(_phoneKey, session.phone);
    await prefs.setString(_statusKey, session.status);
    if (session.rejectionReason != null && session.rejectionReason!.isNotEmpty) {
      await prefs.setString(_rejectionKey, session.rejectionReason!);
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
        businesses: result.businesses,
      );
}

final vendorAuthApiProvider =
    Provider<VendorAuthApi>((ref) => VendorAuthApi(ref.watch(apiClientProvider)));

final vendorAuthControllerProvider =
    AsyncNotifierProvider<VendorAuthController, VendorAuthSession?>(
        VendorAuthController.new);
