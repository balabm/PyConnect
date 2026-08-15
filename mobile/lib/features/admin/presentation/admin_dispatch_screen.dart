import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import 'widgets/heatmap_pane.dart';
import 'widgets/orders_pane.dart';
import 'widgets/venue_status_pane.dart';
import 'widgets/surge_control.dart';
import 'widgets/panic_queue.dart';

class AdminDispatchScreen extends ConsumerWidget {
  const AdminDispatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCritical = ref.watch(hasUnacknowledgedCriticalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('God Mode — Dispatch Dashboard'),
        actions: [
          const SurgeControlButton(),
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  hasCritical ? Icons.warning_rounded : Icons.warning_amber_rounded,
                  color: hasCritical ? AppTheme.coral : null,
                ),
                tooltip: 'Panic Queue',
                onPressed: () {
                  AppHaptics.medium();
                  _showPanicQueue(context, ref);
                },
              ),
              if (hasCritical)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.coral,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: const HeatmapPane(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: const OrdersPane(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 400,
                    child: const VenueStatusPane(),
                  ),
                ],
              ),
            );
          }
          return Row(
            children: [
              Expanded(flex: 4, child: const HeatmapPane()),
              const VerticalDivider(width: 1),
              Expanded(flex: 3, child: const OrdersPane()),
              const VerticalDivider(width: 1),
              Expanded(flex: 3, child: const VenueStatusPane()),
            ],
          );
        },
      ),
    );
  }

  void _showPanicQueue(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PanicQueue(),
    );
  }
}
