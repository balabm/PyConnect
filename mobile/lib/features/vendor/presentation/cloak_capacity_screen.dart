import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Capacity management for LuggageCloak vendors.
/// Shows current cloak occupancy with a visual capacity bar and stored bags list.
class CloakCapacityScreen extends ConsumerStatefulWidget {
  const CloakCapacityScreen({super.key});

  @override
  ConsumerState<CloakCapacityScreen> createState() => _CloakCapacityScreenState();
}

class _CloakCapacityScreenState extends ConsumerState<CloakCapacityScreen> {
  List<BookingSummary> _stored = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  static const int _maxCapacity = 50;

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
          _stored = bookings.where((b) =>
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

  Color get _capacityColor {
    final ratio = _stored.length / _maxCapacity;
    if (ratio > 0.85) return AppTheme.danger;
    if (ratio > 0.6) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { AppHaptics.light(); _loadData(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.coral))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: AppTheme.coral,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCapacityBar(),
                      const SizedBox(height: 24),
                      const Text('Stored Bags',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_stored.isEmpty)
                        _buildEmpty()
                      else
                        ..._stored.map((b) => _BagCard(booking: b)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCapacityBar() {
    final color = _capacityColor;
    final pct = (_stored.length / _maxCapacity * 100).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Occupancy',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${_stored.length} / $_maxCapacity',
                  style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _stored.length / _maxCapacity,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text('${pct.toStringAsFixed(0)}% full',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.luggage, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No bags stored',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
            const SizedBox(height: 4),
            Text('Check in bags via the Scanner tab',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12)),
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
            Text('Could not load capacity',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
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

class _BagCard extends StatelessWidget {
  const _BagCard({required this.booking});
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.luggage, color: AppTheme.success, size: 24),
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
          Text('\u20B9${booking.amount.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
