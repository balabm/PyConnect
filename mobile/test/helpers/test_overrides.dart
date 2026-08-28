import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pondyconnect/core/providers.dart';
import 'package:pondyconnect/core/theme/theme_controller.dart';
import 'package:pondyconnect/features/auth/application/auth_controller.dart';
import 'package:pondyconnect/features/auth/data/auth_api.dart';
import 'package:pondyconnect/features/bookings/data/booking_api.dart';
import 'package:pondyconnect/features/food/data/food_api.dart';
import 'package:pondyconnect/features/public/data/public_api.dart';
import 'package:pondyconnect/features/rides/data/rides_api.dart';
import 'package:pondyconnect/features/stays/data/stays_api.dart';
import 'package:pondyconnect/features/support/data/support_api.dart';
import 'package:pondyconnect/features/transit/data/luggage_api.dart';
import 'package:pondyconnect/features/transit/data/rental_api.dart';
import 'package:pondyconnect/features/transit/data/transit_api.dart';
import 'package:pondyconnect/features/vendor/data/vendor_api.dart';
import 'package:pondyconnect/features/venues/data/venue_api.dart';
import 'fake_token_storage.dart';
import 'mock_api_client.dart';
import 'mock_osm_services.dart';

/// Builds a list of provider overrides for use in ProviderScope.
///
/// [authenticated] — when true, overrides authControllerProvider to return
/// a test AuthSession so screens that depend on auth state work.
/// [mock] — the MockApiClient instance to use. If null, a new one is created.
List<Override> buildOverrides({
  bool authenticated = false,
  MockApiClient? mock,
}) {
  final client = mock ?? MockApiClient();

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
    geocodingProvider.overrideWith((ref) => MockGeocodingService()),
    routingProvider.overrideWith((ref) => MockRoutingService()),
    themeControllerProvider.overrideWith((ref) => _FakeThemeController()),
    if (authenticated)
      authControllerProvider.overrideWith(() => _FakeAuthController()),
  ];
}

/// An AuthController that immediately returns a test session without
/// hitting the network.
class _FakeAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async {
    return AuthSession(
      name: 'Test User',
      phone: '9000000099',
      role: 'Tourist',
      token: 'test-token',
      isProMember: false,
    );
  }
}

/// A ThemeController that doesn't touch FlutterSecureStorage (which is
/// unavailable in widget tests). The _NullStorage returns null for all reads
/// and ignores all writes, so the controller defaults to system mode.
class _FakeThemeController extends ThemeController {
  _FakeThemeController() : super(_NullStorage());
}

/// A no-op secure storage that returns null for reads and ignores writes.
/// Uses noSuchMethod to satisfy the FlutterSecureStorage interface without
/// needing to match every platform-specific named parameter.
class _NullStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) async {
    if (invocation.memberName == const Symbol('read')) return null;
    return null;
  }
}
