import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pondyconnect/features/transit/presentation/transit_screen.dart';
import '../../helpers/mock_api_client.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('Transit Screen', () {
    Future<void> pumpTransitScreen(
      WidgetTester tester, {
      bool authenticated = false,
      MockApiClient? mock,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(authenticated: authenticated, mock: mock),
          child: const MaterialApp(home: TransitScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('transit hubs load and display on Pickups tab', (tester) async {
      await pumpTransitScreen(tester, authenticated: true);

      expect(find.text('Pondicherry Bus Stand'), findsOneWidget);
      expect(find.text('Pondicherry Airport'), findsOneWidget);
    });

    testWidgets('tab switching to Luggage shows luggage content', (tester) async {
      await pumpTransitScreen(tester, authenticated: true);

      // Tap "Luggage" navigation destination
      await tester.tap(find.text('Luggage'));
      await tester.pumpAndSettle();

      expect(find.text('Luggage Cloak Network'), findsOneWidget);
    });

    testWidgets('tab switching to Mobility shows mobility content', (tester) async {
      await pumpTransitScreen(tester, authenticated: true);

      // Tap "Mobility" navigation destination
      await tester.tap(find.text('Mobility'));
      await tester.pumpAndSettle();

      expect(find.text('Hyper-local Mobility'), findsOneWidget);
    });

    testWidgets('unauthenticated state shows login prompt on Luggage tab', (tester) async {
      await pumpTransitScreen(tester, authenticated: false);

      // Tap "Luggage" tab
      await tester.tap(find.text('Luggage'));
      await tester.pumpAndSettle();

      expect(find.text('Log in to book luggage storage near your arrival hub.'), findsOneWidget);
    });

    testWidgets('unauthenticated state shows login prompt on Mobility tab', (tester) async {
      await pumpTransitScreen(tester, authenticated: false);

      // Tap "Mobility" tab
      await tester.tap(find.text('Mobility'));
      await tester.pumpAndSettle();

      expect(find.text('Log in to book scooter rentals.'), findsOneWidget);
    });
  });
}
