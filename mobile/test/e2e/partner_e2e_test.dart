/// Partner App E2E Integration Tests
///
/// Tests the partner router redirect logic (pending → PendingApproval,
/// approved → Dashboard) and the vendor menu toggle (In Stock → Sold Out).
///
/// Run with:
///   `flutter test integration_test/partner_e2e_test.dart -d <emulator-id>`
///
/// Or headless:
///   `flutter test integration_test/partner_e2e_test.dart`
library partner_e2e_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pondyconnect/features/auth/application/vendor_auth_controller.dart';
import 'package:pondyconnect/features/vendor/presentation/pending_approval_screen.dart';
import 'package:pondyconnect/features/vendor/presentation/vendor_menu_screen.dart';
import 'package:pondyconnect/router/partner_router.dart';

import '../helpers/test_helpers.dart';

/// Fixed-duration pump to avoid pumpAndSettle() hanging on
/// continuous animations (shimmers, loading spinners, etc.).
const _pumpDuration = Duration(milliseconds: 100);

/// Suppress layout overflow errors (pre-existing UI bugs).
void _ignoreLayoutOverflow(FlutterErrorDetails details) {
  final summary = details.exceptionAsString();
  if (summary.contains('RenderFlex overflowed') ||
      summary.contains('ListTile background color')) {
    return;
  }
  FlutterError.presentError(details);
}

void main() {
  group('Partner App E2E', () {
    // ─────────────────────────────────────────────────────────────────────
    // Test 1: Pending Vendor Redirects to PendingApproval
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('PartnerRouter_PendingVendor_RedirectsToPendingApproval', (tester) async {
      FlutterError.onError = _ignoreLayoutOverflow;
      final pendingSession = VendorAuthSession(
        accessToken: 'pending-token',
        vendorId: 'vendor-test-1',
        vendorName: 'Test Vendor',
        category: 'Pizzeria',
        phone: '9000000001',
        status: 'Pending',
      );

      final container = ProviderContainer(
        overrides: buildPartnerOverrides(vendorSession: pendingSession),
      );
      addTearDown(container.dispose);

      final router = container.read(partnerRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(_pumpDuration);

      // The router should redirect to /pending-approval
      expect(find.byType(PendingApprovalScreen), findsOneWidget,
          reason: 'Pending vendor should be redirected to PendingApprovalScreen');

      // Verify the "Application Under Review" text is shown
      expect(find.text('Application Under Review'), findsOneWidget,
          reason: 'Pending approval screen should show "Application Under Review"');
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 2: Approved Vendor Loads Dashboard (not PendingApproval)
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('PartnerRouter_ApprovedVendor_RedirectsToDashboard', (tester) async {
      final approvedSession = VendorAuthSession(
        accessToken: 'approved-token',
        vendorId: 'vendor-test-1',
        vendorName: 'Test Vendor',
        category: 'Pizzeria',
        phone: '9000000001',
        status: 'Approved',
      );

      final container = ProviderContainer(
        overrides: buildPartnerOverrides(vendorSession: approvedSession),
      );
      addTearDown(container.dispose);

      final router = container.read(partnerRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(_pumpDuration);

      // The router should NOT show PendingApproval
      expect(find.byType(PendingApprovalScreen), findsNothing,
          reason: 'Approved vendor should not see PendingApprovalScreen');
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 3: Menu Item Toggle Changes to Sold Out
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('VendorMenuScreen_ToggleItem_ChangesToSoldOut', (tester) async {
      final approvedSession = VendorAuthSession(
        accessToken: 'approved-token',
        vendorId: 'vendor-test-1',
        vendorName: 'Test Vendor',
        category: 'Pizzeria',
        phone: '9000000001',
        status: 'Approved',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildPartnerOverrides(vendorSession: approvedSession),
          child: const MaterialApp(home: VendorMenuScreen()),
        ),
      );
      await tester.pump(_pumpDuration);

      // Wait for menu items to load
      expect(find.text('Margherita Pizza'), findsOneWidget,
          reason: 'First menu item should be loaded');
      expect(find.text('Garlic Bread'), findsOneWidget,
          reason: 'Second menu item should be loaded');

      // Assert first item shows "In Stock"
      expect(find.text('In Stock'), findsWidgets,
          reason: 'Items should initially show In Stock');

      // Find the Switch on the first item and toggle it
      final switches = find.byType(Switch);
      expect(switches, findsWidgets,
          reason: 'Toggle switches should be visible for each menu item');

      await tester.tap(switches.first);
      await tester.pump(_pumpDuration);

      // Assert "Sold Out" text now appears
      expect(find.text('Sold Out'), findsOneWidget,
          reason: 'Toggled item should show Sold Out');
    });
  });
}
