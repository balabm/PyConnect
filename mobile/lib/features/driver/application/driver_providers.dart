import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'driver_signalr_provider.dart';
import '../data/driver_api.dart';
import '../domain/driver_models.dart';

final driverApiProvider = Provider<DriverApi>((ref) {
  return DriverApi(ref.read(apiClientProvider));
});

final driverOnlineStatusProvider = StateProvider<bool>((ref) => false);

// ── KYC Upload State ──

/// The three KYC document slots the driver must fill.
final kycSlotsProvider =
    StateNotifierProvider<KycSlotsNotifier, List<KycDocumentSlot>>((ref) {
  return KycSlotsNotifier();
});

class KycSlotsNotifier extends StateNotifier<List<KycDocumentSlot>> {
  KycSlotsNotifier()
      : super([
          KycDocumentSlot(
            label: 'Identity Proof (Aadhaar)',
            icon: Icons.badge_outlined,
            fieldName: 'aadhaar',
          ),
          KycDocumentSlot(
            label: 'Driving License',
            icon: Icons.credit_card_outlined,
            fieldName: 'drivingLicense',
          ),
          KycDocumentSlot(
            label: 'Vehicle RC',
            icon: Icons.directions_car_outlined,
            fieldName: 'rc',
          ),
        ]);

  void setFile(int index, File file) {
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(file: file, status: KycDocStatus.pending)
        else
          state[i],
    ];
  }

  void setUploading(int index) {
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(status: KycDocStatus.uploading)
        else
          state[i],
    ];
  }

  void setUploaded(int index) {
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(status: KycDocStatus.uploaded)
        else
          state[i],
    ];
  }

  void setError(int index, String message) {
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(status: KycDocStatus.error, errorMessage: message)
        else
          state[i],
    ];
  }

  void reset() {
    state = [
      KycDocumentSlot(
        label: 'Identity Proof (Aadhaar)',
        icon: Icons.badge_outlined,
        fieldName: 'aadhaar',
      ),
      KycDocumentSlot(
        label: 'Driving License',
        icon: Icons.credit_card_outlined,
        fieldName: 'drivingLicense',
      ),
      KycDocumentSlot(
        label: 'Vehicle RC',
        icon: Icons.directions_car_outlined,
        fieldName: 'rc',
      ),
    ];
  }
}

/// Whether all three KYC documents have a file selected.
final kycAllFilesSelectedProvider = Provider<bool>((ref) {
  final slots = ref.watch(kycSlotsProvider);
  return slots.every((s) => s.file != null);
});

/// Whether the KYC submit is in progress.
final kycSubmittingProvider = StateProvider<bool>((ref) => false);

final driverWalletProvider = FutureProvider<DriverWalletModel>((ref) async {
  final api = ref.read(driverApiProvider);
  return api.getWallet();
});

final dispatchTaskStreamProvider =
    StreamProvider<List<DispatchTaskModel>>((ref) async* {
  final api = ref.read(driverApiProvider);
  final signalR = ref.read(driverSignalRProvider);

  // Try to fetch real tasks from the API first
  try {
    final tasks = await api.getAvailableTasks();
    yield tasks;
  } catch (_) {
    yield [];
  }

  // Merge SignalR ride offer stream with periodic API polling fallback.
  // The SignalR stream pushes new ride offers as they arrive in real-time.
  // The timer polls every 15 seconds as a fallback for when SignalR is not
  // connected or for non-ride tasks (food delivery, essentials).
  final controller = StreamController<List<DispatchTaskModel>>.broadcast();

  // Subscribe to SignalR dispatch task stream
  final signalRSub = signalR.dispatchTaskStream.listen((tasks) {
    if (!controller.isClosed) controller.add(tasks);
  });

  Timer? timer;
  timer = Timer.periodic(const Duration(seconds: 15), (_) async {
    try {
      final tasks = await api.getAvailableTasks();
      if (!controller.isClosed) {
        controller.add(tasks);
      }
    } catch (_) {
      // Ignore network errors, keep stream alive
    }
  });

  ref.onDispose(() {
    timer?.cancel();
    signalRSub.cancel();
    controller.close();
  });

  yield* controller.stream;
});

// Mock SignalR task provider for demo/testing purposes
final mockTaskProvider = StreamProvider<List<DispatchTaskModel>>((ref) async* {
  final mockTasks = [
    DispatchTaskModel(
      id: 'mock-1',
      taskType: 'FoodDelivery',
      pickupAddress: 'Fuoco Pizzeria, White Town',
      dropoffAddress: 'Le Dupleix Hotel, White Town',
      driverEarnings: 40,
      status: 'Available',
    ),
    DispatchTaskModel(
      id: 'mock-2',
      taskType: 'Ride',
      pickupAddress: 'Pondicherry Bus Stand',
      dropoffAddress: 'Rock Beach',
      driverEarnings: 85,
      status: 'Available',
    ),
    DispatchTaskModel(
      id: 'mock-3',
      taskType: 'EssentialsDrop',
      pickupAddress: '24x7 Store, Mission Street',
      dropoffAddress: 'Aurobindo Ashram Guest House',
      driverEarnings: 30,
      status: 'Available',
    ),
  ];

  yield mockTasks;

  await Future.delayed(const Duration(seconds: 5));
  yield [
    ...mockTasks,
    DispatchTaskModel(
      id: 'mock-4',
      taskType: 'Ride',
      pickupAddress: 'Promenade Beach',
      dropoffAddress: 'Pondicherry Airport',
      driverEarnings: 120,
      status: 'Available',
    ),
  ];
});
