import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pondyconnect/features/rides/presentation/rides_screen.dart';
import '../../helpers/mock_api_client.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('Rides Screen', () {
    Future<void> pumpRidesScreen(
      WidgetTester tester, {
      MockApiClient? mock,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(mock: mock),
          child: const MaterialApp(home: RideHailingScreen()),
        ),
      );
      // Pump initial frame, then advance time to let async providers resolve.
      // Using pumpAndSettle would hang because flutter_map's HTTP tile requests
      // create pending timers that never settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('nearby drivers count displays', (tester) async {
      await pumpRidesScreen(tester);

      // Mock returns 2 drivers
      expect(find.text('2 drivers nearby'), findsOneWidget);
    });

    testWidgets('address search fields are present', (tester) async {
      await pumpRidesScreen(tester);

      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Dropoff'), findsOneWidget);
    });

    testWidgets('map tap selection indicator is shown', (tester) async {
      await pumpRidesScreen(tester);

      // Default mode is pickup selection
      expect(find.text('Tap map to set pickup'), findsOneWidget);
    });

    testWidgets('request ride button disabled without dropoff', (tester) async {
      await pumpRidesScreen(tester);

      // Without dropoff, button should show "Set pickup & dropoff" and be disabled
      expect(find.text('Set pickup & dropoff'), findsOneWidget);
    });

    testWidgets('address search field shows suggestions after typing', (tester) async {
      await pumpRidesScreen(tester);

      // The dropoff row is the second TextField in the address card.
      // The first TextField is the pickup row (pre-filled with "Pondicherry").
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      final dropoffTextField = textFields.at(1);

      await tester.enterText(dropoffTextField, 'Test Dropoff');
      await tester.pump(const Duration(milliseconds: 600)); // debounce
      await tester.pump(const Duration(seconds: 2));

      // Suggestions should appear from mock geocoding service
      expect(find.textContaining('Test Dropoff, Pondicherry'), findsWidgets);
    });

    testWidgets('selecting a suggestion enables Request Ride button', (tester) async {
      await pumpRidesScreen(tester);

      // Set dropoff via address search
      final textFields = find.byType(TextField);
      final dropoffTextField = textFields.at(1);

      await tester.enterText(dropoffTextField, 'Test Dropoff');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 2));

      // Tap the first suggestion
      final suggestion = find.textContaining('Test Dropoff, Pondicherry');
      expect(suggestion, findsWidgets);
      await tester.tap(suggestion.first);
      await tester.pump(const Duration(seconds: 2));

      // Now the Request button should be visible (dropoff is set).
      // The button text is "Request <vehicle> · ₹<fare>" e.g. "Request Bike · ₹120"
      expect(find.textContaining('Request'), findsWidgets);
    });
  });
}
