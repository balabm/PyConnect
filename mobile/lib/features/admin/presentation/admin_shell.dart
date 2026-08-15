import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';

/// The main admin shell with a navigation rail for switching between
/// dashboard sections. This is the "God Mode" single point of control.
/// Uses the unified admin dark SaaS theme.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    _NavDest(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/'),
    _NavDest(icon: Icons.people_rounded, label: 'Users', path: '/users'),
    _NavDest(icon: Icons.two_wheeler_rounded, label: 'Drivers', path: '/drivers'),
    _NavDest(icon: Icons.store_rounded, label: 'Vendors', path: '/vendors'),
    _NavDest(icon: Icons.directions_car_rounded, label: 'Live Rides', path: '/rides'),
    _NavDest(icon: Icons.warning_rounded, label: 'SOS Alerts', path: '/sos'),
    _NavDest(icon: Icons.support_agent_rounded, label: 'Tickets', path: '/tickets'),
    _NavDest(icon: Icons.history_rounded, label: 'Audit Logs', path: '/logs'),
  ];

  int _selectedIndex(String location) {
    for (var i = _destinations.length - 1; i >= 0; i--) {
      if (location.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the SignalR event handler to keep the real-time subscription alive.
    ref.watch(adminSignalREventHandlerProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final index = _selectedIndex(location);
    final hasCritical = ref.watch(hasUnacknowledgedCriticalProvider);
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      body: Row(
        children: [
          if (isWide) ...[
            _buildNavRail(context, index, isExtended: true, hasCritical: hasCritical),
            Container(width: 1, color: AdminColors.border),
          ] else ...[
            _buildNavRail(context, index, isExtended: false, hasCritical: hasCritical),
          ],
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              destinations: _destinations.take(5).map((d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.icon, color: AdminColors.accent),
                label: d.label,
              )).toList(),
            ),
    );
  }

  Widget _buildNavRail(BuildContext context, int index, {required bool isExtended, required bool hasCritical}) {
    return NavigationRail(
      extended: isExtended,
      selectedIndex: index,
      onDestinationSelected: (i) => context.go(_destinations[i].path),
      backgroundColor: AdminColors.bg,
      selectedIconTheme: const IconThemeData(color: AdminColors.accent),
      unselectedIconTheme: const IconThemeData(color: AdminColors.textMuted),
      selectedLabelTextStyle: const TextStyle(
        color: AdminColors.accent,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AdminColors.textMuted,
        fontSize: 14,
      ),
      indicatorColor: AdminColors.accent.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      leading: isExtended
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.emeraldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: AdminColors.textPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('God Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary)),
                        const Text('PY Connect', style: TextStyle(fontSize: 11, color: AdminColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.emeraldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: AdminColors.textPrimary, size: 22),
              ),
            ),
      destinations: _destinations.map((d) {
        final isSos = d.path == '/sos';
        return NavigationRailDestination(
          icon: Stack(
            children: [
              Icon(d.icon),
              if (isSos && hasCritical)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: AdminColors.danger, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                  ),
                ),
            ],
          ),
          label: Text(d.label),
        );
      }).toList(),
    );
  }
}

class _NavDest {
  const _NavDest({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}
