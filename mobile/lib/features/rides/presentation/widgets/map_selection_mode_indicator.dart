import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Modern floating pill overlay on the map indicating pickup/dropoff selection mode.
class MapSelectionModeIndicator extends StatelessWidget {
  const MapSelectionModeIndicator({
    super.key,
    required this.isSelectingPickup,
    required this.canToggle,
    required this.onToggle,
  });

  final bool isSelectingPickup;
  final bool canToggle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final activeColor = isSelectingPickup ? AppTheme.emerald : AppTheme.danger;
    return Material(
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isSelectingPickup
                  ? 'Tap map to set pickup'
                  : 'Tap map to set dropoff',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canToggle) ...[
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 16,
                color: Theme.of(context).dividerColor,
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  foregroundColor: activeColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isSelectingPickup ? 'Dropoff' : 'Pickup',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
