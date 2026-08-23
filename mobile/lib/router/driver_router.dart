import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/phone_entry_screen.dart';
import '../features/driver/application/driver_providers.dart';
import '../features/driver/domain/driver_models.dart';
import '../features/driver/presentation/driver_earnings_screen.dart';
import '../features/driver/presentation/driver_kyc_screen.dart';
import '../features/driver/presentation/driver_pending_verification_screen.dart';
import '../features/driver/presentation/driver_profile_screen.dart';
import '../features/driver/presentation/driver_registration_screen.dart';
import '../features/driver/presentation/driver_ride_screen.dart';
import '../features/driver/presentation/driver_tutorial_screen.dart';
import '../features/driver/presentation/driver_safety_settings_screen.dart';
import '../features/driver/presentation/driver_help_screen.dart';
import '../core/config/app_flavor.dart';
import '../core/providers/force_update_provider.dart';
import '../features/splash/presentation/force_update_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../shell/driver_shell.dart';

final driverRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _DriverAuthRefreshListenable(ref),
    redirect: (context, state) {
      final authenticated =
          ref.read(authControllerProvider).valueOrNull?.isAuthenticated ?? false;
      final path = state.matchedLocation;

      // Force-update barrier takes precedence over all other routing.
      if (path == '/splash' || path == '/force-update') {
        return null;
      }

      if (ref.read(forceUpdateProvider).forceUpdate &&
          path != '/force-update' &&
          path != '/splash') {
        return '/force-update';
      }

      // Allow /register for unauthenticated users (self-onboarding)
      if (!authenticated && path == '/register') {
        return null;
      }

      if (!authenticated && path != '/auth' && !path.startsWith('/auth')) {
        return '/auth';
      }

      if (authenticated && (path == '/auth' || path.startsWith('/auth'))) {
        // After auth, check driver compliance status before routing to '/'.
        final profileAsync = ref.read(driverProfileProvider);
        final profile = profileAsync.valueOrNull;
        if (!profileAsync.isLoading && profile == null) {
          // No driver record exists yet — finish registration first.
          return '/register';
        }
        if (profile == null) {
          // Profile is still loading — avoid a blank screen by landing on the
          // shell, which will redirect once the profile resolves.
          return '/';
        }
        return _complianceRedirect(profile, path) ?? '/';
      }

      // Brand-new authenticated drivers with no profile must register first
      // so the onboarding flow has a driver record to attach KYC documents to.
      // We only act on a finished load to avoid flashing /register while the
      // profile is still being fetched. We also skip this check when the
      // provider hasn't started yet (isLoading false + valueOrNull null +
      // hasError false = never invoked) to avoid a false redirect.
      if (authenticated) {
        final profileAsync = ref.read(driverProfileProvider);
        // Only redirect to /register if the profile fetch has completed
        // (not loading) AND returned null (no driver record). If the fetch
        // errored, don't redirect — let the shell handle it.
        if (!profileAsync.isLoading &&
            profileAsync.valueOrNull == null &&
            !profileAsync.hasError &&
            path != '/register' &&
            path != '/kyc' &&
            path != '/tutorial' &&
            path != '/pending-verification') {
          return '/register';
        }
      }

      // Guard the main shell: ensure tutorial, signature and admin approval
      // are complete before the driver can access the dashboard.
      if (authenticated && path == '/') {
        final profile = ref.read(driverProfileProvider).valueOrNull;
        if (profile != null) {
          final redirect = _complianceRedirect(profile, path);
          if (redirect != null) return redirect;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(flavor: AppFlavor.driver),
      ),
      GoRoute(
        path: '/force-update',
        builder: (_, _) => const ForceUpdateScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const DriverRegistrationScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const PhoneEntryScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (_, _) => const OtpVerifyScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const DriverShell(),
        routes: [
          GoRoute(
            path: 'ride/:id',
            builder: (_, state) => DriverRideScreen(
              rideId: state.pathParameters['id']!,
              taskId: state.pathParameters['id']!,
              driverId: state.uri.queryParameters['driverId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'earnings',
            builder: (_, _) => const DriverEarningsScreen(),
          ),
          GoRoute(
            path: 'kyc',
            builder: (_, _) => const DriverKycScreen(),
          ),
          GoRoute(
            path: 'tutorial',
            builder: (_, _) => const DriverTutorialScreen(),
          ),
          GoRoute(
            path: 'pending-verification',
            builder: (_, _) => const DriverPendingVerificationScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (_, _) => const DriverProfileScreen(),
          ),
          GoRoute(
            path: 'safety-settings',
            builder: (_, _) => const DriverSafetySettingsScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (_, _) => const DriverHelpScreen(),
          ),
        ],
      ),
    ],
  );
});

class _DriverAuthRefreshListenable extends ChangeNotifier {
  _DriverAuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(driverProfileProvider, (_, _) => notifyListeners());
  }
}

/// Returns a redirect path if the driver has not completed onboarding
/// compliance steps (tutorial, signature, admin approval). Returns null
/// if the driver is fully compliant and can access the requested path.
String? _complianceRedirect(DriverProfileModel profile, String path) {
  // Tutorial must be completed first.
  if (!profile.hasCompletedTutorial && path != '/tutorial') {
    return '/tutorial';
  }
  // Safety agreement must be signed.
  if (!profile.hasSignedAgreement && path != '/tutorial') {
    return '/tutorial';
  }
  // Admin approval (KYC review) must be granted before going online.
  if (!profile.isApproved &&
      path != '/pending-verification' &&
      path != '/kyc' &&
      path != '/tutorial') {
    return '/pending-verification';
  }
  return null;
}
