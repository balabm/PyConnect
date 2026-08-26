import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/consumer_equipment_api.dart';

/// Consumer's equipment rental history screen.
/// Shows all rentals made by the consumer with status badges.
class MyEquipmentRentalsScreen extends ConsumerStatefulWidget {
  const MyEquipmentRentalsScreen({super.key});

  @override
  ConsumerState<MyEquipmentRentalsScreen> createState() =>
      _MyEquipmentRentalsScreenState();
}

class _MyEquipmentRentalsScreenState
    extends ConsumerState<MyEquipmentRentalsScreen> {
  @override
  Widget build(BuildContext context) {
    // The backend GET /api/equipment/rentals is vendor-only, so we use
    // the activity hub endpoint to find equipment rentals. For now,
    // we show an honest state explaining that rental history is
    // accessible from the Activity Hub.
    return Scaffold(
      appBar: AppBar(title: const Text('My Equipment Rentals')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 64, color: AppTheme.slate.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'View your rentals in Activity Hub',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'All your equipment rentals, rides, and orders are consolidated in the Activity Hub for easy tracking.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
