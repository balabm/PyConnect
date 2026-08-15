import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pondyconnect/features/venues/presentation/venue_list_screen.dart';
import '../../helpers/mock_api_client.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('Venue List Screen', () {
    Future<void> pumpVenueListScreen(
      WidgetTester tester, {
      MockApiClient? mock,
    }) async {
      // Use a taller surface so all venue cards are visible without scrolling
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(mock: mock),
          child: const MaterialApp(home: VenueListScreen()),
        ),
      );
      // Use pump with duration instead of pumpAndSettle to avoid
      // pending timer issues with staggered animations.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('venue list renders cards with venue names', (tester) async {
      await pumpVenueListScreen(tester);

      expect(find.text('Bon Appétit'), findsOneWidget);
      expect(find.text('The Lighthouse Bar'), findsOneWidget);
      // Surf Café may be off-screen but should be in the widget tree
      expect(find.text('Surf Café'), findsWidgets);
    });

    testWidgets('venue with 80% occupancy shows Packed vibe badge', (tester) async {
      await pumpVenueListScreen(tester);

      // The Lighthouse Bar has occupancy 80 → Vibe.packed (label: "Packed · 80% full")
      expect(find.text('Packed · 80% full'), findsOneWidget);
      // Bon Appétit has occupancy 50 → Vibe.alive (label: "Lively · 50% full")
      expect(find.text('Lively · 50% full'), findsOneWidget);
      // Surf Café has occupancy 20 → Vibe.quiet (label: "Chill · 20% full")
      expect(find.text('Chill · 20% full'), findsOneWidget);
    });

    testWidgets('search filters venues by name', (tester) async {
      await pumpVenueListScreen(tester);

      // Type "bon" in search box
      await tester.enterText(find.byType(TextField).first, 'bon');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Bon Appétit'), findsOneWidget);
      expect(find.text('The Lighthouse Bar'), findsNothing);
    });

    testWidgets('category filter shows only matching venues', (tester) async {
      await pumpVenueListScreen(tester);

      // Tap "Cafe" filter pill — it's a GestureDetector with text "Cafe"
      await tester.tap(find.text('Cafe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show 2 cafes: Bon Appétit and Surf Café
      expect(find.text('Bon Appétit'), findsOneWidget);
      expect(find.text('Surf Café'), findsOneWidget);
      expect(find.text('The Lighthouse Bar'), findsNothing);
    });

    testWidgets('API error shows error state with retry', (tester) async {
      final mock = MockApiClient();
      mock.throwOnNext = true;

      await pumpVenueListScreen(tester, mock: mock);

      // ErrorState widget shows "Something went wrong" and a Retry button
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
