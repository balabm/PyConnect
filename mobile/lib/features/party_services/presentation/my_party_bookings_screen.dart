import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/party_services_api.dart';

/// Consumer screen showing the user's party service bookings.
class MyPartyBookingsScreen extends ConsumerStatefulWidget {
  const MyPartyBookingsScreen({super.key});

  @override
  ConsumerState<MyPartyBookingsScreen> createState() =>
      _MyPartyBookingsScreenState();
}

class _MyPartyBookingsScreenState extends ConsumerState<MyPartyBookingsScreen> {
  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(_myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Party Bookings')),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text('Could not load bookings'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(_myBookingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration, size: 48, color: AppTheme.slate.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('No party bookings yet', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Browse services to book DJs, catering, and more',
                      style: TextStyle(color: AppTheme.slate.withValues(alpha: 0.6))),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) => _BookingCard(booking: bookings[index]),
          );
        },
      ),
    );
  }
}

final _myBookingsProvider = FutureProvider<List<PartyServiceBookingModel>>((ref) async {
  final api = ref.watch(partyServicesApiProvider);
  return await api.getMyBookings();
});

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final PartyServiceBookingModel booking;

  Color get _statusColor {
    switch (booking.status.toLowerCase()) {
      case 'confirmed': return AppTheme.emerald;
      case 'completed': return AppTheme.emerald;
      case 'cancelled': return AppTheme.danger;
      case 'pending': return AppTheme.gold;
      default: return AppTheme.slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.serviceTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    booking.status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category, size: 14, color: AppTheme.slate.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(booking.category, style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.6))),
                const SizedBox(width: 16),
                Icon(Icons.event, size: 14, color: AppTheme.slate.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(booking.eventDate.split('T').first,
                    style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.6))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qty: ${booking.quantity}',
                  style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.6)),
                ),
                Text(
                  '\u20B9${booking.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.payment, size: 14, color: AppTheme.slate.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text('Payment: ${booking.paymentStatus}',
                    style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
