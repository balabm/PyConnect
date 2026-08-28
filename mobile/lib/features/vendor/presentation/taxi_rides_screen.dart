import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Rides screen for TaxiOperator vendors.
/// Lists active and completed rides for this operator.
class TaxiRidesScreen extends ConsumerStatefulWidget {
  const TaxiRidesScreen({super.key});

  @override
  ConsumerState<TaxiRidesScreen> createState() => _TaxiRidesScreenState();
}

class _TaxiRidesScreenState extends ConsumerState<TaxiRidesScreen> {
  List<BookingSummary> _rides = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData());
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
          _rides = bookings;
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
    final active = _rides.where((r) =>
        r.status.toLowerCase() == 'confirmed' ||
        r.status.toLowerCase() == 'inprogress').toList();
    final completed = _rides.where((r) =>
        r.status.toLowerCase() == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Rides', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
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
                      if (active.isNotEmpty) ...[
                        Text('Active Rides',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...active.map((r) => _RideCard(ride: r, isActive: true)),
                        const SizedBox(height: 24),
                      ],
                      Text('Completed',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (completed.isEmpty)
                        _buildEmpty()
                      else
                        ...completed.map((r) => _RideCard(ride: r, isActive: false)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.directions_car, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No rides yet',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14)),
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
            Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Could not load rides',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              onPressed: () { setState(() => _loading = true); _loadData(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, required this.isActive});
  final BookingSummary ride;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.warning : AppTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.directions_car, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.customerName,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(ride.serviceType,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\u20B9${ride.amount.toStringAsFixed(0)}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(ride.status,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  AppHaptics.light();
                  context.push('/assign-driver', extra: ride.bookingId);
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Assign Driver'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
