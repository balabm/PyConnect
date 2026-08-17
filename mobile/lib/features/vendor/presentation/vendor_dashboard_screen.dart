import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/modern_animations.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';
import 'widgets/active_orders_panel.dart';
import 'widgets/venue_stats_panel.dart';
import 'widgets/priority_ping_toggle.dart';

/// Dark slate vendor dashboard with animated stat cards, live orders,
/// and priority ping toggle.
class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key, this.venueId = '00000000-0000-0000-0000-000000000001'});

  final String venueId;

  @override
  ConsumerState<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen> {
  DashboardData? _dashboard;
  List<BookingSummary> _bookings = [];
  bool _priorityActive = false;
  bool _showMoreStats = false;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final dashboard = await api.getDashboard();
      final bookings = await api.getBookings();
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _bookings = bookings;
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

  void _onPriorityActivated(ActivatePriorityResult result) {
    if (result.success) {
      setState(() => _priorityActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? _buildShimmerLoading()
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildShimmerLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.emerald),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard...',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Could not load dashboard',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () {
                AppHaptics.light();
                setState(() => _loading = true);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: AppTheme.emerald,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat cards row
            if (_dashboard != null)
              _buildStatCards(_dashboard!)
            else
              const SizedBox(height: 120),
            const SizedBox(height: 16),
            // Active orders
            ActiveOrdersPanel(
              bookings: _bookings,
            ),
            const SizedBox(height: 16),
            // Detailed stats
            if (_dashboard != null)
              VenueStatsPanel(dashboard: _dashboard!)
            else
              _buildDarkCard(child: Text('Stats unavailable',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))),
            const SizedBox(height: 16),
            // Priority ping
            PriorityPingToggle(
              venueId: widget.venueId,
              api: ref.read(vendorDashboardApiProvider),
              isActive: _priorityActive,
              onActivated: _onPriorityActivated,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(DashboardData d) {
    final crossAxisCount = MediaQuery.of(context).size.width < 360 ? 2 : 3;
    final bookings = _StatCard(
      icon: Icons.receipt_long,
      label: 'Bookings',
      value: d.totalBookingsToday,
      color: AppTheme.emerald,
    );
    final revenue = _StatCard(
      icon: Icons.payments,
      label: 'Revenue',
      value: d.revenueToday.toInt(),
      prefix: '\u20B9',
      color: AppTheme.emerald,
    );
    final pending = _StatCard(
      icon: Icons.pending,
      label: 'Pending',
      value: d.pendingBookings,
      color: AppTheme.warning,
    );
    final done = _StatCard(
      icon: Icons.check_circle,
      label: 'Done',
      value: d.completedBookings,
      color: AppTheme.success,
    );
    final confirmed = _StatCard(
      icon: Icons.event_available,
      label: 'Confirmed',
      value: d.confirmedBookings,
      color: AppTheme.info,
    );

    final visible = [bookings, revenue];
    if (d.pendingBookings > 0) visible.add(pending);
    if (d.completedBookings > 0) visible.add(done);
    if (d.confirmedBookings > 0) visible.add(confirmed);

    final hidden = <_StatCard>[];
    if (d.pendingBookings == 0) hidden.add(pending);
    if (d.completedBookings == 0) hidden.add(done);
    if (d.confirmedBookings == 0) hidden.add(confirmed);

    return FadeSlideIn(
      duration: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: visible,
          ),
          if (hidden.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showMoreStats = !_showMoreStats),
              icon: Icon(
                _showMoreStats ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: AppTheme.emerald,
              ),
              label: Text(
                _showMoreStats ? 'Show less' : 'Show more stats',
                style: const TextStyle(color: AppTheme.emerald),
              ),
            ),
            if (_showMoreStats)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: hidden,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDarkCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Compact stat card with icon, animated count, and colored accent.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountUp(
                  target: value.toDouble(),
                  prefix: prefix,
                  duration: const Duration(milliseconds: 800),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
