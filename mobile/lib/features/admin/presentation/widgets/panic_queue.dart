import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/haptic.dart';
import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/admin_providers.dart';

class PanicQueue extends ConsumerStatefulWidget {
  const PanicQueue({super.key});

  @override
  ConsumerState<PanicQueue> createState() => _PanicQueueState();
}

class _PanicQueueState extends ConsumerState<PanicQueue>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  Timer? _alarmTimer;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _startAlarm();
  }

  void _startAlarm() {
    _flashController.repeat(reverse: true);
    _alarmTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _stopAlarm() {
    _flashController.stop();
    _alarmTimer?.cancel();
    _alarmTimer = null;
  }

  @override
  void dispose() {
    _stopAlarm();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final criticalTickets = ref.watch(criticalTicketsProvider);
    final hasCritical = criticalTickets.isNotEmpty;

    if (!hasCritical) {
      _stopAlarm();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return AnimatedBuilder(
          animation: _flashController,
          builder: (context, child) {
            final flashColor = hasCritical
                ? Color.lerp(AppTheme.coral.withValues(alpha: 0.05), AppTheme.coral.withValues(alpha: 0.1), _flashController.value)!
                : (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface);

            return Container(
              color: flashColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasCritical
                        ? Color.lerp(AppTheme.coral, AdminColors.surface, _flashController.value)
                        : AppTheme.coral.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasCritical ? Icons.warning_rounded : Icons.check_circle,
                          color: hasCritical ? AdminColors.textPrimary : AppTheme.emerald,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasCritical
                                ? 'CRITICAL ALERTS — ${criticalTickets.length} Unacknowledged'
                                : 'Panic Queue — No Active Alerts',
                            style: TextStyle(
                              color: hasCritical ? AdminColors.textPrimary : AdminColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: hasCritical ? AdminColors.textPrimary : AdminColors.textMuted,
                          onPressed: () {
                            AppHaptics.light();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: hasCritical
                        ? ListView.builder(
                            controller: scrollController,
                            itemCount: criticalTickets.length,
                            itemBuilder: (context, i) {
                              final ticket = criticalTickets[i];
                              return AppCard(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  leading: const Icon(Icons.sos, color: AppTheme.coral, size: 32),
                                  title: Text(ticket.userName, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ticket.issueCategory ?? 'Critical Issue', style: const TextStyle(color: AdminColors.textPrimary)),
                                      if (ticket.latitude != null)
                                        Text(
                                          'GPS: ${ticket.latitude!.toStringAsFixed(4)}, ${ticket.longitude!.toStringAsFixed(4)}',
                                          style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                                        ),
                                      Text('Source: ${ticket.source}', style: const TextStyle(fontSize: 11, color: AdminColors.textMuted)),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        ticket.createdAt.toIso8601String().substring(11, 16),
                                        style: const TextStyle(fontSize: 12, color: AdminColors.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          AppHaptics.medium();
                                          ref.read(criticalTicketsProvider.notifier).acknowledge(ticket.id);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.emerald,
                                          foregroundColor: AdminColors.textPrimary,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                        child: const Text('Acknowledge'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const EmptyState(
                            icon: Icons.check_circle,
                            title: 'No active critical tickets',
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
