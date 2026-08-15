import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/profile_screen.dart';
import '../features/essentials/presentation/essentials_screen.dart';
import '../features/experiences/presentation/experiences_screen.dart';
import '../features/food/presentation/restaurant_list_screen.dart';
import '../features/home/presentation/contextual_home.dart';
import '../features/rides/presentation/rides_screen.dart';
import '../features/stays/presentation/stays_screen.dart';
import '../features/transit/presentation/transit_screen.dart';
import '../features/venues/presentation/venue_list_screen.dart';

/// Root scaffold hosting the app hubs behind a shared bottom navigation.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Hub();
  }
}

class _Hub extends ConsumerWidget {
  const _Hub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _indexFor(GoRouterState.of(context).uri.path);

    return Scaffold(
      body: index == 0
          ? Column(
              children: [
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: const ContextualHome(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildStack(index)),
              ],
            )
          : _buildStack(index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/food');
            case 2:
              context.go('/essentials');
            case 3:
              context.go('/rides');
            case 4:
              context.go('/transit');
            case 5:
              context.go('/experiences');
            case 6:
              context.go('/stays');
            default:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_bar_outlined),
            selectedIcon: Icon(Icons.local_bar),
            label: 'Vibe',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Food',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Ride',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: 'Transit',
          ),
          NavigationDestination(
            icon: Icon(Icons.museum_outlined),
            selectedIcon: Icon(Icons.museum),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.bed_outlined),
            selectedIcon: Icon(Icons.bed),
            label: 'Stays',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  static int _indexFor(String path) {
    if (path.startsWith('/food')) return 1;
    if (path.startsWith('/essentials')) return 2;
    if (path.startsWith('/rides')) return 3;
    if (path.startsWith('/transit')) return 4;
    if (path.startsWith('/experiences')) return 5;
    if (path.startsWith('/stays')) return 6;
    if (path.startsWith('/profile')) return 7;
    return 0;
  }

  static Widget _buildStack(int index) {
    return IndexedStack(
      index: index,
      children: const [
        VenueListScreen(),
        RestaurantListScreen(),
        EssentialsScreen(),
        RideHailingScreen(),
        TransitScreen(),
        ExperiencesScreen(),
        StaysScreen(),
        ProfileScreen(),
      ],
    );
  }
}
