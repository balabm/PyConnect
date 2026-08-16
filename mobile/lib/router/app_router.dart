import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/phone_entry_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/change_phone_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/bookings/presentation/booking_screen.dart';
import '../features/essentials/presentation/essentials_order_history_screen.dart';
import '../features/essentials/presentation/essentials_screen.dart';
import '../features/essentials/presentation/essentials_store_view.dart';
import '../features/experiences/presentation/experiences_screen.dart';
import '../features/food/presentation/food_order_detail_screen.dart';
import '../features/food/presentation/food_order_history_screen.dart';
import '../features/food/presentation/food_screen.dart';
import '../features/food/presentation/restaurant_list_screen.dart';
import '../features/hub/services_hub_screen.dart';
import '../features/activity/presentation/activity_hub_screen.dart';
import '../features/activity/presentation/stay_receipt_screen.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/rides/presentation/ride_history_screen.dart';
import '../features/rides/presentation/ride_rating_screen.dart';
import '../features/rides/presentation/ride_receipt_screen.dart';
import '../features/rides/presentation/ride_tracking_screen.dart';
import '../features/rides/presentation/rides_screen.dart';
import '../features/rides/presentation/saved_locations_screen.dart';
import '../features/rides/presentation/scheduled_rides_screen.dart';
import '../features/rides/presentation/emergency_contacts_screen.dart';
import '../features/rides/presentation/trip_share_screen.dart';
import '../features/transit/presentation/transit_screen.dart';
import '../features/stays/presentation/homestay_detail_screen.dart';
import '../features/stays/presentation/stays_screen.dart';
import '../features/support/presentation/help_screen.dart';
import '../features/venues/data/venue_api.dart';
import '../features/venues/presentation/venue_detail_screen.dart';
import '../features/venues/presentation/venue_list_screen.dart';
import '../shell/home_shell.dart';
import '../core/providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) {
      final authenticated = ref.read(authControllerProvider).valueOrNull?.isAuthenticated ?? false;
      final hasSeenAuth = ref.read(hasSeenAuthScreenProvider);
      final path = state.matchedLocation;

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
            builder: (_, _) => const TransitScreen(),
          ),
          GoRoute(
            path: 'experiences',
            builder: (_, _) => const ExperiencesScreen(),
          ),
          GoRoute(
            path: 'stays',
            builder: (_, _) => const StaysScreen(),
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
            builder: (_, _) => const RestaurantListScreen(),
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
            builder: (_, _) => const RideHailingScreen(),
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
            path: 'change-phone',
            builder: (_, _) => const ChangePhoneScreen(),
          ),
          GoRoute(
            path: 'hub',
            builder: (_, _) => const ServicesHubScreen(),
          ),
          GoRoute(
            path: 'activity',
            builder: (_, _) => const ActivityHubScreen(),
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
          GoRoute(
            path: 'rentals',
            builder: (_, _) => const TransitScreen(),
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