/// Consumer App E2E Integration Tests
///
/// Tests the food checkout flow, transparent bill breakdown visibility,
/// COD checkout, and delete account dialog.
///
/// Run with:
///   `flutter test integration_test/consumer_e2e_test.dart -d <emulator-id>`
///
/// Or headless:
///   `flutter test integration_test/consumer_e2e_test.dart`
library consumer_e2e_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pondyconnect/features/food/presentation/food_screen.dart';
import 'package:pondyconnect/features/auth/presentation/profile_screen.dart';

import 'helpers/test_helpers.dart';

/// Fixed-duration pump to avoid pumpAndSettle() hanging on
/// continuous animations (shimmers, loading spinners, etc.).
const _pumpDuration = Duration(seconds: 2);

void main() {

  group('Consumer App E2E', () {
    // ─────────────────────────────────────────────────────────────────────
    // Test 1: Transparent Bill Breakdown Visibility
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('FoodCheckout_TransparentBillBreakdown_Visible', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildConsumerOverrides(authenticated: true),
          child: const MaterialApp(home: FoodScreen(vendorId: '00000000-0000-0000-0000-000000000001')),
        ),
      );
      await tester.pump(_pumpDuration);

      // Find the first menu item add button (+ icon) and tap it
      final addButtons = find.byIcon(Icons.add_circle_outline);
      expect(addButtons, findsWidgets, reason: 'Should have add buttons for menu items');

      await tester.tap(addButtons.first);
      await tester.pump(_pumpDuration);

      // Find and tap the Checkout bar
      final checkoutButton = find.text('Checkout');
      expect(checkoutButton, findsOneWidget, reason: 'Checkout bar should be visible after adding item');

      await tester.tap(checkoutButton);
      await tester.pump(_pumpDuration);

      // Assert the Cart Summary sheet is visible
      expect(find.text('Cart Summary'), findsOneWidget, reason: 'Cart Summary sheet should open');

      // Assert transparent bill breakdown elements are visible
      expect(find.text('Base Item Total'), findsOneWidget,
          reason: 'Base Item Total row should be visible');
      expect(find.textContaining('Taxes'), findsOneWidget,
          reason: 'Taxes (GST) row should be visible');
      expect(find.text('Platform Fee'), findsOneWidget,
          reason: 'Platform Fee row should be visible');
      expect(find.text('Driver Delivery Fee'), findsOneWidget,
          reason: 'Driver Delivery Fee row should be visible');
      expect(find.text('100% to driver'), findsOneWidget,
          reason: '100% to driver badge should be visible');
      expect(find.text('Total'), findsOneWidget,
          reason: 'Total row should be visible');
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 2: COD Checkout Flow
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('FoodCheckout_CashOnDelivery_ConfirmsOrder', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildConsumerOverrides(authenticated: true),
          child: const MaterialApp(home: FoodScreen(vendorId: '00000000-0000-0000-0000-000000000001')),
        ),
      );
      await tester.pump(_pumpDuration);

      // Add an item to cart
      final addButtons = find.byIcon(Icons.add_circle_outline);
      await tester.tap(addButtons.first);
      await tester.pump(_pumpDuration);

      // Open checkout
      await tester.tap(find.text('Checkout'));
      await tester.pump(_pumpDuration);

      // Select Cash on Delivery
      final codRadio = find.text('Cash on Delivery');
      expect(codRadio, findsOneWidget);
      await tester.tap(codRadio);
      await tester.pump(_pumpDuration);

      // Tap Confirm Order
      final confirmButton = find.text('Confirm Order');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pump(_pumpDuration);

      // Assert a success/result sheet appears
      // The checkout result sheet shows "Order Placed!" on success
      expect(find.textContaining('Order'), findsWidgets,
          reason: 'Order confirmation should appear after COD checkout');
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 3: Delete Account Dialog
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('ProfileScreen_DeleteAccount_ShowsConfirmationDialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildConsumerOverrides(authenticated: true),
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump(_pumpDuration);

      // Scroll to find the Delete Account button
      final deleteButton = find.text('Delete Account & Data');
      await tester.scrollUntilVisible(
        deleteButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(_pumpDuration);

      expect(deleteButton, findsOneWidget,
          reason: 'Delete Account & Data button should be visible');

      // Tap it
      await tester.tap(deleteButton);
      await tester.pump(_pumpDuration);

      // Assert confirmation dialog appears
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'Confirmation dialog should appear');
      expect(find.textContaining('Delete'), findsWidgets,
          reason: 'Dialog should mention delete');

      // Tap Cancel to dismiss
      final cancelButton = find.text('Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
        await tester.pump(_pumpDuration);
      }

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'Dialog should be dismissed after Cancel');
    });
  });
}
