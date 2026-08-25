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
import '../features/vendor/presentation/equipment_inventory_screen.dart';
import '../features/vendor/presentation/equipment_rentals_screen.dart';
import '../features/vendor/presentation/crowd_dashboard_screen.dart';
import '../features/vendor/presentation/vendor_event_manager_screen.dart';
import '../features/vendor/presentation/promo_sheet.dart';
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
    // Wakelock is enabled conditionally after _loadVenueInfo determines
    // the accepting-orders status. We enable it here as a safe default
    // so the screen doesn't sleep before the profile loads.
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
      // Load the master "Accepting Orders" status from the vendor profile.
      final api = ref.read(vendorDashboardApiProvider);
      final profile = await api.getProfile();
      if (mounted) {
        setState(() {
          _acceptingOrders = profile.isAcceptingOrders;
        });
        // Sync the wakelock with the accepting-orders status.
        // The tablet screen must NEVER dim or sleep while the restaurant
        // is open and accepting orders. When paused, allow the screen to
        // sleep normally to save battery.
        if (profile.isAcceptingOrders) {
          KeepAwakeService.enable();
        } else {
          KeepAwakeService.disable();
        }
      }
      // Also load venue info for the dashboard screen.
      final venues = await api.getVenues();
      if (venues.isNotEmpty && mounted) {
        setState(() {
          _venueId = venues.first.venueId;
        });
      }
    } catch (e) {
      debugPrint('PartnerShell: venue load failed: $e');
    }
  }

  Future<void> _toggleAcceptingOrders() async {
    if (_toggling) return;
    AppHaptics.light();
    setState(() => _toggling = true);
    try {
      final newStatus = !_acceptingOrders;
      final isAccepting =
          await ref.read(vendorDashboardApiProvider).toggleStatus(newStatus);
      if (mounted) {
        setState(() {
          _acceptingOrders = isAccepting;
          _toggling = false;
        });
        // Toggle the wakelock based on the new accepting-orders status.
        // Screen stays awake while accepting orders; sleeps when paused.
        if (isAccepting) {
          KeepAwakeService.enable();
        } else {
          KeepAwakeService.disable();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAccepting ? 'Now accepting orders' : 'Orders paused',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: isAccepting ? AppTheme.emerald : AppTheme.danger,
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
            CrowdDashboardScreen(),
            VendorEventManagerScreen(),
            DrinksMenuScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.scooterRental => const [
            VendorDashboardScreen(),
            ActiveRentalsScreen(),
            FleetManagementScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.taxiOperator => const [
            VendorDashboardScreen(),
            TaxiRidesScreen(),
            TaxiFleetScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.luggageCloak => const [
            VendorDashboardScreen(),
            VendorBookingsScreen(),
            CloakCapacityScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
        VendorCategoryType.partySupplier => const [
            VendorDashboardScreen(),
            EquipmentRentalsScreen(),
            EquipmentInventoryScreen(),
            ScannerScreen(),
            ManageHubScreen(),
          ],
      };

  List<NavigationDestination> _buildDestinations(BuildContext context) {
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final selectedColor = AppTheme.emerald;

    final secondary = switch (_category) {
      VendorCategoryType.restaurant ||
      VendorCategoryType.cafe ||
      VendorCategoryType.pizzeria => NavigationDestination(
          icon: Icon(Icons.kitchen_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.kitchen, color: selectedColor),
          label: 'KDS',
        ),
      VendorCategoryType.pubClub => NavigationDestination(
          icon: Icon(Icons.event_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.event, color: selectedColor),
          label: 'Events',
        ),
      VendorCategoryType.scooterRental => NavigationDestination(
          icon: Icon(Icons.pedal_bike_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.pedal_bike, color: selectedColor),
          label: 'Active Rentals',
        ),
      VendorCategoryType.taxiOperator => NavigationDestination(
          icon: Icon(Icons.directions_car_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.directions_car, color: selectedColor),
          label: 'Live Rides',
        ),
      VendorCategoryType.luggageCloak => NavigationDestination(
          icon: Icon(Icons.luggage_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.luggage, color: selectedColor),
          label: 'Storage Intake',
        ),
      VendorCategoryType.partySupplier => NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.inventory_2, color: selectedColor),
          label: 'Active Rentals',
        ),
    };

    final tertiary = switch (_category) {
      VendorCategoryType.restaurant ||
      VendorCategoryType.cafe ||
      VendorCategoryType.pizzeria => NavigationDestination(
          icon: Icon(Icons.restaurant_menu_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.restaurant_menu, color: selectedColor),
          label: 'Food Menu',
        ),
      VendorCategoryType.pubClub => NavigationDestination(
          icon: Icon(Icons.local_bar_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.local_bar, color: selectedColor),
          label: 'Drinks & VIP',
        ),
      VendorCategoryType.scooterRental => NavigationDestination(
          icon: Icon(Icons.electric_scooter_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.electric_scooter, color: selectedColor),
          label: 'Fleet',
        ),
      VendorCategoryType.taxiOperator => NavigationDestination(
          icon: Icon(Icons.local_taxi_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.local_taxi, color: selectedColor),
          label: 'Taxi Fleet',
        ),
      VendorCategoryType.luggageCloak => NavigationDestination(
          icon: Icon(Icons.event_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.event, color: selectedColor),
          label: 'Capacity',
        ),
      VendorCategoryType.partySupplier => NavigationDestination(
          icon: Icon(Icons.speaker_outlined, color: inactiveColor),
          selectedIcon: Icon(Icons.speaker, color: selectedColor),
          label: 'Inventory',
        ),
    };

    return [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined, color: inactiveColor),
        selectedIcon: Icon(Icons.dashboard, color: selectedColor),
        label: 'Dashboard',
      ),
      secondary,
      tertiary,
      NavigationDestination(
        icon: Icon(Icons.qr_code_scanner_outlined, color: inactiveColor),
        selectedIcon: Icon(Icons.qr_code_scanner, color: selectedColor),
        label: 'Scanner',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined, color: inactiveColor),
        selectedIcon: Icon(Icons.tune, color: selectedColor),
        label: 'Manage',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                    _vendorName.isEmpty ? 'PY Connect Partner' : _vendorName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _category.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('You will need to log in again with your phone number.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Sign out', style: TextStyle(color: AppTheme.danger)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(vendorAuthControllerProvider.notifier).signOut();
              }
            },
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _toggling ? null : _toggleAcceptingOrders,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _acceptingOrders ? AppTheme.emerald : AppTheme.danger,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (_acceptingOrders ? AppTheme.emerald : AppTheme.danger).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_toggling)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const PulsingDot(
                      color: Colors.white,
                      size: 8,
                      duration: Duration(milliseconds: 1200),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _acceptingOrders ? 'OPEN' : 'CLOSED',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      floatingActionButton: _category == VendorCategoryType.pubClub
          ? FloatingActionButton.extended(
              onPressed: () => PromoSheet.show(context),
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.flash_on),
              label: const Text('Boost'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          AppHaptics.selection();
          setState(() => _currentIndex = i);
        },
        destinations: _buildDestinations(context),
      ),
    );
  }
}
