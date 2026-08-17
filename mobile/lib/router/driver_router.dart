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
import '../features/driver/presentation/driver_registration_screen.dart';
import '../features/driver/presentation/driver_ride_screen.dart';
import '../features/driver/presentation/driver_tutorial_screen.dart';
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
        final profile = ref.read(driverProfileProvider).valueOrNull;
        if (profile == null) {
          // Profile not loaded yet (or no profile) — allow through; the
          // shell will handle the empty state.
          return '/';
        }
        return _complianceRedirect(profile, path) ?? '/';
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
