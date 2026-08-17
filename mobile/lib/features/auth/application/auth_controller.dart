import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../notifications/application/notification_providers.dart';
import '../data/google_sign_in_service.dart';

/// Owns authentication: requesting OTP, verifying it, persisting the token and
/// exposing the current session.
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || token.isEmpty) return null;

    ref.read(apiClientProvider).setToken(token);
    ref.read(authTokenProvider.notifier).state = token;
    try {
      final me = await ref.read(authApiProvider).me();
      return AuthSession(
        name: me.name,
        phone: me.phone,
        role: me.role,
        token: token,
        isProMember: me.isProMember,
      );
    } catch (_) {
      // Token may be stale; the router will force re-auth on a 401.
      return AuthSession(name: '', phone: '', role: '', token: token);
    }
  }

  /// Asks for an OTP for [phone]. On failure, surfaces the error in [state].
  Future<void> requestOtp(String phone) async {
    final current = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      await ref.read(authApiProvider).requestOtp(phone);
      ref.read(otpRequestedForProvider.notifier).state = phone;
      return current;
    });
  }

  Future<void> verifyOtp(String phone, String otp, {String? name}) async {
    state = await AsyncValue.guard(() async {
      final result =
          await ref.read(authApiProvider).verifyOtp(phone, otp, name: name);
      await ref.read(tokenStorageProvider).write(result.accessToken);
      ref.read(apiClientProvider).setToken(result.accessToken);
      ref.read(authTokenProvider.notifier).state = result.accessToken;

      // Register FCM device token with the backend now that we have a JWT.
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          ref.read(fcmTokenProvider.notifier).state = fcmToken;
          await ref.read(deviceTokenApiProvider).updateToken(fcmToken);
        }
      } catch (_) {
      }

      return AuthSession(
        name: result.name,
        phone: result.phone,
        role: result.role,
        token: result.accessToken,
        isProMember: result.isProMember,
      );
    });

    // If the user started a Google sign-in that needs a phone, finish linking
    // immediately after the phone number has been verified.
    if (state.hasValue && ref.read(socialAuthPendingProvider) != null) {
      await linkGoogleAccount();
    }
  }

  /// Attempts a Google sign-in. If the backend says the account needs a phone
  /// number, [socialAuthPendingProvider] is set and [state] becomes `null` so
  /// the UI can route to phone verification and call [linkGoogleToPhone].
  Future<void> signInWithGoogle() async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    try {
      final idToken = await ref.read(googleSignInServiceProvider).getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInException('Google sign-in was cancelled.');
      }

      final result = await ref.read(authApiProvider).signInWithGoogle(idToken);

      if (result.needsPhone) {
        ref.read(socialAuthPendingProvider.notifier).state = SocialAuthPending(
          idToken: idToken,
          name: result.name ?? '',
        );
        state = const AsyncData(null);
        return;
      }

      if (result.accessToken == null || result.accessToken!.isEmpty) {
        throw const GoogleSignInException('Backend did not issue a token.');
      }

      await ref.read(tokenStorageProvider).write(result.accessToken!);
      ref.read(apiClientProvider).setToken(result.accessToken!);
      ref.read(authTokenProvider.notifier).state = result.accessToken;

      // Register FCM token after Google sign-in
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          ref.read(fcmTokenProvider.notifier).state = fcmToken;
          await ref.read(deviceTokenApiProvider).updateToken(fcmToken);
        }
      } catch (_) {
      }

      state = AsyncData(AuthSession(
        name: result.name ?? '',
        phone: result.phone ?? '',
        role: result.role ?? 'Tourist',
        token: result.accessToken!,
        isProMember: result.isProMember,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
      // Preserve any existing session on failure.
      if (current != null) state = AsyncData(current);
    }
  }

  /// Links the currently authenticated phone-verified user to the Google
  /// account stored in [socialAuthPendingProvider]. Call this after the user
  /// has completed the phone/OTP flow so the Google idToken can be attached
  /// to their existing profile.
  Future<void> linkGoogleAccount() async {
    state = await AsyncValue.guard(() async {
      final pending = ref.read(socialAuthPendingProvider);
      if (pending == null) {
        throw const GoogleSignInException(
          'No pending Google sign-in. Start Google sign-in first.',
        );
      }

      final current = state.valueOrNull;
      if (current == null) {
        throw const GoogleSignInException(
          'Phone must be verified before linking Google.',
        );
      }

      final result =
          await ref.read(authApiProvider).linkGoogleAccount(pending.idToken);

      if (result.accessToken == null || result.accessToken!.isEmpty) {
        throw const GoogleSignInException('Backend did not issue a token.');
      }

      await ref.read(tokenStorageProvider).write(result.accessToken!);
      ref.read(apiClientProvider).setToken(result.accessToken!);
      ref.read(authTokenProvider.notifier).state = result.accessToken;
      ref.read(socialAuthPendingProvider.notifier).state = null;

      return AuthSession(
        name: result.name ?? pending.name,
        phone: result.phone ?? current.phone,
        role: result.role ?? current.role,
        token: result.accessToken!,
        isProMember: result.isProMember,
      );
    });
  }

  Future<void> signOut() async {
    // Remove the backend FCM token before deleting the device token so the
    // user (or driver) stops receiving push notifications after logout.
    try {
      await ref.read(apiClientProvider).deleteFcmToken();
    } catch (_) {
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
    }

    await ref.read(tokenStorageProvider).clear();
    ref.read(authTokenProvider.notifier).state = null;
    state = const AsyncData(null);
  }

  /// Deletes the user's account and all personal data (Right to be Forgotten).
  /// After successful deletion, signs the user out locally.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      await ref.read(authApiProvider).deleteAccount();
      await ref.read(tokenStorageProvider).clear();
      ref.read(authTokenProvider.notifier).state = null;
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Refreshes the session with a new JWT (e.g. after a phone number
  /// change). Persists the new token and updates the in-memory state.
  Future<void> refreshWithToken(String newToken) async {
    await ref.read(tokenStorageProvider).write(newToken);
    ref.read(apiClientProvider).setToken(newToken);
    ref.read(authTokenProvider.notifier).state = newToken;
    try {
      final me = await ref.read(authApiProvider).me();
      state = AsyncData(AuthSession(
        name: me.name,
        phone: me.phone,
        role: me.role,
        token: newToken,
        isProMember: me.isProMember,
      ));
    } catch (_) {
      // Keep the old session if /me fails — the token is still valid.
    }
  }

  bool get isAuthenticated => state.valueOrNull?.isAuthenticated ?? false;
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final phoneNumberProvider = StateProvider<String>((ref) => '');

final otpRequestedForProvider = StateProvider<String>((ref) => '');

final googleSignInServiceProvider = Provider<GoogleSignInService>((ref) {
  final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
  final serverClientId =
      webClientId != null && webClientId.isNotEmpty &&
              !webClientId.contains('REPLACE')
          ? webClientId
          : null;
  return GoogleSignInService(serverClientId: serverClientId);
});

final socialAuthPendingProvider =
    StateProvider<SocialAuthPending?>((ref) => null);

class SocialAuthPending {
  SocialAuthPending({required this.idToken, required this.name});

  final String idToken;
  final String name;
}

class AuthSession {
  AuthSession({
    required this.name,
    required this.phone,
    required this.role,
    required this.token,
    this.isProMember = false,
  });

  final String name;
  final String phone;
  final String role;
  final String token;
  final bool isProMember;

  bool get isAuthenticated => token.isNotEmpty;
}