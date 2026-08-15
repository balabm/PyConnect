import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/theme/app_theme.dart';
import '../features/driver/application/driver_providers.dart';
import '../features/driver/presentation/driver_home_screen.dart';
import '../features/driver/presentation/driver_earnings_screen.dart';
import '../core/services/keep_awake_service.dart';
import '../core/services/background_location_service.dart';

/// Root scaffold for the Driver app with bottom navigation.
class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  int _currentIndex = 0;
  Timer? _locationTimer;
  bool _isStartingLocation = false;

  @override
  void dispose() {
    _locationTimer?.cancel();
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
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DriverHomeScreen(),
          DriverEarningsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Rides',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
        ],
      ),
    );
  }
}
