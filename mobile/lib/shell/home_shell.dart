import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/presentation/activity_hub_screen.dart';
import '../features/food/presentation/restaurant_list_screen.dart';
import '../features/hub/services_hub_screen.dart';
import '../features/rides/presentation/rides_screen.dart';
import '../features/stays/presentation/stays_screen.dart';
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
      body: SafeArea(child: _buildStack(index)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/food');
            case 2:
              context.go('/rides');
            case 3:
              context.go('/stays');
            case 4:
              context.go('/activity');
            default:
              context.go('/hub');
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
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Ride',
          ),
          NavigationDestination(
            icon: Icon(Icons.bed_outlined),
            selectedIcon: Icon(Icons.bed),
            label: 'Stays',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }

  static int _indexFor(String path) {
    if (path.startsWith('/food')) return 1;
    if (path.startsWith('/rides')) return 2;
    if (path.startsWith('/stays')) return 3;
    if (path.startsWith('/activity')) return 4;
    if (path.startsWith('/hub')) return 5;
    return 0;
  }

  static Widget _buildStack(int index) {
    return IndexedStack(
      index: index,
      children: const [
        VenueListScreen(),
        RestaurantListScreen(),
        RideHailingScreen(),
        StaysScreen(),
        ActivityHubScreen(),
        ServicesHubScreen(),
      ],
    );
  }
}
