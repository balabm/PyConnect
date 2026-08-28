/// Shared helpers for PY Connect integration tests.
///
/// Provides provider overrides for all three apps (Consumer, Captain, Partner)
/// so integration tests can run against mock data without hitting the network
/// or native platform channels (Razorpay, Geolocator, etc.).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pondyconnect/core/network/offline_mutation_queue.dart';
import 'package:pondyconnect/core/providers.dart';
import 'package:pondyconnect/core/theme/theme_controller.dart';
import 'package:pondyconnect/features/auth/application/auth_controller.dart';
import 'package:pondyconnect/features/auth/application/vendor_auth_controller.dart';
import 'package:pondyconnect/features/auth/data/auth_api.dart';
import 'package:pondyconnect/features/bookings/data/booking_api.dart';
import 'package:pondyconnect/features/driver/application/driver_providers.dart';
import 'package:pondyconnect/features/driver/domain/driver_models.dart';
import 'package:pondyconnect/features/food/data/food_api.dart';
import 'package:pondyconnect/features/public/data/public_api.dart';
import 'package:pondyconnect/features/rides/data/rides_api.dart';
import 'package:pondyconnect/features/stays/data/stays_api.dart';
import 'package:pondyconnect/features/support/data/support_api.dart';
import 'package:pondyconnect/features/transit/data/luggage_api.dart';
import 'package:pondyconnect/features/transit/data/rental_api.dart';
import 'package:pondyconnect/features/transit/data/transit_api.dart';
import 'package:pondyconnect/features/vendor/application/vendor_providers.dart';
import 'package:pondyconnect/features/vendor/data/vendor_api.dart';
import 'package:pondyconnect/features/venues/data/venue_api.dart';

import 'fake_overrides.dart';

/// Builds a list of provider overrides for the Consumer app.
///
/// [authenticated] — when true, overrides authControllerProvider to return
/// a test AuthSession so screens that depend on auth state work.
/// [mock] — the FakeApiClient instance to use. If null, a new one is created.
List<Override> buildConsumerOverrides({
  bool authenticated = false,
  FakeApiClient? mock,
}) {
  final client = mock ?? FakeApiClient();

  return [
    apiClientProvider.overrideWith((ref) => client),
    tokenStorageProvider.overrideWith((ref) => FakeTokenStorage(
          initialToken: authenticated ? 'test-token' : null,
        )),
    authTokenProvider.overrideWith((ref) => authenticated ? 'test-token' : null),
    authApiProvider.overrideWith((ref) => AuthApi(ref.watch(apiClientProvider))),
    venueApiProvider.overrideWith((ref) => VenueApi(ref.watch(apiClientProvider))),
    transitApiProvider.overrideWith((ref) => TransitApi(ref.watch(apiClientProvider))),
    luggageApiProvider.overrideWith((ref) => LuggageApi(ref.watch(apiClientProvider))),
    rentalApiProvider.overrideWith((ref) => RentalApi(ref.watch(apiClientProvider))),
    vendorApiProvider.overrideWith((ref) => VendorApi(ref.watch(apiClientProvider))),
    bookingApiProvider.overrideWith((ref) => BookingApi(ref.watch(apiClientProvider))),
    foodApiProvider.overrideWith((ref) => FoodDeliveryApi(ref.watch(apiClientProvider))),
    ridesApiProvider.overrideWith((ref) => RideHailingApi(ref.watch(apiClientProvider))),
    staysApiProvider.overrideWith((ref) => StaysApi(ref.watch(apiClientProvider))),
    supportApiProvider.overrideWith((ref) => SupportApi(ref.watch(apiClientProvider))),
    publicApiProvider.overrideWith((ref) => PublicApi(ref.watch(apiClientProvider))),
    themeControllerProvider.overrideWith((ref) => FakeThemeController()),
    if (authenticated)
      authControllerProvider.overrideWith(() => FakeAuthController()),
  ];
}

/// Builds a list of provider overrides for the Captain (driver) app.
///
/// [driverProfile] — the fake driver profile to return. When null, defaults
///   to an approved driver with tutorial + agreement completed.
/// [activeTask] — when non-null, overrides activeTaskProvider so the
///   ActiveTripScreen renders with this task.
/// [mock] — the FakeApiClient instance to use.
/// [offlineQueue] — when non-null, overrides offlineMutationQueueProvider
///   so tests can inspect the queue state.
List<Override> buildDriverOverrides({
  DriverProfileModel? driverProfile,
  DispatchTaskModel? activeTask,
  FakeApiClient? mock,
  OfflineMutationQueue? offlineQueue,
}) {
  final client = mock ?? FakeApiClient();

  return [
    apiClientProvider.overrideWith((ref) => client),
    tokenStorageProvider.overrideWith((ref) => FakeTokenStorage(initialToken: 'driver-token')),
    authTokenProvider.overrideWith((ref) => 'driver-token'),
    driverApiProvider.overrideWith((ref) => FakeDriverApi(client)),
    driverProfileProvider.overrideWith((ref) async => driverProfile ?? _defaultDriverProfile),
    activeTaskProvider.overrideWith((ref) => activeTask),
    driverOnlineStatusProvider.overrideWith((ref) => false),
    sharedPreferencesProvider.overrideWith((ref) async => _fakeSharedPreferences()),
    if (offlineQueue != null)
      offlineMutationQueueProvider.overrideWith((ref) => offlineQueue),
    themeControllerProvider.overrideWith((ref) => FakeThemeController()),
  ];
}

/// Builds a list of provider overrides for the Partner (vendor) app.
///
/// [vendorSession] — the fake vendor auth session. Use a pending session to
///   test the PendingApproval redirect, or an approved session to test the
///   dashboard.
/// [mock] — the FakeApiClient instance to use.
List<Override> buildPartnerOverrides({
  required VendorAuthSession vendorSession,
  FakeApiClient? mock,
}) {
  final client = mock ?? FakeApiClient();

  return [
    apiClientProvider.overrideWith((ref) => client),
    tokenStorageProvider.overrideWith((ref) => FakeTokenStorage(initialToken: vendorSession.accessToken)),
    authTokenProvider.overrideWith((ref) => vendorSession.accessToken),
    vendorAuthControllerProvider.overrideWith(() => FakeVendorAuthController(vendorSession)),
    vendorDashboardApiProvider.overrideWith((ref) => FakeVendorDashboardApi(client)),
    vendorMenuProvider.overrideWith((ref) => FakeVendorMenuNotifier(ref, client)),
    themeControllerProvider.overrideWith((ref) => FakeThemeController()),
  ];
}

/// Default approved driver profile for Captain tests.
final _defaultDriverProfile = DriverProfileModel(
  id: 'driver-test-1',
  name: 'Test Driver',
  phone: '9000000050',
  vehicleType: 'Bike',
  vehiclePlate: 'PY-01-AB-1234',
  isApproved: true,
  isKycUploaded: true,
  hasCompletedTutorial: true,
  hasSignedAgreement: true,
  isOnline: false,
);

/// Returns a SharedPreferences instance with mock initial values.
/// Uses the official SharedPreferences test helper.
Future<SharedPreferences> _fakeSharedPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}
