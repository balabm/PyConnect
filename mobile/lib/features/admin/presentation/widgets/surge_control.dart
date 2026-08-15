import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/haptic.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/admin_providers.dart';

class SurgeControlButton extends ConsumerWidget {
  const SurgeControlButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surgeMode = ref.watch(surgeModeProvider);

    final (label, color) = switch (surgeMode) {
      SurgeMode.normal => ('Normal', AdminColors.accent),
      SurgeMode.monsoon => ('Monsoon', AdminColors.info),
      SurgeMode.festivalSurge => ('Festival', AdminColors.warning),
    };

    return PopupMenuButton<SurgeMode>(
      tooltip: 'Surge Control',
      onSelected: (mode) {
        AppHaptics.selection();
        ref.read(surgeModeProvider.notifier).setMode(mode);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: SurgeMode.normal, child: Text('Normal Operations')),
        PopupMenuItem(value: SurgeMode.monsoon, child: Text('Monsoon Mode (+20%)')),
        PopupMenuItem(value: SurgeMode.festivalSurge, child: Text('Festival Surge (+20%)')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
