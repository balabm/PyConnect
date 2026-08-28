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
import '../features/vendor/presentation/equipment_inventory_screen.dart';
import '../features/vendor/presentation/equipment_rentals_screen.dart';
import '../features/vendor/presentation/equipment_detail_screen.dart';
import '../features/vendor/presentation/vendor_event_manager_screen.dart';
import '../features/vendor/presentation/staff_management_screen.dart';
import '../features/vendor/presentation/vendor_finance_screen.dart';
import '../features/vendor/presentation/vendor_disputes_screen.dart';
import '../features/vendor/presentation/vendor_reviews_screen.dart';
import '../features/vendor/presentation/vendor_help_screen.dart';
import '../features/vendor/data/equipment_api.dart';
import '../features/vendor/presentation/vendor_registration_screen.dart';
import '../features/vendor/presentation/printer_settings_screen.dart';
import '../features/vendor/presentation/claim_check_screen.dart';
import '../features/vendor/presentation/bag_intake_screen.dart';
import '../features/vendor/presentation/bag_collection_screen.dart';
import '../features/vendor/presentation/condition_photos_screen.dart';
import '../features/vendor/presentation/rental_return_screen.dart';
import '../features/vendor/presentation/assign_driver_screen.dart';
import '../features/vendor/presentation/partial_refund_screen.dart';
import '../features/vendor/presentation/occupancy_update_screen.dart';
import '../features/vendor/presentation/live_tables_screen.dart';
import '../features/vendor/presentation/crowd_dashboard_screen.dart';
import '../core/config/app_flavor.dart';
import '../core/providers/force_update_provider.dart';
import '../features/splash/presentation/force_update_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../shell/partner_shell.dart';

final partnerRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _PartnerAuthRefreshListenable(ref),
    redirect: (context, state) {
      final session = ref.read(vendorAuthControllerProvider).valueOrNull;
      final authenticated = session?.isAuthenticated ?? false;
      final isApproved = session?.isApproved ?? false;
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
        path: '/splash',
        builder: (_, _) => const SplashScreen(flavor: AppFlavor.partner),
      ),
      GoRoute(
        path: '/force-update',
        builder: (_, _) => const ForceUpdateScreen(),
      ),
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
          // ── Equipment vendor screens ──
          GoRoute(
            path: 'equipment-inventory',
            builder: (_, _) => const EquipmentInventoryScreen(),
          ),
          GoRoute(
            path: 'equipment-rentals',
            builder: (_, _) => const EquipmentRentalsScreen(),
          ),
          GoRoute(
            path: 'equipment-detail',
            builder: (_, state) => EquipmentDetailScreen(
              item: state.extra as EquipmentItemModel,
            ),
          ),
          // ── Pub/Club event manager ──
          GoRoute(
            path: 'events',
            builder: (_, _) => const VendorEventManagerScreen(),
          ),
          // ── Staff, Finance, Disputes, Reviews ──
          GoRoute(
            path: 'staff',
            builder: (_, _) => const StaffManagementScreen(),
          ),
          GoRoute(
            path: 'finance',
            builder: (_, _) => const VendorFinanceScreen(),
          ),
          GoRoute(
            path: 'disputes',
            builder: (_, _) => const VendorDisputesScreen(),
          ),
          GoRoute(
            path: 'reviews',
            builder: (_, _) => const VendorReviewsScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (_, _) => const VendorHelpScreen(),
          ),
          GoRoute(
            path: 'printer-settings',
            builder: (_, _) => const PrinterSettingsScreen(),
          ),
          // ── Luggage Cloak operational screens ──
          GoRoute(
            path: 'claim-check',
            builder: (_, _) => const ClaimCheckScreen(),
          ),
          GoRoute(
            path: 'bag-intake',
            builder: (_, _) => const BagIntakeScreen(),
          ),
          GoRoute(
            path: 'bag-collection',
            builder: (_, _) => const BagCollectionScreen(),
          ),
          // ── Scooter Rental operational screens ──
          GoRoute(
            path: 'condition-photos',
            builder: (_, _) => const ConditionPhotosScreen(),
          ),
          GoRoute(
            path: 'rental-return',
            builder: (context, state) => RentalReturnScreen(rentalId: state.extra as String?),
          ),
          // ── Taxi Operator operational screens ──
          GoRoute(
            path: 'assign-driver',
            builder: (_, state) => AssignDriverScreen(tripId: state.extra as String?),
          ),
          // ── Food vendor operational screens ──
          GoRoute(
            path: 'partial-refund',
            builder: (_, _) => const PartialRefundScreen(),
          ),
          // ── Venue operational screens ──
          GoRoute(
            path: 'occupancy',
            builder: (_, _) => const OccupancyUpdateScreen(),
          ),
          // ── Pub/Club live operations screens ──
          GoRoute(
            path: 'live-tables',
            builder: (_, _) => const LiveTablesScreen(),
          ),
          GoRoute(
            path: 'crowd-dashboard',
            builder: (_, _) => const CrowdDashboardScreen(),
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
