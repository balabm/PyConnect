import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/phone_entry_screen.dart';
import '../features/driver/presentation/driver_earnings_screen.dart';
import '../features/driver/presentation/driver_kyc_screen.dart';
import '../features/driver/presentation/driver_pending_verification_screen.dart';
import '../features/driver/presentation/driver_registration_screen.dart';
import '../features/driver/presentation/driver_ride_screen.dart';
import '../features/driver/presentation/driver_tutorial_screen.dart';
import '../shell/driver_shell.dart';

final driverRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _DriverAuthRefreshListenable(ref),
    redirect: (context, state) {
      final authenticated =
          ref.read(authControllerProvider).valueOrNull?.isAuthenticated ?? false;
      final path = state.matchedLocation;

      // Allow /register for unauthenticated users (self-onboarding)
      if (!authenticated && path == '/register') {
        return null;
      }

      if (!authenticated && path != '/auth' && !path.startsWith('/auth')) {
        return '/auth';
      }

      if (authenticated && (path == '/auth' || path.startsWith('/auth'))) {
        return '/';
      }

      return null;
    },
    routes: [
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
  }
}
