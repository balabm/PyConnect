import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

class VendorBookingsScreen extends ConsumerStatefulWidget {
  const VendorBookingsScreen({super.key});

  @override
  ConsumerState<VendorBookingsScreen> createState() => _VendorBookingsScreenState();
}

class _VendorBookingsScreenState extends ConsumerState<VendorBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(vendorBookingsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Bookings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: () {
              AppHaptics.light();
              ref.read(vendorBookingsProvider.notifier).load();
            },
            icon: Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.emerald,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: AppTheme.emerald,
          tabs: const [
            Tab(text: 'All Bookings'),
            Tab(text: 'Cover Charges'),
          ],
        ),
      ),
      body: bookingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.emerald),
        ),
        error: (e, _) => _buildError(context, ref, e.toString()),
        data: (bookings) {
          final coverCharges = bookings
              .where((b) => b.serviceType.toLowerCase() == 'nightlife' ||
                  b.serviceType.toLowerCase() == 'cover charge' ||
                  b.serviceType.toLowerCase() == 'covercharge')
              .toList();
          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsList(context, ref, bookings, isCoverChargeView: false),
              _buildCoverChargesList(context, ref, coverCharges),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(BuildContext context, WidgetRef ref,
      List<BookingSummary> bookings, {required bool isCoverChargeView}) {
    if (bookings.isEmpty) {
      return _buildEmpty(context, 'No bookings today',
          'Bookings will appear here as customers reserve');
    }
    return RefreshIndicator(
      color: AppTheme.emerald,
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
  }

  Widget _buildCoverChargesList(
      BuildContext context, WidgetRef ref, List<BookingSummary> coverCharges) {
    if (coverCharges.isEmpty) {
      return _buildEmpty(context, 'No cover charge bookings',
          'Pub/club cover charge reservations will appear here');
    }
    return RefreshIndicator(
      color: AppTheme.emerald,
      onRefresh: () => ref.read(vendorBookingsProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coverCharges.length,
        itemBuilder: (_, i) => _CoverChargeCard(
          booking: coverCharges[i],
          onAccept: () {
            AppHaptics.success();
            ref.read(vendorBookingsProvider.notifier).updateStatus(
                  coverCharges[i].bookingId,
                  coverCharges[i].serviceType,
                  'Confirmed',
                );
          },
          onReject: () {
            AppHaptics.heavy();
            ref.read(vendorBookingsProvider.notifier).updateStatus(
                  coverCharges[i].bookingId,
                  coverCharges[i].serviceType,
                  'Cancelled',
                );
          },
        ),
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
            Icon(Icons.cloud_off, size: 48, color: AppTheme.emerald),
            const SizedBox(height: 12),
            Text(
              'Could not load bookings',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(vendorBookingsProvider.notifier).load(),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Cover charge booking card with explicit Accept / Reject actions for
/// pending bookings. Shows customer name, guest count, date/time, status,
/// and total amount.
class _CoverChargeCard extends StatelessWidget {
  const _CoverChargeCard({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  final BookingSummary booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  bool get _isPending =>
      booking.status.toLowerCase() == 'pending' ||
      booking.status.toLowerCase() == 'requested';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.nightlife, color: AppTheme.emerald, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.customerName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.group, size: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${booking.guestCount ?? 1} guest${(booking.guestCount ?? 1) == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
              Icon(Icons.schedule, size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                _formatTime(booking.scheduledFor),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '\u20B9${booking.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: Icon(Icons.check, size: 16),
                    label: Text('Accept'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReject,
                    icon: Icon(Icons.close, size: 16),
                    label: Text('Reject'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
      case 'Requested':
        return AppTheme.gold;
      case 'Confirmed':
        return AppTheme.sky;
      case 'CheckedIn':
        return AppTheme.emerald;
      case 'Completed':
        return AppTheme.success;
      case 'Cancelled':
        return AppTheme.danger;
      default:
        return Colors.grey;
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor(booking.status, context).withValues(alpha: 0.3),
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
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      booking.customerName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                _formatTime(booking.scheduledFor),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
          ..._buildActionButtons(context),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    final next = _nextStatus(booking.serviceType, booking.status);
    if (next == null) return [];

    return [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => onAdvance(next),
              icon: Icon(Icons.arrow_forward, size: 16),
              label: Text(_statusLabel(next)),
              style: FilledButton.styleFrom(
                backgroundColor: _statusColor(next, context),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_canCancel(booking.status))
            IconButton(
              onPressed: () => onAdvance('Cancelled'),
              icon: Icon(Icons.cancel_outlined, color: AppTheme.danger),
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

  Color _statusColor(String status, BuildContext context) {
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
        return AppTheme.emerald;
      case 'Completed':
      case 'Collected':
      case 'Returned':
        return AppTheme.success;
      case 'Cancelled':
        return AppTheme.danger;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
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
      'Nightlife' => (Icons.nightlife, AppTheme.emerald),
      'Transit' => (Icons.airport_shuttle, AppTheme.sky),
      'Luggage' => (Icons.luggage, AppTheme.gold),
      'Rental' => (Icons.pedal_bike, AppTheme.emerald),
      _ => (Icons.event, Theme.of(context).colorScheme.onSurfaceVariant),
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
      'CheckedIn' || 'EnRoute' || 'Active' || 'Dropped' => AppTheme.emerald,
      'Completed' || 'Collected' || 'Returned' => AppTheme.success,
      'Cancelled' => AppTheme.danger,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: (isPaid ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Unpaid',
        style: TextStyle(
          color: isPaid ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
