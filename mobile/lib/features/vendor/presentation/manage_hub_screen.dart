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
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Manage', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Venue status card
            venueAsync.when(
              loading: () => _buildShimmerCard(context),
              error: (_, __) => _buildVenueCard(context, null),
              data: (venue) => _buildVenueCard(context, venue),
            ),
            const SizedBox(height: 16),
            // Management grid
            const Text(
              'Operations',
              style: TextStyle(
                color: Colors.white,
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
              children: [
                _ManageTile(
                  icon: Icons.receipt_long,
                  label: 'Live Orders',
                  subtitle: 'Accept & track delivery orders',
                  color: AppTheme.info,
                  onTap: () {
                    AppHaptics.light();
                    context.push('/orders');
                  },
                ),
                _ManageTile(
                  icon: Icons.event,
                  label: 'Bookings',
                  subtitle: 'Manage reservations & status',
                  color: AppTheme.gold,
                  onTap: () {
                    AppHaptics.light();
                    context.push('/bookings');
                  },
                ),
                _ManageTile(
                  icon: Icons.local_offer,
                  label: 'Promotions',
                  subtitle: 'Discounts & flash sales',
                  color: AppTheme.coral,
                  onTap: () {
                    AppHaptics.light();
                    context.push('/promotions');
                  },
                ),
                _ManageTile(
                  icon: Icons.account_balance_wallet,
                  label: 'Wallet',
                  subtitle: 'Credits & transactions',
                  color: AppTheme.emerald,
                  onTap: () {
                    AppHaptics.light();
                    context.push('/wallet');
                  },
                ),
                _ManageTile(
                  icon: Icons.store,
                  label: 'Venue Profile',
                  subtitle: 'Edit venue details & hours',
                  color: AppTheme.emerald,
                  onTap: () {
                    AppHaptics.light();
                    context.push('/venue');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Quick stats
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
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
    }
  }

  Widget _buildVenueCard(BuildContext context, dynamic venue) {
    final isActive = venue?.isActive ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isActive ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.coral, AppTheme.coralLight]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue?.name ?? 'No venue set up',
                  style: const TextStyle(
                    color: Colors.white,
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
                          color: Colors.white.withValues(alpha: 0.4),
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
            icon: const Icon(Icons.edit, color: AppTheme.coral),
            onPressed: () {
              AppHaptics.light();
              context.push('/venue');
            },
          ),
        ],
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
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.2)),
        ),
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
          ],
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
