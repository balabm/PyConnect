import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/restaurant_card.dart';

final restaurantListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(foodApiProvider);
  return await api.listVendors(foodVendorsOnly: true);
});

class RestaurantListScreen extends ConsumerStatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  ConsumerState<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends ConsumerState<RestaurantListScreen> {
  String _searchQuery = '';
  String? _cuisineFilter;

  static const _cuisines = [
    'Italian', 'Indian', 'Chinese', 'French', 'Cafe',
    'Bakery', 'Breakfast', 'Street Food', 'Seafood'
  ];

  List<dynamic> _filterRestaurants(List<dynamic> vendors) {
    if (_searchQuery.isEmpty && _cuisineFilter == null) return vendors;
    return vendors.where((vendor) {
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
    final restaurantsAsync = ref.watch(restaurantListProvider);

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
                    borderSide: const BorderSide(color: AppTheme.lagoon, width: 2),
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
              loading: () => const ShimmerList(withImage: false, count: 6),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(restaurantListProvider),
              ),
              data: (vendors) {
                final filtered = _filterRestaurants(vendors);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'No restaurants found',
                    subtitle: 'Try a different search or cuisine.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () {
                    AppHaptics.light();
                    return ref.refresh(restaurantListProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final vendor = filtered[index] as Map<String, dynamic>;
                      return FadeSlideIn(
                        delay: Duration(milliseconds: index * 60),
                        child: RestaurantCard(vendor: vendor),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.lagoon : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppTheme.lagoon : Theme.of(context).dividerColor,
            ),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.lagoon.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
