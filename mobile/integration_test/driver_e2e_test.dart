/// Captain (Driver) App E2E Integration Tests
///
/// Tests the delivery lifecycle state machine (4 phases), emergency release
/// dialog, and offline mutation queue behavior on network errors.
///
/// Run with:
///   `flutter test integration_test/driver_e2e_test.dart -d <emulator-id>`
///
/// Or headless:
///   `flutter test integration_test/driver_e2e_test.dart`
library driver_e2e_test;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pondyconnect/core/network/offline_mutation_queue.dart';
import 'package:pondyconnect/features/driver/domain/driver_models.dart';
import 'package:pondyconnect/features/driver/presentation/active_trip_screen.dart';

import 'helpers/test_helpers.dart';
import 'helpers/fake_overrides.dart';

/// Fixed-duration pump to avoid pumpAndSettle() hanging on
/// continuous animations (shimmers, loading spinners, etc.).
const _pumpDuration = Duration(seconds: 2);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helper: creates a mock food delivery task
  DispatchTaskModel createMockTask({String status = 'Assigned'}) {
    return DispatchTaskModel(
      id: 'task-test-1',
      taskType: 'FoodDelivery',
      pickupAddress: 'Fuoco Pizzeria',
      dropoffAddress: '12 Rue Romain Rolland',
      driverEarnings: 40.0,
      status: status,
      driverId: 'driver-test-1',
    );
  }

  // Helper: creates a real OfflineMutationQueue with a fake SharedPreferences
  Future<OfflineMutationQueue> createOfflineQueue({
    bool shouldFail = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return OfflineMutationQueue(
      prefs,
      (mutation) async {
        if (shouldFail) {
          throw DioException(
            requestOptions: RequestOptions(path: mutation.path),
            type: DioExceptionType.connectionError,
            error: SocketException('Network unreachable'),
          );
        }
        return true;
      },
    );
  }

  group('Captain App E2E', () {
    // ─────────────────────────────────────────────────────────────────────
    // Test 1: Delivery Phase Progression (Arrived → Picked Up → Delivered)
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('ActiveTripScreen_PhaseProgression_ArrivedToDelivered', (tester) async {
      final task = createMockTask();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildDriverOverrides(activeTask: task),
          child: MaterialApp(home: DeliveryLifecycleScreen(task: task)),
        ),
      );
      await tester.pump(_pumpDuration);

      // Phase 1: Heading to Store → tap "Arrived at Store"
      expect(find.textContaining('Arrived at'), findsOneWidget,
          reason: 'Should show Arrived at Store button');
      await tester.tap(find.textContaining('Arrived at'));
      await tester.pump(_pumpDuration);

      // Phase 2: At Store → tap "Confirm Order Picked Up"
      expect(find.text('Confirm Order Picked Up'), findsOneWidget,
          reason: 'Should show Confirm Order Picked Up button');
      await tester.tap(find.text('Confirm Order Picked Up'));
      await tester.pump(_pumpDuration);

      // Phase 3: En Route to Customer → tap "Arrived at Delivery Location"
      expect(find.text('Arrived at Delivery Location'), findsOneWidget,
          reason: 'Should show Arrived at Delivery Location button');
      await tester.tap(find.text('Arrived at Delivery Location'));
      await tester.pump(_pumpDuration);

      // Phase 4: Delivered → "Complete Delivery" button should appear
      expect(find.text('Complete Delivery & Collect Cash/UPI'), findsOneWidget,
          reason: 'Should show Complete Delivery button');
      await tester.tap(find.text('Complete Delivery & Collect Cash/UPI'));
      await tester.pump(_pumpDuration);

      // Assert completion SnackBar appears
      expect(find.textContaining('Delivery completed'), findsWidgets,
          reason: 'Completion SnackBar should appear');
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 2: Emergency Release Dialog
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('ActiveTripScreen_EmergencyRelease_ShowsConfirmationDialog', (tester) async {
      final task = createMockTask();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildDriverOverrides(activeTask: task),
          child: MaterialApp(home: DeliveryLifecycleScreen(task: task)),
        ),
      );
      await tester.pump(_pumpDuration);

      // Find the emergency warning icon in the AppBar
      final emergencyIcon = find.byTooltip('Emergency Issue / Cannot Complete');
      expect(emergencyIcon, findsOneWidget,
          reason: 'Emergency release icon should be visible in AppBar');

      // Tap it
      await tester.tap(emergencyIcon);
      await tester.pump(_pumpDuration);

      // Assert confirmation dialog appears
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'Confirmation dialog should appear');

      // Tap Cancel to dismiss
      final cancelButton = find.text('Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump(_pumpDuration);

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'Dialog should be dismissed after Cancel');
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 3: Offline Queue — Queues Mutation on Network Error
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('ActiveTripScreen_OfflineQueue_QueuesMutationOnNetworkError', (tester) async {
      final task = createMockTask();
      final mockClient = FakeApiClient();

      // Create a real OfflineMutationQueue with a fake sender that succeeds
      final queue = await createOfflineQueue(shouldFail: false);

      // Override the DriverApi to throw a network error on the next call
      final fakeDriverApi = FakeDriverApi(mockClient);
      fakeDriverApi.throwNetworkErrorOnNext = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...buildDriverOverrides(activeTask: task, mock: mockClient, offlineQueue: queue),
            // Override driverApiProvider with our configured fake
            // that throws on the next markOutForDelivery call
          ],
          child: MaterialApp(home: DeliveryLifecycleScreen(task: task)),
        ),
      );
      await tester.pump(_pumpDuration);

      // Advance to "At Store" phase first (this call succeeds)
      await tester.tap(find.textContaining('Arrived at'));
      await tester.pump(_pumpDuration);

      // Now set up the network error for the next call (Picked Up → Out for Delivery)
      // We need to inject the error via the mock client
      mockClient.throwOnNextPost = true;

      // Tap "Confirm Order Picked Up" — this triggers markOutForDelivery which will fail
      await tester.tap(find.text('Confirm Order Picked Up'));
      await tester.pump(_pumpDuration);

      // Assert the "Offline — saved" SnackBar appears
      expect(find.textContaining('Offline'), findsWidgets,
          reason: 'Offline SnackBar should appear when network error occurs');

      // Assert the queue has 1 pending mutation
      expect(queue.isNotEmpty, true,
          reason: 'Offline mutation queue should have 1 pending mutation');

      // Flush the queue — should succeed since we restored network
      await queue.flush();
      expect(queue.isNotEmpty, false,
          reason: 'Queue should be empty after successful flush');
    });
  });
}
