import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';

/// Driver information card with avatar, name, rating, plate, and ETA.
class DriverInfoCard extends StatelessWidget {
  const DriverInfoCard({
    super.key,
    required this.driverInfo,
    required this.vehicleType,
    required this.paymentMethod,
    this.etaToPickup,
  });

  final Map<String, dynamic>? driverInfo;
  final String vehicleType;
  final String paymentMethod;
  final int? etaToPickup;

  @override
  Widget build(BuildContext context) {
    final name = driverInfo?['driverName'] as String? ?? 'Driver assigned';
    final rating = (driverInfo?['rating'] as num?)?.toDouble();
    final plate = driverInfo?['vehiclePlate'] as String?;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              _vehicleIcon(vehicleType),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (rating != null)
                  RatingStars(rating: rating, size: 14),
                if (plate != null)
                  Text(
                    plate,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (etaToPickup != null)
            Column(
              children: [
                Text(
                  '$etaToPickup',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
                Text('min', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }

  IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.local_taxi;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.directions;
    }
  }
}
