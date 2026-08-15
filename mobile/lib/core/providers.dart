import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/api_client.dart';
import 'network/offline_mutation_queue.dart';
import 'network/osm_geocoding_service.dart';
import 'network/osrm_routing_service.dart';
import 'network/signalr_client.dart';
import 'network/location_service.dart';
import 'network/razorpay_payment_service.dart';
import 'storage/token_storage.dart';
import '../features/venues/data/venue_api.dart';
import '../features/transit/data/transit_api.dart';
import '../features/transit/data/luggage_api.dart';
import '../features/transit/data/rental_api.dart';
import '../features/vendor/data/vendor_api.dart';
import '../features/vendor/data/vendor_onboarding_api.dart';
import '../features/bookings/data/booking_api.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/food/data/food_api.dart';
import '../features/essentials/data/essentials_api.dart';
import '../features/rides/data/rides_api.dart';
import '../features/public/data/public_api.dart';
import '../features/stays/data/stays_api.dart';
import '../features/support/data/support_api.dart';
import '../features/admin/data/admin_api.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  late ApiClient client;
  client = ApiClient(
    onUnauthorized: () {
      // Clear the in-memory token on the Dio client itself so subsequent
      // requests don't keep sending the stale bearer token.
      client.setToken(null);
      ref.read(tokenStorageProvider).clear();
      ref.read(authTokenProvider.notifier).state = null;
      // Invalidate auth so the router redirect sends the user to /auth.
      ref.invalidate(authControllerProvider);
    },
    onTokenRefreshed: (newToken) async {
      // Persist the refreshed token so it survives app restarts.
      client.setToken(newToken);
      await ref.read(tokenStorageProvider).write(newToken);
      ref.read(authTokenProvider.notifier).state = newToken;
    },
  );
  return client;
});

final tokenStorageProvider =
    Provider<TokenStorage>((ref) => TokenStorage());

final authTokenProvider = StateProvider<String?>((ref) => null);

/// Stores the route the user was trying to access before being redirected to
/// the auth flow. Cleared once the user authenticates and is returned.
final pendingAuthRedirectProvider = StateProvider<String?>((ref) => null);

/// Tracks whether the user has seen the auth/login screen on this launch.
/// The app redirects to /auth on first launch. Once the user logs in or
/// taps "Continue as Guest", this is set to true and they won't be
/// redirected again during the session.
final hasSeenAuthScreenProvider = StateProvider<bool>((ref) => false);

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));
final venueApiProvider = Provider<VenueApi>((ref) => VenueApi(ref.watch(apiClientProvider)));
final transitApiProvider = Provider<TransitApi>((ref) => TransitApi(ref.watch(apiClientProvider)));
final luggageApiProvider = Provider<LuggageApi>((ref) => LuggageApi(ref.watch(apiClientProvider)));
final rentalApiProvider = Provider<RentalApi>((ref) => RentalApi(ref.watch(apiClientProvider)));
final vendorApiProvider = Provider<VendorApi>((ref) => VendorApi(ref.watch(apiClientProvider)));
final bookingApiProvider = Provider<BookingApi>((ref) => BookingApi(ref.watch(apiClientProvider)));
final foodApiProvider = Provider<FoodDeliveryApi>((ref) => FoodDeliveryApi(ref.watch(apiClientProvider)));
final essentialsApiProvider = Provider<QuickCommerceApi>((ref) => QuickCommerceApi(ref.watch(apiClientProvider)));
final ridesApiProvider = Provider<RideHailingApi>((ref) => RideHailingApi(ref.watch(apiClientProvider)));
final staysApiProvider = Provider<StaysApi>((ref) => StaysApi(ref.watch(apiClientProvider)));
final supportApiProvider = Provider<SupportApi>((ref) => SupportApi(ref.watch(apiClientProvider)));
final publicApiProvider = Provider<PublicApi>((ref) => PublicApi(ref.watch(apiClientProvider)));
final adminApiProvider = Provider<AdminApi>((ref) => AdminApi(ref.watch(apiClientProvider)));
final vendorOnboardingApiProvider = Provider<VendorOnboardingApi>((ref) => VendorOnboardingApi(ref.watch(apiClientProvider)));

/// SignalR clients for real-time ride updates (rider-facing) and driver hub.
final rideHubProvider = Provider<SignalRClient>((ref) {
  return SignalRClient(
    hubPath: '/hubs/ride',
    tokenProvider: () => ref.read(authTokenProvider),
  );
});

final driverHubProvider = Provider<SignalRClient>((ref) {
  return SignalRClient(
    hubPath: '/hubs/driver',
    tokenProvider: () => ref.read(authTokenProvider),
  );
});

/// OSM Nominatim geocoding service for address search + reverse geocoding.
final geocodingProvider = Provider<OsmGeocodingService>((ref) => OsmGeocodingService());

/// OSRM routing service for road distance, duration, and route polyline.
final routingProvider = Provider<OsrmRoutingService>((ref) => OsrmRoutingService());

/// Device GPS location service.
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// Razorpay payment service for checkout flows.
final razorpayPaymentProvider = Provider<RazorpayPaymentService>((ref) {
  return RazorpayPaymentService(ref.watch(apiClientProvider));
});

/// Global cart item count provider shared between food screen and home badge.
final cartItemCountProvider = StateProvider<int>((ref) => 0);

/// SharedPreferences instance for the offline mutation queue and other
/// lightweight persistence needs.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Offline mutation queue for the Captain (driver) app. When a driver taps
/// "Complete Trip" or "Arrived" and the network is down, the mutation is
/// queued and replayed when connectivity is restored.
final offlineMutationQueueProvider = Provider<OfflineMutationQueue>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
        data: (p) => p,
        orElse: () => throw StateError('SharedPreferences not ready'),
      );
  final apiClient = ref.watch(apiClientProvider);

  final queue = OfflineMutationQueue(
    prefs,
    (mutation) async {
      try {
        await apiClient.post(mutation.path, data: mutation.body);
        return true;
      } catch (e) {
        if (e is Exception) rethrow;
        return false;
      }
    },
  );

  // Watch the auth token — when it changes, try to flush the queue.
  ref.watch(authTokenProvider);
  return queue;
});