import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/haptic.dart';
import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/admin_providers.dart';

class VenueStatusPane extends ConsumerStatefulWidget {
  const VenueStatusPane({super.key});

  @override
  ConsumerState<VenueStatusPane> createState() => _VenueStatusPaneState();
}

class _VenueStatusPaneState extends ConsumerState<VenueStatusPane> {
  final _forceSoldOut = <String, bool>{};

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(adminVenueStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.storefront, size: 18),
              const SizedBox(width: 8),
              Text('Venue Status', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Expanded(
          child: venuesAsync.when(
            loading: () => const ShimmerList(withImage: false, count: 5),
            error: (_, _) => const ErrorState(message: 'Error loading venues'),
            data: (venues) => ListView.builder(
              itemCount: venues.length,
              itemBuilder: (context, i) {
                final venue = venues[i];
                final isForced = _forceSoldOut[venue.name] ?? false;
                final effectiveSoldOut = isForced || venue.isForceSoldOut;
                final fillPercent = effectiveSoldOut ? 1.0 : venue.fillPercent;

                return AppCard(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              venue.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Text(
                            effectiveSoldOut
                                ? 'SOLD OUT'
                                : '${venue.currentCapacity}/${venue.maxCapacity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: effectiveSoldOut ? AppTheme.coral : AppTheme.lagoon,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: fillPercent,
                        backgroundColor: Theme.of(context).dividerColor,
                        color: effectiveSoldOut
                            ? AppTheme.coral
                            : fillPercent > 0.8
                                ? AppTheme.gold
                                : AppTheme.lagoon,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Force Sold Out', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const Spacer(),
                          Switch(
                            value: isForced,
                            onChanged: (val) {
                              AppHaptics.light();
                              setState(() {
                                _forceSoldOut[venue.name] = val;
                              });
                            },
                            activeThumbColor: AppTheme.coral,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
