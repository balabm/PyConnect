import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

final receiptProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, rideId) async {
  final api = ref.watch(ridesApiProvider);
  return await api.getReceipt(rideId);
});

class RideReceiptScreen extends ConsumerWidget {
  const RideReceiptScreen({super.key, required this.rideId});
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(receiptProvider(rideId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              AppHaptics.light();
              // TODO: Share receipt via system share sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt sharing coming soon')),
              );
            },
          ),
        ],
      ),
      body: receiptAsync.when(
        loading: () => const ShimmerList(withImage: false, count: 4),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(receiptProvider(rideId)),
        ),
        data: (receipt) => _ReceiptBody(receipt: receipt, rideId: rideId),
      ),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({required this.receipt, required this.rideId});
  final Map<String, dynamic> receipt;
  final String rideId;

  @override
  Widget build(BuildContext context) {
    final status = receipt['status'] as String? ?? '';
    final vehicleType = receipt['vehicleType'] as String? ?? 'Bike';
    final paymentMethod = receipt['paymentMethod'] as String? ?? 'Cash';
    final baseFare = receipt['baseFare'] ?? 0;
    final distanceFare = receipt['distanceFare'] ?? 0;
    final timeFare = receipt['timeFare'] ?? 0;
    final surgeMultiplier = (receipt['surgeMultiplier'] as num?)?.toDouble() ?? 1.0;
    final surgeReason = receipt['surgeReason'] as String?;
    final fare = receipt['fare'] ?? 0;
    final platformBookingFee = receipt['platformBookingFee'] ?? 0;
    final cancellationFee = receipt['cancellationFee'] ?? 0;
    final totalAmount = receipt['totalAmount'] ?? 0;
    final distanceKm = receipt['distanceKm'] ?? 0;
    final actualDistanceKm = receipt['actualDistanceKm'];
    final estimatedDurationMin = receipt['estimatedDurationMin'] ?? 0;
    final actualDurationMin = receipt['actualDurationMin'];
    final requestedAt = receipt['requestedAt'] as String? ?? '';
    final completedAt = receipt['completedAt'] as String?;
    final pickupAddress = receipt['pickupAddress'] as String? ?? '';
    final dropoffAddress = receipt['dropoffAddress'] as String? ?? '';
    final driverName = receipt['driverName'] as String?;
    final ratingByRider = receipt['ratingByRider'];

    final isCompleted = status.toLowerCase() == 'completed';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header card
          FadeSlideIn(
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Text('\u20B9$totalAmount', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$vehicleType · $paymentMethod', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (driverName != null) ...[
                    const SizedBox(height: 8),
                    Text('Driver: $driverName', style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Route card
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trip Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _RouteRow(icon: Icons.my_location, color: AppTheme.info, text: pickupAddress),
                  Padding(padding: const EdgeInsets.only(left: 10), child: Container(width: 2, height: 20, color: Theme.of(context).dividerColor)),
                  _RouteRow(icon: Icons.location_on, color: AppTheme.danger, text: dropoffAddress),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _DetailRow(label: 'Distance', value: actualDistanceKm != null ? '$actualDistanceKm km' : '$distanceKm km'),
                  _DetailRow(label: 'Duration', value: actualDurationMin != null ? '$actualDurationMin min' : '$estimatedDurationMin min (est.)'),
                  _DetailRow(label: 'Requested', value: _formatDate(requestedAt)),
                  if (completedAt != null) _DetailRow(label: 'Completed', value: _formatDate(completedAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Fare breakdown card
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fare Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _FareRow(label: 'Base fare', value: '\u20B9$baseFare'),
                  _FareRow(label: 'Distance fare', value: '\u20B9$distanceFare'),
                  _FareRow(label: 'Time fare', value: '\u20B9$timeFare'),
                  if (surgeMultiplier > 1.0) ...[
                    _FareRow(
                      label: 'Surge (${surgeMultiplier}x)',
                      value: surgeReason ?? 'High demand',
                      highlight: true,
                      small: true,
                    ),
                  ],
                  const Divider(),
                  _FareRow(label: 'Ride fare (100% to driver)', value: '\u20B9$fare', bold: true),
                  _FareRow(label: 'Platform booking fee', value: '\u20B9$platformBookingFee'),
                  if (cancellationFee != null && cancellationFee > 0)
                    _FareRow(label: 'Cancellation fee', value: '\u20B9$cancellationFee'),
                  const Divider(),
                  _FareRow(label: 'Total', value: '\u20B9$totalAmount', bold: true, large: true),
                ],
              ),
            ),
          ),
          if (ratingByRider != null) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Your rating: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    ...List.generate(5, (i) => Icon(
                      i < (ratingByRider as int) ? Icons.star : Icons.star_border,
                      color: AppTheme.warning, size: 20,
                    )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (isCompleted && ratingByRider == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  AppHaptics.light();
                  context.push('/rides/$rideId/rate');
                },
                icon: const Icon(Icons.star),
                label: const Text('Rate this ride'),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'PY Connect · 0% commission · 100% to driver',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return AppTheme.success;
      case 'cancelled':
      case 'drivercancelled': return AppTheme.danger;
      case 'enroute': return AppTheme.info;
      default: return AppTheme.darkTextSecondary;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
        Text(value, style: const TextStyle(fontSize: 14)),
      ]),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({required this.label, required this.value, this.bold = false, this.large = false, this.highlight = false, this.small = false});
  final String label;
  final String value;
  final bool bold;
  final bool large;
  final bool highlight;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: small ? 12 : (large ? 18 : 14),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        )),
        Text(value, style: TextStyle(
          fontSize: small ? 12 : (large ? 18 : 14),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: highlight ? AppTheme.coral : null,
        )),
      ]),
    );
  }
}


