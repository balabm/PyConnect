import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_api.dart';
import '../data/vendor_dashboard_api.dart';

/// Live crowd dashboard for pub/club owners.
///
/// Shows real data from the backend:
/// - Live occupancy from venue capacity (GET /api/vendor/venues)
/// - Checked-in guests from live tables (GET /api/vendor/live-tables)
/// - Cover charge collected from live tables
/// - Revenue today from dashboard (GET /api/vendor/dashboard)
/// - Bookings today from dashboard
///
/// No mock data. All numbers come from real API calls.
class CrowdDashboardScreen extends ConsumerStatefulWidget {
  const CrowdDashboardScreen({super.key});

  @override
  ConsumerState<CrowdDashboardScreen> createState() => _CrowdDashboardScreenState();
}

class _CrowdDashboardScreenState extends ConsumerState<CrowdDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<LiveTableEntry> _tables = [];
  DashboardData? _dashboard;
  List<VendorVenueSummary> _venues = [];
  bool _loading = true;
  String? _error;

  Future<void> _loadData() async {
    try {
      final vendorApi = ref.read(vendorApiProvider);
      final dashboardApi = ref.read(vendorDashboardApiProvider);
      final results = await Future.wait([
        vendorApi.getLiveTables(),
        dashboardApi.getDashboard(),
        dashboardApi.getVenues(),
      ]);
      if (mounted) {
        setState(() {
          _tables = results[0] as List<LiveTableEntry>;
          _dashboard = results[1] as DashboardData;
          _venues = results[2] as List<VendorVenueSummary>;
          _loading = false;
          _error = null;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crowd Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { AppHaptics.light(); _loadData(); },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 16),
          Center(child: Text('Failed to load dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)), textAlign: TextAlign.center),
          )),
          const SizedBox(height: 24),
          Center(child: FilledButton(onPressed: _loadData, child: const Text('Retry'))),
        ],
      );
    }

    final checkedInCount = _tables.length;
    final totalGuests = _tables.fold<int>(0, (sum, t) => sum + t.guestCount);
    final coverCollected = _tables.fold<double>(0.0, (sum, t) => sum + t.coverChargeAmount);
    final revenueToday = _dashboard?.revenueToday ?? 0;
    final bookingsToday = _dashboard?.totalBookingsToday ?? 0;
    final maxCapacity = _venues.isNotEmpty ? _venues.first.maxCapacity : 0;
    final occupancyPct = maxCapacity > 0 ? ((totalGuests / maxCapacity) * 100).round().clamp(0, 100) : 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Occupancy hero
        _OccupancyCard(
          current: totalGuests,
          max: maxCapacity,
          pct: occupancyPct,
        ),
        const SizedBox(height: 16),

        // Quick stats
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.groups,
              label: 'Checked In',
              value: '$checkedInCount',
              color: AppTheme.info,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.payments,
              label: 'Cover Collected',
              value: '\u20B9${_formatAmount(coverCollected)}',
              color: AppTheme.emerald,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.trending_up,
              label: 'Revenue Today',
              value: '\u20B9${_formatAmount(revenueToday)}',
              color: AppTheme.gold,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.event_available,
              label: 'Bookings Today',
              value: '$bookingsToday',
              color: AppTheme.coral,
            )),
          ],
        ),
        const SizedBox(height: 24),

        // Live tables list
        if (_tables.isNotEmpty) ...[
          Text('Live Tables', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._tables.map((t) => _LiveTableRow(table: t)),
        ] else ...[
          _EmptyState(
            icon: Icons.table_restaurant,
            title: 'No checked-in guests',
            subtitle: 'Live tables will appear here as guests check in',
          ),
        ],
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({required this.current, required this.max, required this.pct});
  final int current;
  final int max;
  final int pct;

  Color get _color {
    if (pct > 85) return AppTheme.danger;
    if (pct > 60) return AppTheme.warning;
    return AppTheme.emerald;
  }

  String get _status {
    if (pct > 85) return 'Near Capacity';
    if (pct > 60) return 'Busy';
    if (pct > 30) return 'Moderate';
    return 'Quiet';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withValues(alpha: 0.15), _color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$pct%', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: _color)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(_status, style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$current / $max guests', style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: max > 0 ? (current / max).clamp(0, 1) : 0,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _LiveTableRow extends StatelessWidget {
  const _LiveTableRow({required this.table});
  final LiveTableEntry table;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.table_restaurant, color: AppTheme.emerald, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(table.guestName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${table.guestCount} guests \u2022 ${table.serviceType}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\u20B9${table.coverChargeAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.emerald)),
                Text('\u20B9${table.creditAvailable.toStringAsFixed(0)} credit',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
