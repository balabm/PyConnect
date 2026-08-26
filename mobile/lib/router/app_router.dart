import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/phone_entry_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/wallet/presentation/consumer_wallet_screen.dart';
import '../features/auth/presentation/change_phone_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/bookings/presentation/booking_screen.dart';
import '../features/tickets/presentation/ticket_screen.dart';
import '../features/essentials/presentation/essentials_order_history_screen.dart';
import '../features/essentials/presentation/essentials_screen.dart';
import '../features/essentials/presentation/essentials_store_view.dart';
import '../features/experiences/presentation/experiences_screen.dart';
import '../features/events/presentation/party_builder_screen.dart';
import '../features/events/presentation/create_party_screen.dart';
import '../features/events/presentation/event_list_screen.dart';
import '../features/events/presentation/event_detail_screen.dart';
import '../features/events/presentation/host_scanner_screen.dart';
import '../features/events/presentation/attendees_screen.dart';
import '../features/genie/presentation/genie_screen.dart';
import '../features/split_payments/presentation/split_payment_screen.dart';
import '../features/food/presentation/food_order_detail_screen.dart';
import '../features/food/presentation/food_order_history_screen.dart';
import '../features/food/presentation/food_screen.dart';
import '../features/activity/presentation/stay_receipt_screen.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/rides/presentation/ride_history_screen.dart';
import '../features/rides/presentation/ride_rating_screen.dart';
import '../features/rides/presentation/ride_receipt_screen.dart';
import '../features/rides/presentation/ride_tracking_screen.dart';
import '../features/rides/presentation/saved_locations_screen.dart';
import '../features/rides/presentation/scheduled_rides_screen.dart';
import '../features/rides/presentation/emergency_contacts_screen.dart';
import '../features/rides/presentation/trip_share_screen.dart';
import '../features/stays/presentation/homestay_detail_screen.dart';
import '../features/support/presentation/help_screen.dart';
import '../features/venues/data/venue_api.dart';
import '../features/venues/presentation/venue_detail_screen.dart';
import '../features/venues/presentation/venue_list_screen.dart';
import '../features/location/presentation/saved_addresses_screen.dart';
import '../features/location/presentation/map_picker_screen.dart';
import '../features/events/presentation/ticket_wallet_screen.dart';
import '../features/equipment/presentation/equipment_browse_screen.dart';
import '../features/equipment/presentation/equipment_detail_screen.dart';
import '../features/equipment/presentation/my_equipment_rentals_screen.dart';
import '../features/equipment/data/consumer_equipment_api.dart';
import '../features/party_services/presentation/party_services_browse_screen.dart';
import '../features/party_services/presentation/party_service_detail_screen.dart';
import '../features/party_services/presentation/my_party_bookings_screen.dart';
import '../features/party_services/data/party_services_api.dart';
import '../shell/home_shell.dart';
import '../core/config/app_flavor.dart';
import '../core/providers.dart';
import '../core/providers/force_update_provider.dart';
import '../core/widgets/empty_state_view.dart';
import '../features/splash/presentation/force_update_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    errorBuilder: (context, state) => EmptyStateView(
      icon: Icons.error_outline,
      title: 'Page not found',
      subtitle: 'The page you are looking for does not exist.',
      actionLabel: 'Return to Home',
      onAction: () => context.go('/'),
      isError: true,
    ),
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) {
      final authenticated = ref.read(authControllerProvider).valueOrNull?.isAuthenticated ?? false;
      final hasSeenAuth = ref.read(hasSeenAuthScreenProvider);
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

      // Handle FCM deep link: if a pending deep link exists and the user is
      // authenticated, navigate to that route.
      final pendingDeepLink = ref.read(pendingDeepLinkProvider);
      if (pendingDeepLink != null && authenticated && path == '/') {
        ref.read(pendingDeepLinkProvider.notifier).state = null;
        return pendingDeepLink;
      }

      // First launch: redirect unauthenticated users to the login screen.
      // They can "Continue as Guest" to skip into the app.
      if (!authenticated && !hasSeenAuth && path == '/') {
        return '/auth';
      }

      // Routes that require an authenticated identity.
      // - Venue booking flow
      // - Profile management (viewing profile, changing phone number)
      final requiresAuth =
          (path.startsWith('/venues/') && path.endsWith('/book')) ||
          path == '/profile' ||
          path == '/change-phone';
      if (requiresAuth && !authenticated) {
        // Remember where the user was trying to go so we can return after login.
        ref.read(pendingAuthRedirectProvider.notifier).state = state.uri.toString();
        return '/auth';
      }

      // Signed-in users should not land on the auth screens; return to pending
      // destination or home.
      if (authenticated && (path == '/auth' || path.startsWith('/auth'))) {
        final pending = ref.read(pendingAuthRedirectProvider);
        ref.read(pendingAuthRedirectProvider.notifier).state = null;
        return pending ?? '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(flavor: AppFlavor.consumer),
      ),
      GoRoute(
        path: '/force-update',
        builder: (_, _) => const ForceUpdateScreen(),
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
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeShell(),
        routes: [
          GoRoute(
            path: 'venues',
            builder: (_, state) => VenueListScreen(
              initialCategory: state.uri.queryParameters['category'],
              initialFilter: state.uri.queryParameters['filter'],
            ),
            routes: [
              GoRoute(
                path: ':venueId',
                builder: (_, state) => VenueDetailScreen(
                  venueId: state.pathParameters['venueId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'book',
                    builder: (_, state) => BookingScreen(
                      venueId: state.pathParameters['venueId']!,
                      initialVenue: state.extra as Venue?,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'transit',
            builder: (_, _) => const HomeShell(),
          ),
          GoRoute(
            path: 'party',
            builder: (_, _) => const PartyBuilderScreen(),
          ),
          GoRoute(
            path: 'create-party',
            builder: (_, _) => const CreatePartyScreen(),
          ),
          GoRoute(
            path: 'genie',
            builder: (_, _) => const GenieScreen(),
          ),
          GoRoute(
            path: 'split-payment',
            builder: (_, _) => const SplitPaymentScreen(),
          ),
          GoRoute(
            path: 'events',
            builder: (_, _) => const EventListScreen(),
          ),
          GoRoute(
            path: 'events/:slug',
            builder: (_, state) => EventDetailScreen(
              slug: state.pathParameters['slug']!,
            ),
          ),
          GoRoute(
            path: 'events/:id/scan',
            builder: (_, state) => HostScannerScreen(
              eventId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'events/:id/attendees',
            builder: (_, state) => AttendeesScreen(
              eventId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'ticket/:bookingId',
            builder: (_, state) => TicketScreen(
              bookingId: state.pathParameters['bookingId']!,
            ),
          ),
          GoRoute(
            path: 'experiences',
            builder: (_, _) => const ExperiencesScreen(),
          ),
          // ── Equipment rental screens ──
          GoRoute(
            path: 'equipment',
            builder: (_, _) => const EquipmentBrowseScreen(),
          ),
          GoRoute(
            path: 'equipment/my-rentals',
            builder: (_, _) => const MyEquipmentRentalsScreen(),
          ),
          GoRoute(
            path: 'equipment/:itemId',
            builder: (_, state) => EquipmentDetailScreen(
              item: state.extra as ConsumerEquipmentItemModel,
            ),
          ),
          // ── Party services marketplace ──
          GoRoute(
            path: 'party-services',
            builder: (_, _) => const PartyServicesBrowseScreen(),
          ),
          GoRoute(
            path: 'party-services/my-bookings',
            builder: (_, _) => const MyPartyBookingsScreen(),
          ),
          GoRoute(
            path: 'party-services/:id',
            builder: (_, state) => PartyServiceDetailScreen(
              serviceId: state.pathParameters['id']!,
              service: state.extra as PartyServiceModel?,
            ),
          ),
          GoRoute(
            path: 'stays',
            builder: (_, _) => const HomeShell(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => HomestayDetailScreen(
                  homestayId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'food',
            builder: (_, _) => const HomeShell(),
            routes: [
              GoRoute(
                path: 'vendor/:vendorId',
                builder: (_, state) => FoodScreen(
                  vendorId: state.pathParameters['vendorId']!,
                  vendorName: state.uri.queryParameters['name'],
                  deliveryFee: double.tryParse(
                          state.uri.queryParameters['deliveryFee'] ?? '') ??
                      20.0,
                ),
              ),
              GoRoute(
                path: 'orders',
                builder: (_, _) => const FoodOrderHistoryScreen(),
              ),
              GoRoute(
                path: 'orders/:id',
                builder: (_, state) => FoodOrderDetailScreen(
                  orderId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'essentials',
            builder: (_, _) => const EssentialsScreen(),
            routes: [
              GoRoute(
                path: 'store',
                builder: (_, _) => const EssentialsStoreView(),
              ),
              GoRoute(
                path: 'orders',
                builder: (_, _) => const EssentialsOrderHistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'rides',
            builder: (_, _) => const HomeShell(),
            routes: [
              GoRoute(
                path: 'history',
                builder: (_, _) => const RideHistoryScreen(),
              ),
              GoRoute(
                path: 'saved-locations',
                builder: (_, _) => const SavedLocationsScreen(),
              ),
              GoRoute(
                path: 'emergency-contacts',
                builder: (_, _) => const EmergencyContactsScreen(),
              ),
              GoRoute(
                path: 'scheduled',
                builder: (_, _) => const ScheduledRidesScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => RideTrackingScreen(
                  rideId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'rate',
                    builder: (_, state) => RideRatingScreen(
                      rideId: state.pathParameters['id']!,
                      driverName: state.uri.queryParameters['driver'] ?? 'Driver',
                    ),
                  ),
                  GoRoute(
                    path: 'receipt',
                    builder: (_, state) => RideReceiptScreen(
                      rideId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'trip/:token',
            builder: (_, state) => TripShareScreen(
              token: state.pathParameters['token']!,
            ),
          ),
          GoRoute(
            path: 'profile',
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'addresses',
            builder: (_, _) => const SavedAddressesScreen(),
          ),
          GoRoute(
            path: 'map-picker',
            builder: (_, _) => const MapPickerScreen(),
          ),
          GoRoute(
            path: 'tickets',
            builder: (_, _) => const TicketWalletScreen(),
          ),
          GoRoute(
            path: 'wallet',
            builder: (_, _) => const ConsumerWalletScreen(),
          ),
          GoRoute(
            path: 'change-phone',
            builder: (_, _) => const ChangePhoneScreen(),
          ),
          GoRoute(
            path: 'hub',
            builder: (_, _) => const HomeShell(),
          ),
          GoRoute(
            path: 'activity',
            builder: (_, _) => const HomeShell(),
            routes: [
              GoRoute(
                path: 'stay/:id',
                builder: (_, state) => StayReceiptScreen(
                  bookingId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          // Deep-link aliases for activity hub entries. These redirect
          // /activity/food/:id and /activity/ride/:id to the canonical
          // detail screens so FCM notifications and shared links work.
          GoRoute(
            path: 'activity/food/:id',
            builder: (_, state) => FoodOrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'activity/ride/:id',
            builder: (_, state) => RideTrackingScreen(
              rideId: state.pathParameters['id']!,
            ),
          ),
          // Deep-link alias for shared venue URLs: https://pyconnect.run.place/venue/:id
          GoRoute(
            path: 'venue/:id',
            builder: (_, state) => VenueDetailScreen(
              venueId: state.pathParameters['id']!,
            ),
          ),
          // Deep-link alias for shared restaurant URLs: https://pyconnect.run.place/restaurant/:id
          GoRoute(
            path: 'restaurant/:id',
            builder: (_, state) => FoodScreen(
              vendorId: state.pathParameters['id']!,
              vendorName: state.uri.queryParameters['name'],
              deliveryFee: double.tryParse(
                      state.uri.queryParameters['deliveryFee'] ?? '') ??
                  20.0,
            ),
          ),
          GoRoute(
            path: 'rentals',
            builder: (_, _) => const HomeShell(),
          ),
          GoRoute(
            path: 'help',
            builder: (_, _) => const HelpScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Re-evaluates the redirect list whenever auth state changes.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}