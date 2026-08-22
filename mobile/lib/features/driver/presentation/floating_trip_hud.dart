import 'package:flutter/material.dart';

import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';

/// A glassmorphic floating island HUD that overlays the map during
/// an active trip. Shows turn-by-turn direction, ETA, and distance
/// in a sleek, high-contrast format.
///
/// Position at the top of the map widget using a [Positioned] or
/// [SafeArea] wrapper.
class FloatingTripHud extends StatelessWidget {
  const FloatingTripHud({
    super.key,
    required this.maneuverIcon,
    required this.maneuverText,
    required this.etaMinutes,
    required this.distanceKm,
    this.destinationLabel,
    this.onTapNavigate,
  });

  /// Icon for the next maneuver (e.g., Icons.turn_right, Icons.straight).
  final IconData maneuverIcon;

  /// Turn-by-turn instruction text.
  final String maneuverText;

  /// Estimated time of arrival in minutes.
  final int etaMinutes;

  /// Remaining distance in kilometers.
  final double distanceKm;

  /// Optional destination label (e.g., "Drop-off: 123 Main St").
  final String? destinationLabel;

  /// Callback when the navigate button is tapped.
  final VoidCallback? onTapNavigate;

  @override
  Widget build(BuildContext context) {
    return AppGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: AppRadius.xl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Maneuver row
          Row(
            children: [
              // Maneuver icon with glow
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppTheme.emerald.withOpacity(0.25),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  maneuverIcon,
                  color: AppTheme.emerald,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              // Maneuver text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      maneuverText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoal,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (destinationLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        destinationLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Divider
          Container(
            height: 0.5,
            color: Theme.of(context).dividerColor.withOpacity(0.12),
          ),
          const SizedBox(height: 12),
          // ETA + distance row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ETA
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: AppTheme.slate,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$etaMinutes min',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              // Distance
              Row(
                children: [
                  Icon(
                    Icons.straighten_rounded,
                    size: 18,
                    color: AppTheme.slate,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate,
                    ),
                  ),
                ],
              ),
              // Navigate button
              if (onTapNavigate != null)
                GestureDetector(
                  onTap: onTapNavigate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.emeraldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Go',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
