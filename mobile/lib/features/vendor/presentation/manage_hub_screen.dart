import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/vendor_auth_controller.dart';
import '../application/vendor_providers.dart';
import '../domain/vendor_category_type.dart';

class ManageHubScreen extends ConsumerWidget {
  const ManageHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailProvider);
    final session = ref.watch(vendorAuthControllerProvider).valueOrNull;
    final category = VendorCategoryType.fromString(session?.category);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text('Manage', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (session != null && session.hasMultipleBusinesses)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _showBusinessSwitcher(context, session),
                icon: const Icon(Icons.storefront, size: 18),
                label: Text(
                  session.vendorName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Venue status card — shows real API data or real error.
            venueAsync.when(
              loading: () => _buildShimmerCard(context),
              error: (e, _) => _buildVenueError(context, e.toString()),
              data: (venue) => venue == null
                  ? _buildNoVenue(context)
                  : _buildVenueCard(context, venue),
            ),
            const SizedBox(height: 16),
            // Management grid
            Text(
              'Operations',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: _buildCategoryTiles(context, category),
            ),
            const SizedBox(height: 24),
            // Quick stats
            Text(
              'Quick Actions',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickAction(
              context,
              icon: Icons.flash_on,
              label: 'Launch Flash Sale',
              subtitle: 'Time-limited discount to boost orders',
              color: AppTheme.gold,
              onTap: () {
                AppHaptics.light();
                context.push('/promotions');
              },
            ),
            const SizedBox(height: 8),
            // Category-specific quick action
            ..._buildCategoryQuickActions(context, category),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Builds the operations grid tiles based on the vendor category.
  /// Each category sees only the tiles relevant to its business type.
  List<Widget> _buildCategoryTiles(BuildContext context, VendorCategoryType category) {
    // Common tiles for ALL vendor types
    final commonTiles = <_ManageTile>[
      _ManageTile(
        icon: Icons.qr_code_scanner,
        label: 'Scanner',
        subtitle: 'Scan tickets & QR',
        color: AppTheme.gold,
        onTap: () { AppHaptics.light(); context.push('/scanner'); },
      ),
      _ManageTile(
        icon: Icons.account_balance_wallet,
        label: 'Wallet',
        subtitle: 'Balance & payouts',
        color: AppTheme.emerald,
        onTap: () { AppHaptics.light(); context.push('/wallet'); },
      ),
      _ManageTile(
        icon: Icons.campaign,
        label: 'Marketing',
        subtitle: 'Promotions & flash sales',
        color: AppTheme.emerald,
        onTap: () { AppHaptics.light(); context.push('/promotions'); },
      ),
      _ManageTile(
        icon: Icons.print,
        label: 'Printer',
        subtitle: 'Thermal printer setup',
        color: AppTheme.info,
        onTap: () { AppHaptics.light(); context.push('/printer-settings'); },
      ),
    ];

    // Category-specific tiles
    final categoryTiles = <_ManageTile>[];

    switch (category) {
      case VendorCategoryType.restaurant:
      case VendorCategoryType.cafe:
      case VendorCategoryType.pizzeria:
        categoryTiles.addAll([
          _ManageTile(
            icon: Icons.restaurant_menu,
            label: 'Menu',
            subtitle: 'Dishes & pricing',
            color: AppTheme.emerald,
            onTap: () { AppHaptics.light(); context.push('/menu'); },
          ),
          _ManageTile(
            icon: Icons.receipt_long,
            label: 'Orders',
            subtitle: 'Accept & track',
            color: AppTheme.info,
            onTap: () { AppHaptics.light(); context.push('/orders'); },
          ),
          _ManageTile(
            icon: Icons.kitchen,
            label: 'KDS',
            subtitle: 'Kitchen display',
            color: AppTheme.coral,
            onTap: () { AppHaptics.light(); context.push('/kds'); },
          ),
          _ManageTile(
            icon: Icons.money_off,
            label: 'Partial Refund',
            subtitle: 'Remove out-of-stock item',
            color: AppTheme.warning,
            onTap: () { AppHaptics.light(); context.push('/partial-refund'); },
          ),
        ]);
        break;
      case VendorCategoryType.pubClub:
        categoryTiles.addAll([
          _ManageTile(
            icon: Icons.local_bar,
            label: 'Drinks Menu',
            subtitle: 'Drinks & VIP packages',
            color: AppTheme.emerald,
            onTap: () { AppHaptics.light(); context.push('/drinks-menu'); },
          ),
          _ManageTile(
            icon: Icons.table_restaurant,
            label: 'Live Tables',
            subtitle: 'Cover charge tracking',
            color: AppTheme.info,
            onTap: () { AppHaptics.light(); context.push('/bookings'); },
          ),
          _ManageTile(
            icon: Icons.people,
            label: 'Occupancy',
            subtitle: 'Update live crowd %',
            color: AppTheme.gold,
            onTap: () { AppHaptics.light(); context.push('/occupancy'); },
          ),
        ]);
        break;
      case VendorCategoryType.scooterRental:
        categoryTiles.addAll([
          _ManageTile(
            icon: Icons.pedal_bike,
            label: 'Fleet',
            subtitle: 'Scooters & pricing',
            color: AppTheme.emerald,
            onTap: () { AppHaptics.light(); context.push('/fleet'); },
          ),
          _ManageTile(
            icon: Icons.assignment_return,
            label: 'Active Rentals',
            subtitle: 'Track rented scooters',
            color: AppTheme.info,
            onTap: () { AppHaptics.light(); context.push('/rentals'); },
          ),
          _ManageTile(
            icon: Icons.camera_alt,
            label: 'Condition Photos',
            subtitle: 'Pre-rental 5-angle capture',
            color: AppTheme.gold,
            onTap: () { AppHaptics.light(); context.push('/condition-photos'); },
          ),
          _ManageTile(
            icon: Icons.assignment_turned_in,
            label: 'Complete Return',
            subtitle: 'Inspect & close rental',
            color: AppTheme.coral,
            onTap: () { AppHaptics.light(); context.push('/rental-return'); },
          ),
        ]);
        break;
      case VendorCategoryType.taxiOperator:
        categoryTiles.addAll([
          _ManageTile(
            icon: Icons.local_taxi,
            label: 'Taxi Fleet',
            subtitle: 'Vehicles & drivers',
            color: AppTheme.emerald,
            onTap: () { AppHaptics.light(); context.push('/taxi-fleet'); },
          ),
          _ManageTile(
            icon: Icons.directions_car,
            label: 'Live Rides',
            subtitle: 'Track active rides',
            color: AppTheme.info,
            onTap: () { AppHaptics.light(); context.push('/rides'); },
          ),
          _ManageTile(
            icon: Icons.assignment_ind,
            label: 'Assign Driver',
            subtitle: 'Assign driver to trip',
            color: AppTheme.gold,
            onTap: () { AppHaptics.light(); context.push('/assign-driver'); },
          ),
        ]);
        break;
      case VendorCategoryType.luggageCloak:
        categoryTiles.addAll([
          _ManageTile(
            icon: Icons.luggage,
            label: 'Capacity',
            subtitle: 'Stored bags & occupancy',
            color: AppTheme.emerald,
            onTap: () { AppHaptics.light(); context.push('/capacity'); },
          ),
          _ManageTile(
            icon: Icons.event,
            label: 'Bookings',
            subtitle: 'Reservations & intake',
            color: AppTheme.info,
            onTap: () { AppHaptics.light(); context.push('/bookings'); },
          ),
          _ManageTile(
            icon: Icons.qr_code,
            label: 'Claim Check',
            subtitle: 'Walk-in QR generation',
            color: AppTheme.gold,
            onTap: () { AppHaptics.light(); context.push('/claim-check'); },
          ),
          _ManageTile(
            icon: Icons.camera_alt,
            label: 'Bag Intake',
            subtitle: 'Receive bags with photo',
            color: AppTheme.coral,
            onTap: () { AppHaptics.light(); context.push('/bag-intake'); },
          ),
          _ManageTile(
            icon: Icons.lock_open,
            label: 'Collect Bags',
            subtitle: 'PIN-based collection',
            color: AppTheme.emerald,
            onTap: () { AppHaptics.light(); context.push('/bag-collection'); },
          ),
        ]);
        break;
      case VendorCategoryType.partySupplier:
        categoryTiles.addAll([
          _ManageTile(
            icon: Icons.speaker,
            label: 'Equipment Inventory',
            subtitle: 'Speakers, lights & gear',
            color: AppTheme.emerald,
            onTap: () { AppHaptics.light(); context.push('/equipment-inventory'); },
          ),
          _ManageTile(
            icon: Icons.inventory_2,
            label: 'Active Rentals',
            subtitle: 'Asset tracking Kanban',
            color: AppTheme.info,
            onTap: () { AppHaptics.light(); context.push('/equipment-rentals'); },
          ),
        ]);
        break;
    }

    return [...categoryTiles, ...commonTiles];
  }

  List<Widget> _buildCategoryQuickActions(BuildContext context, VendorCategoryType category) {
    switch (category) {
      case VendorCategoryType.restaurant:
      case VendorCategoryType.cafe:
      case VendorCategoryType.pizzeria:
        return [
          _buildQuickAction(context,
              icon: Icons.restaurant_menu,
              label: 'Add Menu Item',
              subtitle: 'Add a new dish to your menu',
              color: AppTheme.emerald,
              onTap: () { AppHaptics.light(); context.push('/menu'); }),
          const SizedBox(height: 8),
        ];
      case VendorCategoryType.pubClub:
        return [
          _buildQuickAction(context,
              icon: Icons.local_bar,
              label: 'Add Drink',
              subtitle: 'Add a new drink to your menu',
              color: AppTheme.emerald,
              onTap: () { AppHaptics.light(); context.push('/drinks-menu'); }),
          const SizedBox(height: 8),
        ];
      case VendorCategoryType.scooterRental:
        return [
          _buildQuickAction(context,
              icon: Icons.pedal_bike,
              label: 'View Active Rentals',
              subtitle: 'Track scooters currently rented',
              color: AppTheme.emerald,
              onTap: () { AppHaptics.light(); context.push('/rentals'); }),
          const SizedBox(height: 8),
        ];
      case VendorCategoryType.taxiOperator:
        return [
          _buildQuickAction(context,
              icon: Icons.directions_car,
              label: 'View Active Rides',
              subtitle: 'Track taxis currently on duty',
              color: AppTheme.emerald,
              onTap: () { AppHaptics.light(); context.push('/rides'); }),
          const SizedBox(height: 8),
        ];
      case VendorCategoryType.luggageCloak:
        return [
          _buildQuickAction(context,
              icon: Icons.luggage,
              label: 'View Stored Bags',
              subtitle: 'Check cloak occupancy and stored items',
              color: AppTheme.emerald,
              onTap: () { AppHaptics.light(); context.push('/capacity'); }),
          const SizedBox(height: 8),
        ];
      case VendorCategoryType.partySupplier:
        return [
          _buildQuickAction(context,
              icon: Icons.speaker,
              label: 'Add Equipment',
              subtitle: 'Add a new item to your rental inventory',
              color: AppTheme.emerald,
              onTap: () { AppHaptics.light(); context.push('/equipment-inventory'); }),
          const SizedBox(height: 8),
        ];
    }
  }

  /// Shows a bottom sheet listing all businesses owned by this partner.
  /// Tapping a business switches the active vendor context.
  void _showBusinessSwitcher(BuildContext context, VendorAuthSession session) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Switch Business',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...session.businesses.map((b) {
              final isActive = b.vendorId == session.vendorId;
              return ListTile(
                leading: Icon(
                  VendorCategoryType.fromString(b.category).icon,
                  color: isActive ? AppTheme.emerald : null,
                ),
                title: Text(
                  b.name,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${VendorCategoryType.fromString(b.category).displayName} · ${b.status}',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: isActive
                    ? const Icon(Icons.check_circle, color: AppTheme.emerald)
                    : null,
                onTap: () {
                  AppHaptics.selection();
                  Navigator.pop(ctx);
                  // TODO: Switch active vendor context — requires
                  // persisting the selected vendorId and passing it as
                  // a query param to vendor API calls.
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueCard(BuildContext context, dynamic venue) {
    final isActive = venue?.isActive ?? false;
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (isActive ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.emerald, AppTheme.emeraldLight]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.store, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue?.name ?? 'No venue set up',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isActive ? Icons.check_circle : Icons.pause_circle,
                        color: isActive ? AppTheme.success : AppTheme.danger,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? 'Active' : 'Paused',
                        style: TextStyle(
                          color: isActive ? AppTheme.success : AppTheme.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (venue?.category != null && venue.category.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '\u00B7 ${venue.category}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: AppTheme.emerald),
              onPressed: () {
                AppHaptics.light();
                context.push('/venue');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  Widget _buildVenueError(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.danger, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load venue: $error',
              style: TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVenue(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.store_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No venue linked to your account. Contact admin to link your venue.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: isDisabled ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDisabled
                ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDisabled ? 0.08 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isDisabled ? color.withValues(alpha: 0.6) : color, size: 22),
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5) : Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDisabled
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
