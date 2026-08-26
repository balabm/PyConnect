import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/api_client.dart';
import 'network/offline_mutation_queue.dart';
import 'network/osm_geocoding_service.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'network/osrm_routing_service.dart';
import 'services/gps_buffer_service.dart';
import '../features/driver/application/driver_providers.dart';
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
import '../features/auth/application/vendor_auth_controller.dart';
import '../features/food/data/food_api.dart';
import '../features/essentials/data/essentials_api.dart';
import '../features/rides/data/rides_api.dart';
import '../features/public/data/public_api.dart';
import '../features/stays/data/stays_api.dart';
import '../features/support/data/support_api.dart';
import '../features/admin/data/admin_api.dart';
import '../features/wallet/data/user_wallet_api.dart';

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
      ref.invalidate(vendorAuthControllerProvider);
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
final userWalletApiProvider = Provider<UserWalletApi>((ref) => UserWalletApi(ref.watch(apiClientProvider)));

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

/// SignalR client for real-time vendor status updates. The consumer app
/// listens to "VendorStatusChanged" events to instantly grey out vendor
/// cards and disable "Add to Cart" when a vendor stops accepting orders.
/// No auth required — guests can browse vendors.
final vendorStatusHubProvider = Provider<SignalRClient>((ref) {
  return SignalRClient(
    hubPath: '/hubs/vendor',
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

/// Real-time vendor status map. Keys are vendor IDs (strings), values are
/// `true` when the vendor is accepting orders. Updated instantly via SignalR
/// "VendorStatusChanged" events so the consumer app can grey out cards and
/// disable "Add to Cart" without a page refresh.
final vendorAcceptingOrdersProvider =
    StateNotifierProvider<VendorAcceptingOrdersNotifier, Map<String, bool>>(
  (ref) => VendorAcceptingOrdersNotifier(ref),
);

class VendorAcceptingOrdersNotifier extends StateNotifier<Map<String, bool>> {
  VendorAcceptingOrdersNotifier(this._ref) : super({}) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<List<Object?>>? _sub;

  Future<void> _init() async {
    final hub = _ref.read(vendorStatusHubProvider);
    try {
      await hub.connect();
    } catch (_) {
      // Connection will auto-retry; non-fatal.
    }
    _sub = hub.on('VendorStatusChanged').listen((args) {
      if (args.isEmpty) return;
      final payload = args.first as Map<String, dynamic>?;
      if (payload == null) return;
      final vendorId = payload['vendorId'] as String?;
      final isAccepting = payload['isAcceptingOrders'] as bool?;
      if (vendorId == null || isAccepting == null) return;
      state = {...state, vendorId: isAccepting};
    });
  }

  /// Seeds the initial status from the vendor list API response so cards
  /// are correct before any SignalR events arrive.
  void seedFromVendorList(List<dynamic> vendors) {
    final map = <String, bool>{};
    for (final v in vendors) {
      final vendor = v as Map<String, dynamic>;
      final id = vendor['id'] as String?;
      if (id != null) {
        map[id] = vendor['isAcceptingOrders'] as bool? ?? true;
      }
    }
    state = {...state, ...map};
  }

  /// Returns whether a specific vendor is currently accepting orders.
  /// Defaults to `true` if no SignalR update has been received yet.
  bool isAccepting(String vendorId) => state[vendorId] ?? true;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// SharedPreferences instance for the offline mutation queue and other
/// lightweight persistence needs.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Internet connection status stream for the Captain (driver) app.
/// Emits [InternetConnectionStatus.connected] whenever the device regains
/// internet access so the offline queue can be flushed.
final internetConnectionCheckerProvider =
    StreamProvider<InternetConnectionStatus>((ref) {
  return InternetConnectionChecker().onStatusChange;
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

  // Flush the queue when the connection comes back online.
  ref.listen<AsyncValue<InternetConnectionStatus>>(
    internetConnectionCheckerProvider,
    (previous, next) {
      if (next.value == InternetConnectionStatus.connected) {
        queue.flush();
      }
    },
  );

  // Watch the auth token — when it changes, try to flush the queue.
  ref.watch(authTokenProvider);
  return queue;
});

/// GPS buffer service for the Captain app. Buffers GPS pings in
/// SharedPreferences when the device loses connectivity (cell handover,
/// dead zones) and flushes them when 4G is restored.
final gpsBufferServiceProvider = Provider<GpsBufferService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
        data: (p) => p,
        orElse: () => throw StateError('SharedPreferences not ready'),
      );
  final driverApi = ref.watch(driverApiProvider);

  final buffer = GpsBufferService(
    prefs,
    (lat, lng, {double? heading}) async {
      try {
        await driverApi.updateLocation(lat, lng);
        return true;
      } catch (_) {
        return false;
      }
    },
  );

  // Flush the buffer when connection comes back online.
  ref.listen<AsyncValue<InternetConnectionStatus>>(
    internetConnectionCheckerProvider,
    (previous, next) {
      if (next.value == InternetConnectionStatus.connected) {
        buffer.flush();
      }
    },
  );

  return buffer;
});