import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Fare breakdown card with surge, platform fee, total, and trip stats.
class FareCard extends StatelessWidget {
  const FareCard({
    super.key,
    required this.fare,
    required this.platformBookingFee,
    required this.totalAmount,
    required this.distanceKm,
    required this.estimatedDurationMin,
    required this.surgeMultiplier,
    required this.surgeReason,
  });

  final dynamic fare;
  final dynamic platformBookingFee;
  final dynamic totalAmount;
  final dynamic distanceKm;
  final dynamic estimatedDurationMin;
  final double surgeMultiplier;
  final String? surgeReason;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          FareRow(label: 'Fare (100% to driver)', value: '\u20B9$fare'),
          if (surgeMultiplier > 1.0) ...[
            FareRow(
              label: 'Surge (${surgeMultiplier}x)',
              value: surgeReason ?? 'High demand',
              small: true,
            ),
          ],
          FareRow(
            label: 'Platform booking fee',
            value: '\u20B9$platformBookingFee',
          ),
          const Divider(),
          FareRow(label: 'Total', value: '\u20B9$totalAmount', bold: true),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Distance: $distanceKm km',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              Text(
                'ETA: $estimatedDurationMin min',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
