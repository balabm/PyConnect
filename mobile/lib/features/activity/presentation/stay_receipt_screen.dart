import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Fetches a single stay booking by ID from the user's booking list.
/// The stays API exposes `listMyBookings()` which returns all bookings; we
/// filter client-side because there is no single-booking endpoint.
final stayBookingProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final bookings = await ref.watch(staysApiProvider).listMyBookings();
  return bookings.firstWhere(
    (b) => (b['id'] as String?) == bookingId,
    orElse: () => <String, dynamic>{},
  );
});

/// Read-only receipt screen for a stay (homestay) booking.
class StayReceiptScreen extends ConsumerWidget {
  const StayReceiptScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(stayBookingProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Stay Receipt')),
      body: bookingAsync.when(
        loading: () => const ShimmerList(withImage: false, count: 4),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(stayBookingProvider(bookingId)),
        ),
        data: (booking) {
          if (booking == null || booking.isEmpty) {
            return const EmptyState(
              icon: Icons.bed_outlined,
              title: 'Booking Not Found',
              subtitle: 'This booking may have been cancelled or removed.',
            );
          }
          return _StayReceiptBody(booking: booking);
        },
      ),
    );
  }
}

class _StayReceiptBody extends StatelessWidget {
  const _StayReceiptBody({required this.booking});
  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final status = (booking['status'] as String?) ?? 'Unknown';
    final bookingRef = (booking['bookingReference'] ??
            booking['referenceId'] ??
            booking['id']) ??
        'N/A';
    final checkIn = booking['checkInDate'] as String? ?? '—';
    final checkOut = booking['checkOutDate'] as String? ?? '—';
    final guests = booking['guests'] ?? booking['guestCount'] ?? 1;
    final totalAmount = (booking['totalAmount'] as num?)?.toDouble();
    final passToken = booking['passToken'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header card with status + amount
          FadeSlideIn(
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  StatusBadge(
                    label: _friendlyStatus(status),
                    variant: _statusVariant(status),
                    icon: _statusIcon(status),
                  ),
                  const SizedBox(height: 16),
                  if (totalAmount != null) ...[
                    Text(
                      '\u20B9${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    'Homestay Booking',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // QR stay pass
          if (passToken != null && passToken.isNotEmpty)
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Stay Pass',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: passToken,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      passToken,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (passToken != null && passToken.isNotEmpty)
            const SizedBox(height: 16),
          // Booking details card
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Booking Details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Booking Reference',
                    value: bookingRef.toString(),
                  ),
                  _DetailRow(
                    icon: Icons.login,
                    label: 'Check-in',
                    value: _formatDate(checkIn),
                  ),
                  _DetailRow(
                    icon: Icons.logout,
                    label: 'Check-out',
                    value: _formatDate(checkOut),
                  ),
                  _DetailRow(
                    icon: Icons.people_outline,
                    label: 'Guests',
                    value: '$guests ${guests == 1 ? 'guest' : 'guests'}',
                  ),
                  if (totalAmount != null) ...[
                    const Divider(),
                    _DetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Total Paid',
                      value: '\u20B9${totalAmount.toStringAsFixed(0)}',
                      bold: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Need help button
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/help'),
                icon: const Icon(Icons.support_agent),
                label: const Text('Need Help?'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.emerald),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PY Connect · Homestay Booking',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static String _friendlyStatus(String status) {
    return switch (status.toLowerCase()) {
      'confirmed' => 'Confirmed',
      'checkedin' || 'checked_in' => 'Checked In',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'pending' => 'Pending',
      _ => status,
    };
  }

  static BadgeVariant _statusVariant(String status) {
    return switch (status.toLowerCase()) {
      'confirmed' => BadgeVariant.success,
      'checkedin' || 'checked_in' => BadgeVariant.info,
      'completed' => BadgeVariant.success,
      'cancelled' => BadgeVariant.danger,
      'pending' => BadgeVariant.warning,
      _ => BadgeVariant.neutral,
    };
  }

  static IconData _statusIcon(String status) {
    return switch (status.toLowerCase()) {
      'confirmed' => Icons.check_circle,
      'checkedin' || 'checked_in' => Icons.login,
      'completed' => Icons.task_alt,
      'cancelled' => Icons.cancel,
      'pending' => Icons.hourglass_top,
      _ => Icons.info_outline,
    };
  }

  static String _formatDate(String iso) {
    if (iso == '—') return iso;
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
