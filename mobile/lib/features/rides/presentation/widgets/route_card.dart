import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';

/// Card showing pickup and dropoff addresses with a connecting line.
class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.my_location, color: AppTheme.info, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride['pickupAddress'] as String? ?? 'Pickup',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Container(width: 2, height: 24, color: Theme.of(context).dividerColor),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride['dropoffAddress'] as String? ?? 'Dropoff',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
