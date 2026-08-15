import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/animations/haptic.dart';
import '../core/animations/staggered_animations.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/vendor_auth_controller.dart';
import '../features/vendor/application/vendor_providers.dart';
import '../features/vendor/domain/vendor_category_type.dart';
import '../features/vendor/presentation/vendor_dashboard_screen.dart';
import '../features/vendor/presentation/vendor_menu_screen.dart';
import '../features/vendor/presentation/vendor_bookings_screen.dart';
import '../features/vendor/presentation/kitchen_display_screen.dart';
import '../features/vendor/presentation/manage_hub_screen.dart';
import '../features/vendor/presentation/drinks_menu_screen.dart';
import '../features/vendor/presentation/fleet_management_screen.dart';
import '../features/vendor/presentation/active_rentals_screen.dart';
import '../features/vendor/presentation/taxi_fleet_screen.dart';
import '../features/vendor/presentation/taxi_rides_screen.dart';
import '../features/vendor/presentation/cloak_capacity_screen.dart';
import '../features/scanner/presentation/scanner_screen.dart';
import '../core/services/keep_awake_service.dart';

/// Root scaffold for the Partner (service owner POS) app with bottom navigation.
/// Dark slate theme with animated live status indicator.
/// Navigation tabs adapt to the vendor's category.
class PartnerShell extends ConsumerStatefulWidget {
  const PartnerShell({super.key});

  @override
  ConsumerState<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends ConsumerState<PartnerShell> {
  int _currentIndex = 0;
  bool _acceptingOrders = true;
  bool _toggling = false;
  String? _venueId;
  String _vendorName = '';
  VendorCategoryType _category = VendorCategoryType.restaurant;

  @override
  void initState() {
    super.initState();
    KeepAwakeService.enable();
    _loadVenueInfo();
  }

  @override
  void dispose() {
    KeepAwakeService.disable();
    super.dispose();
  }

  Future<void> _loadVenueInfo() async {
    final session = ref.read(vendorAuthControllerProvider).valueOrNull;
    if (session != null && mounted) {
      setState(() {
        _vendorName = session.vendorName;
        _category = VendorCategoryType.fromString(session.category);
      });
    }
    try {
      final venues = await ref.read(vendorDashboardApiProvider).getVenues();
      if (venues.isNotEmpty && mounted) {
        setState(() {
          _venueId = venues.first.venueId;
          _acceptingOrders = venues.first.isActive;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleAcceptingOrders() async {
    if (_venueId == null || _toggling) return;
    AppHaptics.light();
    setState(() => _toggling = true);
    try {
      final isActive =
          await ref.read(vendorDashboardApiProvider).toggleVenueAvailability(_venueId!);
      if (mounted) {
        setState(() {
          _acceptingOrders = isActive;
          _toggling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Now accepting orders' : 'Orders paused'),
            backgroundColor: isActive ? AppTheme.lagoon : AppTheme.coral,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _toggling = false);
    }
  }

  List<Widget> get _screens => switch (_category) {
        VendorCategoryType.restaurant ||
        VendorCategoryType.cafe ||
        VendorCategoryType.pizzeria =>
          const [
            VendorDashboardScreen(),
            KitchenDisplayScreen(),
            VendorMenuScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.pubClub => const [
            VendorDashboardScreen(),
            KitchenDisplayScreen(),
            DrinksMenuScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.scooterRental => const [
            VendorDashboardScreen(),
            FleetManagementScreen(),
            ActiveRentalsScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.taxiOperator => const [
            VendorDashboardScreen(),
            TaxiFleetScreen(),
            TaxiRidesScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.luggageCloak => const [
            VendorDashboardScreen(),
            CloakCapacityScreen(),
            VendorBookingsScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
      };

  List<NavigationDestination> get _destinations {
    final secondary = switch (_category) {
      VendorCategoryType.restaurant ||
      VendorCategoryType.cafe ||
      VendorCategoryType.pizzeria ||
      VendorCategoryType.pubClub => const NavigationDestination(
          icon: Icon(Icons.kitchen_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.kitchen, color: AppTheme.coral),
          label: 'KDS',
        ),
      VendorCategoryType.scooterRental => const NavigationDestination(
          icon: Icon(Icons.electric_scooter_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.electric_scooter, color: AppTheme.coral),
          label: 'Fleet',
        ),
      VendorCategoryType.taxiOperator => const NavigationDestination(
          icon: Icon(Icons.local_taxi_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.local_taxi, color: AppTheme.coral),
          label: 'Fleet',
        ),
      VendorCategoryType.luggageCloak => const NavigationDestination(
          icon: Icon(Icons.luggage_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.luggage, color: AppTheme.coral),
          label: 'Capacity',
        ),
    };

    final tertiary = switch (_category) {
      VendorCategoryType.restaurant ||
      VendorCategoryType.cafe ||
      VendorCategoryType.pizzeria => const NavigationDestination(
          icon: Icon(Icons.restaurant_menu_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.restaurant_menu, color: AppTheme.coral),
          label: 'Menu',
        ),
      VendorCategoryType.pubClub => const NavigationDestination(
          icon: Icon(Icons.local_bar_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.local_bar, color: AppTheme.coral),
          label: 'Drinks',
        ),
      VendorCategoryType.scooterRental => const NavigationDestination(
          icon: Icon(Icons.pedal_bike_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.pedal_bike, color: AppTheme.coral),
          label: 'Rentals',
        ),
      VendorCategoryType.taxiOperator => const NavigationDestination(
          icon: Icon(Icons.directions_car_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.directions_car, color: AppTheme.coral),
          label: 'Rides',
        ),
      VendorCategoryType.luggageCloak => const NavigationDestination(
          icon: Icon(Icons.event_outlined, color: Color(0x80FFFFFF)),
          selectedIcon: Icon(Icons.event, color: AppTheme.coral),
          label: 'Bookings',
        ),
    };

    return [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined, color: Color(0x80FFFFFF)),
        selectedIcon: Icon(Icons.dashboard, color: AppTheme.coral),
        label: 'Dashboard',
      ),
      secondary,
      tertiary,
      const NavigationDestination(
        icon: Icon(Icons.qr_code_scanner_outlined, color: Color(0x80FFFFFF)),
        selectedIcon: Icon(Icons.qr_code_scanner, color: AppTheme.coral),
        label: 'Scanner',
      ),
      const NavigationDestination(
        icon: Icon(Icons.tune_outlined, color: Color(0x80FFFFFF)),
        selectedIcon: Icon(Icons.tune, color: AppTheme.coral),
        label: 'Manage',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        scrolledUnderElevation: 2,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.coral, AppTheme.coralLight],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_category.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _vendorName.isEmpty ? 'PondyConnect Partner' : _vendorName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _category.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _toggleAcceptingOrders,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _acceptingOrders
                    ? AppTheme.success.withValues(alpha: 0.15)
                    : AppTheme.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _acceptingOrders
                      ? AppTheme.success.withValues(alpha: 0.3)
                      : AppTheme.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_toggling)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    )
                  else
                    PulsingDot(
                      color: _acceptingOrders ? AppTheme.success : AppTheme.danger,
                      size: 8,
                      duration: const Duration(milliseconds: 1200),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _acceptingOrders ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _acceptingOrders ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.darkSurface,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          AppHaptics.selection();
          setState(() => _currentIndex = i);
        },
        indicatorColor: AppTheme.coral.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        destinations: _destinations,
      ),
    );
  }
}
