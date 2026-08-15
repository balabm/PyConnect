import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Taxi fleet management for TaxiOperator vendors.
/// Shows registered taxis with driver assignments and status.
class TaxiFleetScreen extends ConsumerStatefulWidget {
  const TaxiFleetScreen({super.key});

  @override
  ConsumerState<TaxiFleetScreen> createState() => _TaxiFleetScreenState();
}

class _TaxiFleetScreenState extends ConsumerState<TaxiFleetScreen> {
  List<BookingSummary> _activeRides = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final bookings = await ref.read(vendorDashboardApiProvider).getBookings();
      if (mounted) {
        setState(() {
          _activeRides = bookings.where((b) =>
              b.status.toLowerCase() == 'confirmed' ||
              b.status.toLowerCase() == 'inprogress').toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Fleet', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { AppHaptics.light(); _loadData(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: AppTheme.emerald,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatRow(),
                      const SizedBox(height: 16),
                      const Text('Active Vehicles',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_activeRides.isEmpty)
                        _buildEmpty()
                      else
                        ..._activeRides.map((b) => _TaxiCard(booking: b)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatRow() {
    // _activeRides is already filtered to confirmed/inprogress (on duty)
    final onDuty = _activeRides.length;
    // Off-duty count would come from a separate API call; show 0 as placeholder
    return Row(
      children: [
        Expanded(child: _StatTile(
          icon: Icons.local_taxi, label: 'On Duty', value: onDuty, color: AppTheme.warning)),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(
          icon: Icons.local_parking, label: 'Off Duty', value: 0, color: Colors.white.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.local_taxi, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No active vehicles',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Could not load fleet',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () { setState(() => _loading = true); _loadData(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon; final String label; final int value; final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaxiCard extends StatelessWidget {
  const _TaxiCard({required this.booking});
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_taxi, color: AppTheme.warning, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.customerName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(booking.serviceType,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\u20B9${booking.amount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(booking.status,
                    style: const TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
