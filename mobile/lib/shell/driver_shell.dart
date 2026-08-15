import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/theme/app_theme.dart';
import '../core/network/offline_mutation_queue.dart';
import '../core/providers.dart';
import '../features/driver/application/driver_providers.dart';
import '../features/driver/application/driver_signalr_provider.dart';
import '../features/driver/presentation/driver_home_screen.dart';
import '../features/driver/presentation/driver_earnings_screen.dart';
import '../features/driver/presentation/active_trip_screen.dart';
import '../core/services/keep_awake_service.dart';
import '../core/services/background_location_service.dart';
import '../core/services/overlay_alert_service.dart';
import '../features/driver/data/driver_api.dart';
import '../features/driver/presentation/ride_offer_sheet.dart';

/// Root scaffold for the Driver app with bottom navigation.
class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  Timer? _locationTimer;
  bool _isStartingLocation = false;
  StreamSubscription? _rideOfferSub;
  StreamSubscription? _foodOfferSub;

  /// Queue of pending ride offers that arrived while another offer sheet
  /// was already open. When the current sheet closes, the next queued
  /// offer is shown automatically.
  final List<RideOfferModel> _offerQueue = [];

  @override
  void initState() {
    super.initState();
    // Initialize overlay alert service for dispatch notifications
    OverlayAlertService.instance.initialize();
    _listenForRideOffers();
    _resumeActiveTask();
  }

  /// On app restart, check if the driver has an in-progress task and
  /// restore it to the Active Trip tab so the driver can continue the
  /// ride/delivery after an app kill or crash.
  Future<void> _resumeActiveTask() async {
    try {
      final tasks = await ref.read(driverApiProvider).getAvailableTasks();
      // Find a task assigned to this driver that is not Available/Completed/Cancelled
      final activeTask = tasks.where((t) =>
          t.status != 'Available' &&
          t.status != 'Completed' &&
          t.status != 'Cancelled' &&
          t.driverId != null).firstOrNull;
      if (activeTask != null && mounted) {
        ref.read(activeTaskProvider.notifier).state = activeTask;
        ref.read(driverSelectedTabProvider.notifier).state = 1;
      }
      // Network is up — flush any queued offline mutations.
      _flushOfflineQueue();
    } catch (_) {
      // Non-fatal — driver can still go online normally
    }
  }

  /// Flushes the offline mutation queue if there are pending mutations.
  /// Called after successful API calls when network connectivity is restored.
  void _flushOfflineQueue() {
    try {
      final queue = ref.read(offlineMutationQueueProvider);
      if (queue.isNotEmpty) {
        queue.flush();
      }
    } catch (_) {
      // SharedPreferences not ready yet — skip.
    }
  }

  void _listenForRideOffers() {
    final signalR = ref.read(driverSignalRProvider);
    _rideOfferSub = signalR.rideOfferStream.listen((args) {
      for (final arg in args) {
        if (arg is Map<String, dynamic>) {
          try {
            final offer = RideOfferModel.fromJson(arg);
            // Show high-priority notification (works in background).
            OverlayAlertService.instance.showRideOfferAlert(
              title: offer.taskType.contains('Food') ? 'Food Delivery!' : 'New Ride Request!',
              body: 'Pickup: ${offer.pickupAddress}\nEarnings: ₹${offer.driverEarnings.toStringAsFixed(0)} (100%)',
              rideId: offer.rideId,
            );
            // Also show the full-screen modal offer sheet when app is foregrounded.
            _showOfferSheet(offer);
          } catch (_) {}
        }
      }
    });
    _foodOfferSub = signalR.foodDeliveryOfferStream.listen((args) {
      for (final arg in args) {
        if (arg is Map<String, dynamic>) {
          try {
            final offer = RideOfferModel.fromJson(arg);
            OverlayAlertService.instance.showRideOfferAlert(
              title: 'Food Delivery Task!',
              body: 'Pickup: ${offer.pickupAddress}\nEarnings: ₹${offer.driverEarnings.toStringAsFixed(0)} (100%)',
              rideId: offer.rideId,
            );
            _showOfferSheet(offer);
          } catch (_) {}
        }
      }
    });
  }

  /// Shows the [RideOfferSheet] as a non-dismissible bottom sheet so the
  /// driver can review the offer and accept/decline with a 30-second
  /// countdown. If a sheet is already open, the offer is queued and
  /// shown when the current sheet closes.
  bool _offerSheetOpen = false;
  void _showOfferSheet(RideOfferModel offer) {
    if (!mounted) return;
    if (_offerSheetOpen) {
      // Queue the offer — it will be shown when the current sheet closes.
      _offerQueue.add(offer);
      return;
    }
    _offerSheetOpen = true;
    final context = this.context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RideOfferSheet(
        offer: offer,
        onAccept: () async {
          Navigator.pop(sheetContext);
          try {
            final api = ref.read(driverApiProvider);
            final accepted = await api.acceptTask(offer.rideId);
            ref.read(activeTaskProvider.notifier).state = accepted;
            ref.read(driverSelectedTabProvider.notifier).state = 1;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to accept: $e')),
              );
            }
          }
        },
        onDecline: () {
          Navigator.pop(sheetContext);
          // Notify backend so the offer can be re-dispatched immediately.
          try {
            ref.read(driverSignalRProvider).declineRide(offer.rideId);
          } catch (_) {
            // Best-effort decline — backend will timeout the offer anyway.
          }
        },
      ),
    ).whenComplete(() {
      _offerSheetOpen = false;
      // Drain the queue — show the next pending offer if any.
      if (_offerQueue.isNotEmpty && mounted) {
        final next = _offerQueue.removeAt(0);
        _showOfferSheet(next);
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _rideOfferSub?.cancel();
    _foodOfferSub?.cancel();
    KeepAwakeService.disable();
    super.dispose();
  }

  void _toggleOnline(WidgetRef ref) async {
    final isOnline = ref.read(driverOnlineStatusProvider);
    if (isOnline) {
      try {
        await ref.read(driverApiProvider).goOffline();
        ref.read(driverOnlineStatusProvider.notifier).state = false;
        _locationTimer?.cancel();
        _locationTimer = null;
        KeepAwakeService.disable();
        BackgroundLocationService.instance.stop();
        // Disconnect SignalR dispatch listener when going offline
        await ref.read(driverSignalRProvider).disconnect();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to go offline: $e'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    } else {
      // Request location permissions before going online
      final hasPermission = await _requestLocationPermissions();
      if (!hasPermission || !mounted) return;

      try {
        await ref.read(driverApiProvider).goOnline();
        ref.read(driverOnlineStatusProvider.notifier).state = true;
        KeepAwakeService.enable();
        _startLocationTracking(ref);
        // Connect to SignalR dispatch hub so the driver receives real-time
        // ride/food offers. We fetch the driver profile to get the driver Id
        // used for joining the targeted dispatch channel.
        try {
          final profile = await ref.read(driverApiProvider).getProfile();
          if (profile.id.isNotEmpty) {
            await ref.read(driverSignalRProvider).connect(profile.id);
          }
        } catch (e) {
          // SignalR connection failure is non-fatal — location pings still
          // allow dispatch via polling. Warn the driver so they can retry.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not connect to dispatch: $e. Toggle offline/online to retry.'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to go online: $e'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    }
  }

  /// Requests foreground and background location permissions with proper flow.
  /// Returns true if foreground permission is granted (background is optional
  /// but requested for continuous tracking while online).
  Future<bool> _requestLocationPermissions() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services to go online'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to go online'),
                backgroundColor: AppTheme.danger,
              ),
            );
          }
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location permission in Settings'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        return false;
      }

      // Request background location permission with rationale.
      // On Android 10+, this shows a separate system dialog.
      // The user must have already granted foreground location.
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          // Geolocator handles the background permission request on Android
          // by requesting the ACCESS_BACKGROUND_LOCATION permission.
          final bgPermission = await Geolocator.requestPermission();
          if (bgPermission == LocationPermission.always) {
            // Background location granted — start the foreground service
            await BackgroundLocationService.instance.initialize();
          }
        } catch (_) {
          // Background location is optional — foreground is sufficient
          // for basic online status. The app will still work with
          // foreground-only location while the app is visible.
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts periodic location updates and sends them to the backend.
  void _startLocationTracking(WidgetRef ref) {
    if (_isStartingLocation) return;
    _isStartingLocation = true;

    // Start the background service for persistent tracking
    BackgroundLocationService.instance.start();

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        await ref.read(driverApiProvider).updateLocation(
              position.latitude,
              position.longitude,
            );
      } catch (_) {
        // Ignore GPS errors — keep the timer alive
      }
    });
    _isStartingLocation = false;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineStatusProvider);
    final currentIndex = ref.watch(driverSelectedTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PY Connect Captain'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _toggleOnline(ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppTheme.emerald.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: isOnline ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: IndexedStack(
        index: currentIndex,
        children: const [
          DriverHomeScreen(),
          ActiveTripScreen(),
          DriverEarningsScreen(),
        ],
      )),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => ref.read(driverSelectedTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Active Trip',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings & Profile',
          ),
        ],
      ),
    );
  }
}
