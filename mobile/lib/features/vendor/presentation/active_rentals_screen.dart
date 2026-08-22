import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Active rentals screen for ScooterRental vendors.
/// Shows current rentals with customer info, status management, and a
/// live countdown timer showing time remaining until return.
class ActiveRentalsScreen extends ConsumerStatefulWidget {
  const ActiveRentalsScreen({super.key});

  @override
  ConsumerState<ActiveRentalsScreen> createState() => _ActiveRentalsScreenState();
}

class _ActiveRentalsScreenState extends ConsumerState<ActiveRentalsScreen> {
  List<BookingSummary> _rentals = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData());
    // Update countdown displays every minute.
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final bookings = await ref.read(vendorDashboardApiProvider).getBookings();
      if (mounted) {
        setState(() {
          _rentals = bookings.where((b) =>
              b.status.toLowerCase() == 'confirmed' ||
              b.status.toLowerCase() == 'inprogress' ||
              b.status.toLowerCase() == 'active').toList();
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
      appBar: AppBar(
        title: const Text('Active Rentals', style: TextStyle(fontWeight: FontWeight.bold)),
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
              : _rentals.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppTheme.emerald,
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rentals.length,
                        itemBuilder: (_, i) => _RentalCard(booking: _rentals[i]),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pedal_bike, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No active rentals',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 18)),
          const SizedBox(height: 8),
          Text('Active scooter rentals will appear here',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 13)),
        ],
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
            Text('Could not load rentals',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(),
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

/// Countdown info derived from the rental's start time and duration.
class _CountdownInfo {
  _CountdownInfo(this.remaining, this.total, this.isOverdue, this.isWarning);

  final Duration remaining;
  final Duration total;
  final bool isOverdue;
  final bool isWarning;

  double get progress {
    if (total.inSeconds == 0) return 0;
    final elapsed = total - remaining;
    return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }
}

_CountdownInfo _computeCountdown(BookingSummary booking) {
  // startTime from scheduledFor; durationHours from booking or default 4h.
  DateTime? start;
  try {
    start = booking.scheduledFor.isEmpty ? null : DateTime.parse(booking.scheduledFor);
  } catch (_) {
    start = null;
  }
  final durationHours = booking.durationHours ?? 4.0;
  final total = Duration(minutes: (durationHours * 60).round());
  // If no start time available, fall back to "now" so a full-duration countdown shows.
  final startTime = start ?? DateTime.now();
  final returnTime = startTime.add(total);
  final now = DateTime.now();
  final rawRemaining = returnTime.difference(now);
  final isOverdue = rawRemaining.isNegative;
  final isWarning = !isOverdue && rawRemaining.inHours < 1;
  // remaining is clamped to zero for progress calc; overdue amount kept separately.
  return _CountdownInfo(
    isOverdue ? Duration.zero : rawRemaining,
    total,
    isOverdue,
    isWarning,
  );
}

String _formatRemaining(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
  return '${d.inMinutes}m';
}

class _RentalCard extends StatelessWidget {
  const _RentalCard({required this.booking});
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final countdown = _computeCountdown(booking);
    final color = countdown.isOverdue
        ? AppTheme.danger
        : countdown.isWarning
            ? AppTheme.warning
            : AppTheme.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pedal_bike, color: AppTheme.info, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.customerName,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(booking.serviceType,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                ),
              ),
              Text('\u20B9${booking.amount.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(booking.status,
                    style: const TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Countdown timer section
          _buildCountdown(countdown, color),
        ],
      ),
    );
  }

  Widget _buildCountdown(_CountdownInfo countdown, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                countdown.isOverdue ? Icons.warning_amber_rounded : Icons.timer,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                countdown.isOverdue
                    ? 'Overdue — return past due'
                    : 'Returns in: ${_formatRemaining(countdown.remaining)}',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (countdown.isOverdue)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 24),
              child: Text(
                'Please follow up with the customer',
                style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
              ),
            ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: countdown.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
