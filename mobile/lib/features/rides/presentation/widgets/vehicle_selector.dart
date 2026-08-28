import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Modern horizontal vehicle-type selector with fare estimate + ETA.
class VehicleSelector extends StatelessWidget {
  const VehicleSelector({
    super.key,
    required this.vehicles,
    required this.selectedIndex,
    required this.fares,
    required this.onSelected,
    this.etas,
    this.descriptions,
  });

  /// List of (name, icon, perKm, base, minFare, etaMin, capacity, hasAC) tuples.
  final List<(String, IconData, double, double, double, int, int, bool)> vehicles;
  final int selectedIndex;
  final List<double> fares;
  final List<int>? etas;
  final ValueChanged<int> onSelected;

  /// Optional short description for each vehicle (e.g. "Quick & affordable").
  final List<String>? descriptions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vehicles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (name, icon, _, _, _, eta, capacity, hasAC) = vehicles[i];
          final fare = fares[i];
          final etaVal = etas?[i] ?? eta;
          final isSelected = selectedIndex == i;

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 200 + i * 80),
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: 110,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.emerald.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.emerald
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        icon,
                        size: 30,
                        color: isSelected
                            ? AppTheme.emerald
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppTheme.emerald
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (descriptions != null && i < descriptions!.length) ...[
                      const SizedBox(height: 1),
                      Text(
                        descriptions![i],
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '\u20B9${fare.toInt()}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppTheme.emerald
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$etaVal min away',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(
                          '$capacity',
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (hasAC) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AC',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
