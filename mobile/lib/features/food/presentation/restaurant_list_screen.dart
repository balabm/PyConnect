import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';
import 'widgets/restaurant_card.dart';
import '../../../core/widgets/skeleton_loaders.dart';

final restaurantListProvider =
    FutureProvider.family<List<dynamic>, bool>((ref, foodVendorsOnly) async {
  final api = ref.watch(foodApiProvider);
  return await api.listVendors(foodVendorsOnly: foodVendorsOnly);
});

class RestaurantListScreen extends ConsumerStatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  ConsumerState<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends ConsumerState<RestaurantListScreen> {
  String _searchQuery = '';
  String? _cuisineFilter;
  bool _foodVendorsOnly = true; // true = Food Delivery, false = Quick Essentials

  /// Vendor categories that serve food and should appear in the Food Delivery tab.
  /// Matches the backend VendorCategory enum names returned as strings in the API response.
  static const _foodCategories = {'Restaurant', 'Cafe', 'Pizzeria'};

  static const _cuisines = [
    'Italian', 'Indian', 'Chinese', 'French', 'Cafe',
    'Bakery', 'Breakfast', 'Street Food', 'Seafood'
  ];

  List<dynamic> _filterRestaurants(List<dynamic> vendors) {
    // Client-side category safety net: ensure non-food vendors (e.g. LuggageCloak,
  // ScooterRental, TaxiOperator) never appear in the Food Delivery tab, and food
  // vendors never appear in the Quick Essentials tab — even if the backend filter
  // is missed or returns unexpected data.
    final categoryFiltered = vendors.where((vendor) {
      final map = vendor as Map<String, dynamic>;
      final category = map['category'] as String? ?? '';
      final isFood = _foodCategories.contains(category);
      return _foodVendorsOnly ? isFood : !isFood;
    }).toList();

    if (_searchQuery.isEmpty && _cuisineFilter == null) return categoryFiltered;
    return categoryFiltered.where((vendor) {
      final map = vendor as Map<String, dynamic>;
      final name = (map['name'] as String? ?? '').toLowerCase();
      final cuisine = map['cuisineType'] as String? ?? '';
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCuisine = _cuisineFilter == null || cuisine == _cuisineFilter;
      return matchesSearch && matchesCuisine;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantListProvider(_foodVendorsOnly));
    // Watch the real-time vendor status map so cards update instantly.
    final statusMap = ref.watch(vendorAcceptingOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Delivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Order History',
            onPressed: () {
              AppHaptics.light();
              context.push('/food/orders');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Food Delivery / Quick Essentials segmented toggle
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.restaurant_outlined, size: 18),
                    label: Text('Food Delivery'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.shopping_bag_outlined, size: 18),
                    label: Text('Quick Essentials'),
                  ),
                ],
                selected: {_foodVendorsOnly},
                onSelectionChanged: (selection) {
                  AppHaptics.selection();
                  setState(() => _foodVendorsOnly = selection.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.emerald;
                    }
                    return Theme.of(context).colorScheme.surfaceContainerHighest;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return Theme.of(context).colorScheme.onSurfaceVariant;
                  }),
                  side: WidgetStateProperty.all(
                    BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
              ),
            ),
          ),
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search restaurants...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: AppTheme.emerald, width: 2),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildPill('All', _cuisineFilter == null, () {
                    AppHaptics.selection();
                    setState(() => _cuisineFilter = null);
                  }),
                  ..._cuisines.map((c) => _buildPill(c, _cuisineFilter == c, () {
                        AppHaptics.selection();
                        setState(() => _cuisineFilter = c);
                      })),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: restaurantsAsync.when(
              loading: () => const SkeletonList(type: SkeletonType.restaurant, count: 6),
              error: (e, _) => EmptyStateView(
                isError: true,
                icon: Icons.cloud_off_rounded,
                title: 'Something went wrong',
                subtitle: e.toString(),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(restaurantListProvider(_foodVendorsOnly)),
              ),
              data: (vendors) {
                // Seed the real-time status map with the initial API data.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(vendorAcceptingOrdersProvider.notifier).seedFromVendorList(vendors);
                });
                final filtered = _filterRestaurants(vendors);
                if (filtered.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.restaurant_outlined,
                    title: 'No restaurants found',
                    subtitle: 'Try a different search or cuisine.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () {
                    AppHaptics.light();
                    return ref.refresh(restaurantListProvider(_foodVendorsOnly).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final vendor = filtered[index] as Map<String, dynamic>;
                      final vendorId = vendor['id'] as String? ?? '';
                      final isAccepting = statusMap[vendorId] ??
                          (vendor['isAcceptingOrders'] as bool? ?? true);
                      return FadeSlideIn(
                        delay: Duration(milliseconds: index * 60),
                        child: RestaurantCard(
                          vendor: vendor,
                          isAcceptingOrders: isAccepting,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, bool selected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.charcoal
                : isDark ? AppTheme.darkCard : AppTheme.searchFill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? Colors.white
                  : isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
            ),
          ),
        ),
      ),
    );
  }
}
