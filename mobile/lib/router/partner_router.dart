import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/vendor_auth_controller.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/phone_entry_screen.dart';
import '../features/vendor/presentation/pending_approval_screen.dart';
import '../features/scanner/presentation/scanner_screen.dart';
import '../features/vendor/presentation/vendor_menu_screen.dart';
import '../features/vendor/presentation/vendor_promotions_screen.dart';
import '../features/vendor/presentation/vendor_orders_screen.dart';
import '../features/vendor/presentation/vendor_bookings_screen.dart';
import '../features/vendor/presentation/vendor_venue_screen.dart';
import '../features/vendor/presentation/vendor_wallet_screen.dart';
import '../features/vendor/presentation/kitchen_display_screen.dart';
import '../features/vendor/presentation/drinks_menu_screen.dart';
import '../features/vendor/presentation/fleet_management_screen.dart';
import '../features/vendor/presentation/active_rentals_screen.dart';
import '../features/vendor/presentation/taxi_fleet_screen.dart';
import '../features/vendor/presentation/taxi_rides_screen.dart';
import '../features/vendor/presentation/cloak_capacity_screen.dart';
import '../features/vendor/presentation/vendor_registration_screen.dart';
import '../features/vendor/presentation/printer_settings_screen.dart';
import '../shell/partner_shell.dart';

final partnerRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _PartnerAuthRefreshListenable(ref),
    redirect: (context, state) {
      final session = ref.read(vendorAuthControllerProvider).valueOrNull;
      final authenticated = session?.isAuthenticated ?? false;
      final isApproved = session?.isApproved ?? false;
      final path = state.matchedLocation;

      // Allow /register for unauthenticated users (self-onboarding)
      if (!authenticated && path == '/register') {
        return null;
      }

      if (!authenticated && path != '/auth' && !path.startsWith('/auth')) {
        return '/auth';
      }

      if (authenticated && (path == '/auth' || path.startsWith('/auth'))) {
        return isApproved ? '/' : '/pending-approval';
      }

      if (authenticated && !isApproved && path != '/pending-approval' && !path.startsWith('/pending-approval')) {
        return '/pending-approval';
      }

      if (authenticated && isApproved && path == '/pending-approval') {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/register',
        builder: (_, _) => const VendorRegistrationScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (_, _) => const PendingApprovalScreen(),
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
        builder: (_, _) => const PartnerShell(),
        routes: [
          GoRoute(
            path: 'menu',
            builder: (_, _) => const VendorMenuScreen(),
          ),
          GoRoute(
            path: 'promotions',
            builder: (_, _) => const VendorPromotionsScreen(),
          ),
          GoRoute(
            path: 'scanner',
            builder: (_, _) => const ScannerScreen(),
          ),
          GoRoute(
            path: 'kds',
            builder: (_, _) => const KitchenDisplayScreen(),
          ),
          GoRoute(
            path: 'orders',
            builder: (_, _) => const VendorOrdersScreen(),
          ),
          GoRoute(
            path: 'bookings',
            builder: (_, _) => const VendorBookingsScreen(),
          ),
          GoRoute(
            path: 'venue',
            builder: (_, _) => const VendorVenueScreen(),
          ),
          GoRoute(
            path: 'wallet',
            builder: (_, _) => const VendorWalletScreen(),
          ),
          GoRoute(
            path: 'drinks-menu',
            builder: (_, _) => const DrinksMenuScreen(),
          ),
          GoRoute(
            path: 'fleet',
            builder: (_, _) => const FleetManagementScreen(),
          ),
          GoRoute(
            path: 'rentals',
            builder: (_, _) => const ActiveRentalsScreen(),
          ),
          GoRoute(
            path: 'taxi-fleet',
            builder: (_, _) => const TaxiFleetScreen(),
          ),
          GoRoute(
            path: 'rides',
            builder: (_, _) => const TaxiRidesScreen(),
          ),
          GoRoute(
            path: 'capacity',
            builder: (_, _) => const CloakCapacityScreen(),
          ),
          GoRoute(
            path: 'printer-settings',
            builder: (_, _) => const PrinterSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _PartnerAuthRefreshListenable extends ChangeNotifier {
  _PartnerAuthRefreshListenable(Ref ref) {
    ref.listen(vendorAuthControllerProvider, (_, _) => notifyListeners());
  }
}
