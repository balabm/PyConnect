import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/modern_animations.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final sosAsync = ref.watch(adminSosAlertsProvider);
    final ridesAsync = ref.watch(adminActiveRidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Dashboard'),
            const SizedBox(width: 10),
            _LiveBadge(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminDashboardStatsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
        error: (e, _) => _ErrorCard(message: e.toString(), onRetry: () => ref.invalidate(adminDashboardStatsProvider)),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Critical alerts banner
            if (stats.activeSosAlerts > 0 || stats.openSupportTickets > 0)
              _CriticalBanner(
                sosCount: stats.activeSosAlerts,
                ticketCount: stats.openSupportTickets,
                onSosTap: () => context.go('/sos'),
                onTicketTap: () => context.go('/tickets'),
              ),
            if (stats.activeSosAlerts > 0 || stats.openSupportTickets > 0)
              const SizedBox(height: 24),
            // Stats grid — enterprise metric cards with prominent stat numbers
            LayoutBuilder(builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 1200 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.people_rounded,
                    label: 'TOTAL USERS',
                    value: stats.totalUsers,
                    subtitle: '${stats.activeUsers} active',
                    color: AdminColors.accent,
                    onTap: () => context.go('/users'),
                  ),
                  _StatCard(
                    icon: Icons.two_wheeler_rounded,
                    label: 'DRIVERS',
                    value: stats.totalDrivers,
                    subtitle: '${stats.onlineDrivers} online · ${stats.approvedDrivers} approved',
                    color: AdminColors.info,
                    onTap: () => context.go('/drivers'),
                  ),
                  _StatCard(
                    icon: Icons.store_rounded,
                    label: 'VENDORS',
                    value: stats.totalVendors,
                    subtitle: '${stats.approvedVendors} approved · ${stats.totalVenues} venues',
                    color: AdminColors.warning,
                    onTap: () => context.go('/vendors'),
                  ),
                  _StatCard(
                    icon: Icons.directions_car_rounded,
                    label: 'ACTIVE RIDES',
                    value: stats.activeRides,
                    subtitle: stats.activeRides > 0 ? 'In progress now' : 'No active rides',
                    color: AdminColors.success,
                    onTap: () => context.go('/rides'),
                  ),
                  _StatCard(
                    icon: Icons.warning_rounded,
                    label: 'SOS ALERTS',
                    value: stats.activeSosAlerts,
                    subtitle: stats.activeSosAlerts > 0 ? 'CRITICAL' : 'All clear',
                    color: stats.activeSosAlerts > 0 ? AdminColors.danger : AdminColors.success,
                    onTap: () => context.go('/sos'),
                  ),
                  _StatCard(
                    icon: Icons.support_agent_rounded,
                    label: 'OPEN TICKETS',
                    value: stats.openSupportTickets,
                    subtitle: stats.openSupportTickets > 0 ? 'Need attention' : 'All resolved',
                    color: stats.openSupportTickets > 0 ? AdminColors.warning : AdminColors.success,
                    onTap: () => context.go('/tickets'),
                  ),
                ].map((card) => SizedBox(
                  width: (constraints.maxWidth - (crossCount - 1) * 16) / crossCount,
                  child: card,
                )).toList(),
              );
            }),
            const SizedBox(height: 32),
            // Live sections
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _LiveSosCard(sosAsync: sosAsync)),
                const SizedBox(width: 16),
                Expanded(child: _LiveRidesCard(ridesAsync: ridesAsync)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(
            color: AdminColors.success,
            size: 8,
            duration: const Duration(milliseconds: 1200),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AdminColors.success,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CriticalBanner extends StatelessWidget {
  const _CriticalBanner({required this.sosCount, required this.ticketCount, required this.onSosTap, required this.onTicketTap});
  final int sosCount;
  final int ticketCount;
  final VoidCallback onSosTap;
  final VoidCallback onTicketTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AdminColors.danger.withValues(alpha: 0.8), AdminColors.danger]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.priority_high_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attention Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('$sosCount active SOS alert(s) · $ticketCount open ticket(s)',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
              ],
            ),
          ),
          TextButton(onPressed: onSosTap, style: TextButton.styleFrom(foregroundColor: AdminColors.textPrimary), child: const Text('View SOS')),
          TextButton(onPressed: onTicketTap, style: TextButton.styleFrom(foregroundColor: AdminColors.textPrimary), child: const Text('View Tickets')),
        ],
      ),
    );
  }
}

