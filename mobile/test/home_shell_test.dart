import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pondyconnect/shell/home_shell.dart';
import 'package:pondyconnect/features/food/presentation/restaurant_list_screen.dart';
import 'package:pondyconnect/features/rides/presentation/rides_screen.dart';
import 'package:pondyconnect/core/navigation/floating_nav_bar.dart';
import 'helpers/mock_api_client.dart';
import 'helpers/test_overrides.dart';

void main() {
  group('Home Shell', () {
    Future<void> pumpHomeShell(
      WidgetTester tester, {
      String initialLocation = '/',
      MockApiClient? mock,
    }) async {
      // Use a larger surface to avoid layout overflow from ContextualHome
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HomeShell(),
            routes: [
              GoRoute(path: 'food', builder: (_, _) => const RestaurantListScreen()),
              GoRoute(path: 'rides', builder: (_, _) => const RideHailingScreen()),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(mock: mock),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // Use pump with duration instead of pumpAndSettle because the
      // IndexedStack renders RideHailingScreen which contains a flutter_map
      // that makes HTTP tile requests with pending timers.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('all 6 navigation destinations are present', (tester) async {
      await pumpHomeShell(tester);

      final navBar = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
      expect(navBar.destinations.length, 6);
    });

    testWidgets('SOS FAB is not shown on home shell', (tester) async {
      await pumpHomeShell(tester);

      // SOS should only appear during active rides/orders, not on the home shell
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.sos), findsNothing);
    });

    testWidgets('tapping Food nav switches to Food screen', (tester) async {
      await pumpHomeShell(tester);

      // Tap "Food" destination
      await tester.tap(find.text('Food'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // RestaurantListScreen should be visible
      expect(find.byType(RestaurantListScreen), findsOneWidget);
      expect(find.text('Food Delivery'), findsOneWidget);
    });
  });
}
