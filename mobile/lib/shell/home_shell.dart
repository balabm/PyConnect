import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/floating_nav_bar.dart';
import '../features/activity/presentation/activity_hub_screen.dart';
import '../features/food/presentation/restaurant_list_screen.dart';
import '../features/hub/services_hub_screen.dart';
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
      body: _buildStack(index),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/food');
            case 2:
              context.go('/transit');
            case 3:
              context.go('/stays');
            case 4:
              context.go('/activity');
            default:
              context.go('/hub');
          }
        },
        destinations: const [
          FloatingNavDestination(
            icon: Icons.local_bar_outlined,
            activeIcon: Icons.local_bar,
            label: 'Vibe',
          ),
          FloatingNavDestination(
            icon: Icons.restaurant_outlined,
            activeIcon: Icons.restaurant,
            label: 'Food',
          ),
          FloatingNavDestination(
            icon: Icons.commute_outlined,
            activeIcon: Icons.commute,
            label: 'Transit',
          ),
          FloatingNavDestination(
            icon: Icons.bed_outlined,
            activeIcon: Icons.bed,
            label: 'Stays',
          ),
          FloatingNavDestination(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long,
            label: 'Activity',
          ),
          FloatingNavDestination(
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view,
            label: 'More',
          ),
        ],
      ),
    );
  }

  static int _indexFor(String path) {
    if (path.startsWith('/food')) return 1;
    if (path.startsWith('/transit')) return 2;
    if (path.startsWith('/rides')) return 2;
    if (path.startsWith('/rentals')) return 2;
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
        TransitScreen(),
        StaysScreen(),
        ActivityHubScreen(),
        ServicesHubScreen(),
      ],
    );
  }
}
