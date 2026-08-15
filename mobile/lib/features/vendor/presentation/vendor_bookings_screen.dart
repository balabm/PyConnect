import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

class VendorBookingsScreen extends ConsumerWidget {
  const VendorBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(vendorBookingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Bookings'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.darkTextPrimary,
        actions: [
          IconButton(
            onPressed: () {
              AppHaptics.light();
              ref.read(vendorBookingsProvider.notifier).load();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: bookingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.coral),
        ),
        error: (e, _) => _buildError(context, ref, e.toString()),
        data: (bookings) {
          if (bookings.isEmpty) {
            return _buildEmpty();
          }
          return RefreshIndicator(
            color: AppTheme.coral,
            onRefresh: () => ref.read(vendorBookingsProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (_, i) => _BookingCard(
                booking: bookings[i],
                onAdvance: (newStatus) {
                  AppHaptics.medium();
                  ref.read(vendorBookingsProvider.notifier).updateStatus(
                        bookings[i].bookingId,
                        bookings[i].serviceType,
                        newStatus,
                      );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.coral),
            const SizedBox(height: 12),
            Text(
              'Could not load bookings',
              style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(vendorBookingsProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 48, color: AppTheme.darkTextSecondary),
          const SizedBox(height: 12),
          Text(
            'No bookings today',
            style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Bookings will appear here as customers reserve',
            style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onAdvance});

  final BookingSummary booking;
  final void Function(String newStatus) onAdvance;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor(booking.status).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ServiceIcon(booking.serviceType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceType,
                      style: TextStyle(
                        color: AppTheme.darkTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      booking.customerName,
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(booking.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: AppTheme.darkTextSecondary),
              const SizedBox(width: 4),
              Text(
                _formatTime(booking.scheduledFor),
                style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '₹${booking.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _PaymentChip(booking.paymentStatus),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildActionButtons(),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final next = _nextStatus(booking.serviceType, booking.status);
    if (next == null) return [];

    return [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => onAdvance(next),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(_statusLabel(next)),
              style: FilledButton.styleFrom(
                backgroundColor: _statusColor(next),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_canCancel(booking.status))
            IconButton(
              onPressed: () => onAdvance('Cancelled'),
              icon: const Icon(Icons.cancel_outlined, color: AppTheme.danger),
              tooltip: 'Cancel',
            ),
        ],
      ),
    ];
  }

  String? _nextStatus(String serviceType, String currentStatus) {
    switch (serviceType) {
      case 'Nightlife':
        switch (currentStatus) {
          case 'Pending': return 'Confirmed';
          case 'Confirmed': return 'CheckedIn';
          case 'CheckedIn': return 'Completed';
          default: return null;
        }
      case 'Transit':
        switch (currentStatus) {
          case 'Requested': return 'EnRoute';
          case 'EnRoute': return 'Completed';
          case 'Assigned': return 'EnRoute';
          default: return null;
        }
      case 'Luggage':
        switch (currentStatus) {
          case 'Reserved': return 'Dropped';
          case 'Dropped': return 'Collected';
          default: return null;
        }
      case 'Rental':
        switch (currentStatus) {
          case 'Reserved': return 'Active';
          case 'Active': return 'Returned';
          default: return null;
        }
      default:
        return null;
    }
  }

  bool _canCancel(String status) {
    return status != 'Completed' &&
        status != 'Cancelled' &&
        status != 'Collected' &&
        status != 'Returned';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Confirmed': return 'Confirm';
      case 'CheckedIn': return 'Check In';
      case 'Completed': return 'Complete';
      case 'EnRoute': return 'Start Trip';
      case 'Dropped': return 'Mark Dropped';
      case 'Collected': return 'Mark Collected';
      case 'Active': return 'Start Rental';
      case 'Returned': return 'Mark Returned';
      case 'Cancelled': return 'Cancel';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
      case 'Requested':
      case 'Reserved':
        return AppTheme.gold;
      case 'Confirmed':
      case 'Assigned':
        return AppTheme.sky;
      case 'CheckedIn':
      case 'EnRoute':
      case 'Active':
      case 'Dropped':
        return AppTheme.lagoon;
      case 'Completed':
      case 'Collected':
      case 'Returned':
        return AppTheme.success;
      case 'Cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.darkTextSecondary;
    }
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon(this.serviceType);
  final String serviceType;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (serviceType) {
      'Nightlife' => (Icons.nightlife, AppTheme.coral),
      'Transit' => (Icons.airport_shuttle, AppTheme.sky),
      'Luggage' => (Icons.luggage, AppTheme.gold),
      'Rental' => (Icons.pedal_bike, AppTheme.lagoon),
      _ => (Icons.event, AppTheme.darkTextSecondary),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Pending' || 'Requested' || 'Reserved' => AppTheme.gold,
      'Confirmed' || 'Assigned' => AppTheme.sky,
      'CheckedIn' || 'EnRoute' || 'Active' || 'Dropped' => AppTheme.lagoon,
      'Completed' || 'Collected' || 'Returned' => AppTheme.success,
      'Cancelled' => AppTheme.danger,
      _ => AppTheme.darkTextSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip(this.paymentStatus);
  final String paymentStatus;

  @override
  Widget build(BuildContext context) {
    final isPaid = paymentStatus == 'Captured' || paymentStatus == 'Paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isPaid ? AppTheme.lagoon : AppTheme.darkTextSecondary)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Unpaid',
        style: TextStyle(
          color: isPaid ? AppTheme.lagoon : AppTheme.darkTextSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
