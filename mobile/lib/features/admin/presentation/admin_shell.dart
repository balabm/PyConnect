import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';

/// The main admin shell with a navigation rail for switching between
/// dashboard sections. This is the "God Mode" single point of control.
/// Uses the unified admin dark SaaS theme.
///
/// Restructured to 5 primary tabs per the PY Connect MasterPlan:
///   1. Analytics & Metrics   → /
///   2. Merchant Approvals    → /vendors
///   3. Captain KYC Queue     → /drivers
///   4. Live Ops & SOS        → /rides
///   5. Finance & Audit       → /finance
///
/// Secondary routes (users, tickets, audit logs, sos) remain accessible
/// from the dashboard / sub-menus but are not shown as primary nav items.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell>
    with SingleTickerProviderStateMixin {
  /// Primary navigation destinations (5 tabs per MasterPlan).
  static const _destinations = [
    _NavDest(
      icon: Icons.insights_rounded,
      label: 'Analytics & Metrics',
      path: '/',
    ),
    _NavDest(
      icon: Icons.store_rounded,
      label: 'Merchant Approvals',
      path: '/vendors',
    ),
    _NavDest(
      icon: Icons.badge_rounded,
      label: 'Captain KYC Queue',
      path: '/drivers',
    ),
    _NavDest(
      icon: Icons.directions_car_rounded,
      label: 'Live Ops & SOS',
      path: '/rides',
    ),
    _NavDest(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Finance & Audit',
      path: '/finance',
    ),
  ];

  /// Secondary destinations surfaced as a "More" sub-menu on the desktop
  /// rail and accessible from the dashboard. Keeps existing routes working.
  static const _secondaryDestinations = [
    _NavDest(icon: Icons.people_rounded, label: 'Users', path: '/users'),
    _NavDest(icon: Icons.warning_rounded, label: 'SOS Alerts', path: '/sos'),
    _NavDest(
      icon: Icons.support_agent_rounded,
      label: 'Tickets',
      path: '/tickets',
    ),
    _NavDest(icon: Icons.history_rounded, label: 'Audit Logs', path: '/logs'),
  ];

  late final AnimationController _sosBannerController;

  @override
  void initState() {
    super.initState();
    // Flash the SOS banner by alternating opacity 0.5 ↔ 1.0 every second.
    _sosBannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.5,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _sosBannerController.dispose();
    super.dispose();
  }

  int _selectedIndex(String location) {
    for (var i = _destinations.length - 1; i >= 0; i--) {
      if (location.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  /// Count of active (unresolved) SOS alerts, derived from the live SOS
  /// alerts stream provider.
  int _activeSosCount() {
    final sosAsync = ref.read(adminSosAlertsProvider);
    final alerts = sosAsync.valueOrNull ?? const [];
    return alerts.where((a) => a.status.toLowerCase() != 'resolved').length;
  }

  @override
  Widget build(BuildContext context) {
    // Watch the SignalR event handler to keep the real-time subscription alive.
    ref.watch(adminSignalREventHandlerProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final index = _selectedIndex(location);
    final hasCritical = ref.watch(hasUnacknowledgedCriticalProvider);
    final isWide = MediaQuery.of(context).size.width >= 1100;

    // Drive the flashing animation only while there are active SOS alerts.
    final activeSos = _activeSosCount();
    if (activeSos > 0) {
      _sosBannerController
        ..repeat(reverse: true)
        ..value = _sosBannerController.isAnimating
            ? _sosBannerController.value
            : 1.0;
    } else {
      _sosBannerController.stop();
    }

    return Scaffold(
      body: Column(
        children: [
          // Flashing red SOS banner — shown only when there are active alerts.
          if (activeSos > 0)
            _SosBanner(
              controller: _sosBannerController,
              count: activeSos,
              onTap: () => context.go('/sos'),
            ),
          Expanded(
            child: Row(
              children: [
                if (isWide) ...[
                  _buildNavRail(
                    context,
                    index,
                    isExtended: true,
                    hasCritical: hasCritical,
                  ),
                  Container(width: 1, color: AdminColors.border),
                ] else ...[
                  _buildNavRail(
                    context,
                    index,
                    isExtended: false,
                    hasCritical: hasCritical,
                  ),
                ],
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              destinations: _destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.icon, color: AdminColors.accent),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildNavRail(
    BuildContext context,
    int index, {
    required bool isExtended,
    required bool hasCritical,
  }) {
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.emeraldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AdminColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'God Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'PY Connect',
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.emeraldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AdminColors.textPrimary,
                  size: 22,
                ),
              ),
            ),
      trailing: isExtended ? _buildMoreMenu(context, hasCritical) : null,
      destinations: _destinations
          .map(
            (d) => NavigationRailDestination(
              icon: Icon(d.icon),
              label: Text(d.label),
            ),
          )
          .toList(),
    );
  }

  /// "More" sub-menu exposing secondary routes (Users, SOS, Tickets, Logs)
  /// so the existing routes remain reachable from the desktop rail without
  /// crowding the 5 primary tabs. Also includes a Sign out action.
  Widget _buildMoreMenu(BuildContext context, bool hasCritical) {
    return PopupMenuButton<String>(
      tooltip: 'More sections',
      icon: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.more_horiz_rounded, color: AdminColors.textMuted),
          if (true) SizedBox(width: 6),
          Text(
            'More',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 14),
          ),
        ],
      ),
      color: AdminColors.surface,
      onSelected: (value) {
        if (value == '__logout__') {
          ref.read(authControllerProvider.notifier).signOut();
          return;
        }
        context.go(value);
      },
      itemBuilder: (_) => [
        ..._secondaryDestinations.map((d) {
          final isSos = d.path == '/sos';
          return PopupMenuItem<String>(
            value: d.path,
            child: Row(
              children: [
                Icon(d.icon, color: AdminColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  d.label,
                  style: const TextStyle(color: AdminColors.textPrimary),
                ),
                if (isSos && hasCritical) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AdminColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 10,
                      minHeight: 10,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__logout__',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: AdminColors.danger, size: 20),
              SizedBox(width: 12),
              Text(
                'Sign out',
                style: TextStyle(color: AdminColors.danger),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Flashing red SOS banner
// ---------------------------------------------------------------------------

/// A full-width red banner shown at the top of the admin shell when there
/// are active (unresolved) SOS alerts. It flashes by alternating opacity
/// between 0.5 and 1.0 every second via [controller]. Tapping it navigates
/// to the SOS screen.
class _SosBanner extends StatelessWidget {
  const _SosBanner({
    required this.controller,
    required this.count,
    required this.onTap,
  });

  final AnimationController controller;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(
          opacity: controller.value,
          child: child,
        );
      },
      child: Material(
        color: AdminColors.danger,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ACTIVE SOS ALERT — $count unresolved alert${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDest {
  const _NavDest({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}
