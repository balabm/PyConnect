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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pondyconnect/core/network/offline_mutation_queue.dart';
import 'package:pondyconnect/features/driver/domain/driver_models.dart';
import 'package:pondyconnect/features/driver/presentation/active_trip_screen.dart';

import '../helpers/test_helpers.dart';

/// Fixed-duration pump to avoid pumpAndSettle() hanging on
/// continuous animations (shimmers, loading spinners, etc.).
const _pumpDuration = Duration(milliseconds: 100);

void main() {
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
    testWidgets('OfflineQueue_QueuesMutationOnNetworkError', (tester) async {
      // Create a queue with a sender that always fails (simulates offline)
      final queue = await createOfflineQueue(shouldFail: true);

      // Enqueue a mutation
      final mutation = QueuedMutation(
        id: 'mutation-test-1',
        path: '/api/driver/tasks/task-1/out-for-delivery',
        method: 'POST',
        body: {'taskId': 'task-1'},
        createdAt: DateTime.now(),
      );

      await queue.enqueue(mutation);

      // The mutation should be in the queue
      expect(queue.isNotEmpty, true,
          reason: 'Offline mutation queue should retain the queued mutation');
      expect(queue.queue.length, 1,
          reason: 'Queue should have exactly 1 pending mutation');

      // Flush should fail (sender throws) and the mutation stays queued
      await queue.flush();
      expect(queue.isNotEmpty, true,
          reason: 'Queue should still have mutation after failed flush');

      // Now create a queue with a succeeding sender, enqueue same mutation, flush
      final successQueue = await createOfflineQueue(shouldFail: false);
      final mutation2 = QueuedMutation(
        id: 'mutation-test-2',
        path: '/api/driver/tasks/task-1/out-for-delivery',
        method: 'POST',
        body: {'taskId': 'task-1'},
        createdAt: DateTime.now(),
      );
      await successQueue.enqueue(mutation2);
      expect(successQueue.isNotEmpty, true);

      await successQueue.flush();
      expect(successQueue.isNotEmpty, false,
          reason: 'Queue should be empty after successful flush');
    });
  });
}
