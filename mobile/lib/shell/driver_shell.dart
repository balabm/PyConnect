import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/device/location_security.dart';
import '../core/animations/haptic.dart';
import '../core/navigation/floating_nav_bar.dart';
import '../core/theme/app_theme.dart';
import '../core/network/offline_mutation_queue.dart';
import '../core/services/gps_buffer_service.dart';
import '../core/providers.dart';
import '../features/driver/application/driver_providers.dart';
import '../features/driver/application/driver_signalr_provider.dart';
import '../features/driver/presentation/driver_home_screen.dart';
import '../features/driver/presentation/driver_earnings_screen.dart';
import '../features/driver/presentation/active_trip_screen.dart';
import '../core/services/keep_awake_service.dart';
import '../core/services/background_location_service.dart';
import '../core/services/overlay_alert_service.dart';
import '../core/services/tts_service.dart';
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
  int _consecutiveGpsFailures = 0;

  /// Whether a mock/fake GPS app has been detected. When true, the driver
  /// is forced offline and a permanent red warning screen is shown.
  bool _mockLocationDetected = false;

  /// Whether the SignalR dispatch connection is currently reconnecting.
  /// When true, a yellow banner is shown at the top of the screen.
  bool _isReconnecting = false;

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

  /// Flushes the GPS buffer if there are pending pings from an offline
  /// period (cell handover, dead zone). Called after a successful
  /// location update confirms connectivity is restored.
  void _flushGpsBuffer(WidgetRef ref) {
    try {
      final buffer = ref.read(gpsBufferServiceProvider);
      if (buffer.hasPending) {
        buffer.flush();
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
            // Voice-assisted dispatch: announce the ride in the driver's
            // selected language so they don't have to look at the screen.
            ref.read(ttsServiceProvider).announceRideOffer(
                  pickupAddress: offer.pickupAddress,
                  fare: offer.fare,
                  vehicleType: offer.vehicleType,
                  isSos: offer.isSos,
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
            final foodOffer = FoodDeliveryOfferModel.fromJson(arg);
            // Bridge the v4 FoodDelivery payload into the ride-offer sheet.
            final offer = RideOfferModel(
              rideId: foodOffer.orderId,
              pickupAddress: foodOffer.pickupAddress,
              dropoffAddress: foodOffer.deliveryAddress,
              distanceKm: 0,
              fare: foodOffer.totalAmount,
              driverEarnings: foodOffer.driverEarnings,
              paymentMethod: foodOffer.paymentMethod,
              vehicleType: 'Bike',
              isSos: false,
              surgeMultiplier: 1.0,
              surgeReason: null,
              expiresIn: foodOffer.expiresIn,
              taskType: 'FoodDelivery',
            );
            OverlayAlertService.instance.showRideOfferAlert(
              title: 'Food Delivery Task!',
              body: 'Pickup: ${offer.pickupAddress}\nEarnings: ₹${offer.driverEarnings.toStringAsFixed(0)} (100%)',
              rideId: offer.rideId,
            );
            // Voice-assisted dispatch for food delivery offers.
            ref.read(ttsServiceProvider).announceFoodDeliveryOffer(
                  storeName: offer.pickupAddress,
                  earnings: offer.driverEarnings,
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

  /// Drives the Captain to the requested online/offline state. Called by the
  /// shell in response to [driverOnlineToggleRequestProvider] changes so every
  /// toggle (app bar, home screen, etc.) actually starts/stops the location
  /// service and SignalR dispatch connection.
  void _setOnline(bool isOnline, WidgetRef ref) async {
    try {
    if (!isOnline) {
      try {
        await ref.read(driverApiProvider).goOffline();
        ref.read(driverOnlineStatusProvider.notifier).state = false;
        _locationTimer?.cancel();
        _locationTimer = null;
        KeepAwakeService.disable();
        BackgroundLocationService.instance.stop();
        // Clear the reconnecting banner and the callback before disconnecting
        // so the intentional disconnect doesn't trigger the auth-offline path.
        if (mounted) setState(() => _isReconnecting = false);
        final hub = ref.read(driverHubProvider);
        hub.onConnectionStateChanged = null;
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
            // Wire up the connection state callback before connecting so we
            // catch the very first reconnecting/reconnected events.
            final hub = ref.read(driverHubProvider);
            hub.onConnectionStateChanged = (isReconnecting) {
              if (!mounted) return;
              if (isReconnecting) {
                // Reconnecting started — show yellow banner, keep UI "Online".
                // Transient network errors (SocketException/timeout) do NOT
                // toggle the driver offline.
                setState(() => _isReconnecting = true);
              } else {
                // Either reconnected or permanently disconnected.
                setState(() => _isReconnecting = false);
                // If the connection is NOT connected, it was permanently
                // lost. This only happens on auth rejection (401/403) or
                // intentional disconnect. If the driver is still marked
                // online, this was an auth rejection — toggle offline.
                if (!hub.isConnected && ref.read(driverOnlineStatusProvider)) {
                  ref.read(driverOnlineStatusProvider.notifier).state = false;
                  _locationTimer?.cancel();
                  _locationTimer = null;
                  KeepAwakeService.disable();
                  BackgroundLocationService.instance.stop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Authentication expired. Please log in again.'),
                        backgroundColor: AppTheme.danger,
                      ),
                    );
                  }
                }
              }
            };
            await ref.read(driverSignalRProvider).connect(profile.id);
          }
        } catch (e) {
          // SignalR connection failure is non-fatal — location pings still
          // allow dispatch via polling. Warn the driver so they can retry.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not connect to live dispatch. You may miss ride offers. Toggle offline/online to retry.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final msg = _parseGoOnlineError(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    }
  } finally {
    if (mounted) {
      // Reset the toggle request so the same on/off switch can be retried
      // after a permission denial or network error.
      ref.read(driverOnlineToggleRequestProvider.notifier).state = null;
    }
  }
}

  /// Parses a goOnline/SignalR exception into a user-facing message.
  /// Detects auth-expired and network errors so the driver knows exactly
  /// what to do instead of seeing a raw exception string.
  String _parseGoOnlineError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('401') ||
        text.contains('unauthorized') ||
        text.contains('token')) {
      return 'Authentication expired. Please log in again.';
    }
    if (text.contains('socketexception') ||
        text.contains('connection') ||
        text.contains('timeout')) {
      return 'Network error. Check your internet connection.';
    }
    return 'Failed to go online: $e';
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
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );

        // Anti-spoofing: check if the position is from a mock-location app.
        // If so, drop the ping, force the driver offline, and show a
        // permanent red warning screen. Log the anomaly to the backend.
        if (LocationSecurity.isMocked(currentPosition)) {
          _handleMockLocationDetected(ref);
          return;
        }

        await ref.read(driverApiProvider).updateLocation(
              currentPosition.latitude,
              currentPosition.longitude,
            );
        // GPS + network succeeded — reset the failure counter and flush
        // any buffered pings from a previous offline period.
        _consecutiveGpsFailures = 0;
        _flushGpsBuffer(ref);
      } catch (e) {
        // Network or GPS error — buffer the GPS ping so the trip trail
        // remains complete when connectivity is restored.
        if (currentPosition != null) {
          try {
            final buffer = ref.read(gpsBufferServiceProvider);
            await buffer.enqueue(currentPosition.latitude, currentPosition.longitude);
          } catch (_) {
            // Buffer not ready — drop silently.
          }
        }

        // GPS error — track consecutive failures and warn the driver
        // after 3 in a row so they know to move to an open area.
        _consecutiveGpsFailures++;
        if (_consecutiveGpsFailures == 3 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS signal lost. Move to an open area.'),
              backgroundColor: AppTheme.warning,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });
    _isStartingLocation = false;
  }

  /// Handles a detected mock/fake GPS location. Drops the ping, forces the
  /// driver offline, stops location tracking, and shows a permanent red
  /// warning screen. The anomaly is logged to the backend for review.
  void _handleMockLocationDetected(WidgetRef ref) {
    if (_mockLocationDetected) return; // Already handled

    setState(() => _mockLocationDetected = true);

    // Stop location tracking immediately.
    _locationTimer?.cancel();
    _locationTimer = null;
    BackgroundLocationService.instance.stop();

    // Force the driver offline.
    ref.read(driverOnlineToggleRequestProvider.notifier).state = false;

    // Best-effort: log the anomaly to the backend for fraud/suspension review.
    try {
      ref.read(driverApiProvider).reportMockLocation(0, 0);
    } catch (_) {
      // Ignore — the log is best-effort.
    }

    if (mounted) {
      AppHaptics.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineStatusProvider);
    final currentIndex = ref.watch(driverSelectedTabProvider);

    // Listen to toggle requests from any Captain widget (home screen, app bar,
    // etc.) and route them through the single location + SignalR flow.
    ref.listen(driverOnlineToggleRequestProvider, (prev, next) {
      if (next != null && next != ref.read(driverOnlineStatusProvider)) {
        _setOnline(next, ref);
      }
    });

    // Mock location detected — show permanent red warning screen.
    if (_mockLocationDetected) {
      return Scaffold(
        body: Container(
          color: AppTheme.danger,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gps_off, size: 80, color: Colors.white),
                    const SizedBox(height: 24),
                    const Text(
                      'Mock Location Detected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please disable fake GPS apps to go online.\n\n'
                      'Your account has been flagged for review. Repeated attempts to spoof your location may result in suspension.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('I\'ve Disabled Fake GPS'),
                      onPressed: () {
                        // Reset the mock flag and allow the driver to try again.
                        setState(() => _mockLocationDetected = false);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('PY Connect Captain'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => ref.read(driverOnlineToggleRequestProvider.notifier).state = !isOnline,
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
      body: SafeArea(child: Column(
        children: [
          if (_isReconnecting)
            Material(
              color: AppTheme.warning,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Reconnecting to dispatch...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: const [
                DriverHomeScreen(),
                ActiveTripScreen(),
                DriverEarningsScreen(),
              ],
            ),
          ),
        ],
      )),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => ref.read(driverSelectedTabProvider.notifier).state = i,
        destinations: const [
          FloatingNavDestination(
            icon: Icons.list_outlined,
            activeIcon: Icons.list,
            label: 'Tasks',
          ),
          FloatingNavDestination(
            icon: Icons.two_wheeler_outlined,
            activeIcon: Icons.two_wheeler,
            label: 'Active Trip',
          ),
          FloatingNavDestination(
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet,
            label: 'Earnings',
          ),
        ],
      ),
    );
  }
}