/// Enterprise metric card: icon + uppercase label at top, prominent 28px bold
/// stat value in center, status indicator pill at bottom.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.subtitle, required this.color, this.onTap});
  final IconData icon;
  final String label;
  final int value;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: icon + uppercase label
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              // Center: prominent stat value
              CountUp(
                target: value.toDouble(),
                duration: const Duration(milliseconds: 800),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Bottom: status indicator
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveSosCard extends StatelessWidget {
  const _LiveSosCard({required this.sosAsync});
  final AsyncValue<List<AdminSosAlert>> sosAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_rounded, color: AdminColors.danger),
              const SizedBox(width: 8),
              const Text('Active SOS Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary)),
              const Spacer(),
              TextButton(onPressed: () => context.go('/sos'), child: const Text('View all')),
            ]),
            const Divider(),
            sosAsync.when(
              loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.accent))),
              error: (_, __) => const SizedBox(height: 60, child: Center(child: Text('Unable to load', style: TextStyle(color: AdminColors.textMuted)))),
              data: (alerts) => alerts.isEmpty
                  ? const SizedBox(height: 60, child: Center(child: Text('No active alerts', style: TextStyle(color: AdminColors.textMuted))))
                  : Column(
                      children: alerts.take(3).map((a) => ListTile(
                        dense: true,
                        textColor: AdminColors.textPrimary,
                        iconColor: AdminColors.danger,
                        leading: const Icon(Icons.warning, size: 20),
                        title: Text(a.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${a.userPhone} · ${_timeAgo(a.triggeredAt)}', style: const TextStyle(color: AdminColors.textMuted)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(a.status, style: const TextStyle(fontSize: 11, color: AdminColors.danger, fontWeight: FontWeight.w600)),
                        ),
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRidesCard extends StatelessWidget {
  const _LiveRidesCard({required this.ridesAsync});
  final AsyncValue<List<AdminActiveRide>> ridesAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.directions_car_rounded, color: AdminColors.accent),
              const SizedBox(width: 8),
              const Text('Active Rides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary)),
              const Spacer(),
              TextButton(onPressed: () => context.go('/rides'), child: const Text('View all')),
            ]),
            const Divider(),
            ridesAsync.when(
              loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.accent))),
              error: (_, __) => const SizedBox(height: 60, child: Center(child: Text('Unable to load', style: TextStyle(color: AdminColors.textMuted)))),
              data: (rides) => rides.isEmpty
                  ? const SizedBox(height: 60, child: Center(child: Text('No active rides', style: TextStyle(color: AdminColors.textMuted))))
                  : Column(
                      children: rides.take(3).map((r) => ListTile(
                        dense: true,
                        textColor: AdminColors.textPrimary,
                        iconColor: AdminColors.accent,
                        leading: Icon(_vehicleIcon(r.vehicleType), size: 20),
                        title: Text(r.riderName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(r.driverName != null ? 'Driver: ${r.driverName}' : 'Searching for driver...', style: const TextStyle(color: AdminColors.textMuted)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(r.status, style: const TextStyle(fontSize: 11, color: AdminColors.accent, fontWeight: FontWeight.w600)),
                        ),
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AdminColors.textMuted),
            const SizedBox(height: 16),
            const Text('Connection Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AdminColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AdminColors.textMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    ));
  }
}

IconData _vehicleIcon(String type) {
  switch (type.toLowerCase()) {
    case 'car': return Icons.directions_car_rounded;
    case 'auto': return Icons.local_taxi_rounded;
    default: return Icons.two_wheeler_rounded;
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
