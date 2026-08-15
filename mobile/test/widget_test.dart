import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pondyconnect/app.dart';
import 'package:pondyconnect/core/network/api_client.dart';
import 'package:pondyconnect/core/providers.dart';
import 'package:pondyconnect/core/theme/theme_controller.dart';
import 'package:pondyconnect/features/venues/application/venue_controller.dart';
import 'package:pondyconnect/features/venues/data/venue_api.dart';
import 'package:pondyconnect/features/venues/presentation/vibe.dart';

void main() {
  group('Vibe classification', () {
    test('Is quiet below 40% occupancy', () {
      expect(Vibe.fromOccupancy(20), Vibe.quiet);
    });

    test('Is alive between 40-74%', () {
      expect(Vibe.fromOccupancy(40), Vibe.alive);
      expect(Vibe.fromOccupancy(74), Vibe.alive);
    });

    test('Is packed at 75% and above', () {
      expect(Vibe.fromOccupancy(75), Vibe.packed);
      expect(Vibe.fromOccupancy(100), Vibe.packed);
    });
  });

  testWidgets('App boots past the provider root', (WidgetTester tester) async {
    // Use a larger surface to avoid layout overflow from ContextualHome
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overrides = <Override>[
      apiClientProvider.overrideWith((ref) => _StubApiClient()),
      venueApiProvider.overrideWith((ref) => VenueApi(ref.watch(apiClientProvider))),
      themeControllerProvider.overrideWith((ref) => _FakeThemeController()),
      // Override venueListProvider to avoid the 30-second poll timer
      venueListProvider.overrideWith(() => _NoPollVenueListController()),
    ];
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const PondyConnectApp()),
    );
    await tester.pump();
    // Pump enough time for staggered animations to complete
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProviderScope), findsOneWidget);

    // Unmount so the poller Timer is cancelled via ref.onDispose.
    await tester.pumpWidget(const SizedBox());
    // Pump to allow timers to be cancelled
    await tester.pump(const Duration(seconds: 1));
  });
}

/// Fails immediately so tests never touch the network or dio timers.
class _StubApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) {
    throw ApiException('stubbed');
  }
}

/// A VenueListController that doesn't start a poll timer.
class _NoPollVenueListController extends VenueListController {
  @override
  Future<List<Venue>> build() async {
    // Don't start the poll timer — just return empty list
    return [];
  }
}

/// A ThemeController that doesn't touch FlutterSecureStorage (which is
/// unavailable in widget tests).
class _FakeThemeController extends ThemeController {
  _FakeThemeController() : super(_NullStorage());
}

class _NullStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) async {
    if (invocation.memberName == const Symbol('read')) return null;
    return null;
  }
}