import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/haptic.dart';
import '../../core/animations/staggered_animations.dart';
import '../../core/theme/app_theme.dart';

/// A clean Apple-style grouped list of secondary services accessible from the
/// "More" tab. Replaces the old multi-colored Windows 8-style grid.
class ServicesHubScreen extends StatelessWidget {
  const ServicesHubScreen({super.key});

  static const _services = [
    _HubService(
      icon: Icons.directions_bus_outlined,
      title: 'Transit',
      subtitle: 'Bus, ferry & luggage cloak',
      route: '/transit',
    ),
    _HubService(
      icon: Icons.shopping_bag_outlined,
      title: 'Shop',
      subtitle: 'Essentials & daily needs',
      route: '/essentials',
    ),
    _HubService(
      icon: Icons.museum_outlined,
      title: 'Explore',
      subtitle: 'Experiences & safety tips',
      route: '/experiences',
    ),
    _HubService(
      icon: Icons.person_outline,
      title: 'Profile',
      subtitle: 'Account, themes & settings',
      route: '/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Services'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          return FadeSlideIn(
            delay: Duration(milliseconds: index * 60),
            child: _HubRow(
              service: service,
              isFirst: index == 0,
              isLast: index == _services.length - 1,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

class _HubService {
  const _HubService({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.service,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
  });

  final _HubService service;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.light();
        context.go(service.route);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.white,
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(AppRadius.lg) : Radius.zero,
            topRight: isFirst ? const Radius.circular(AppRadius.lg) : Radius.zero,
            bottomLeft: isLast ? const Radius.circular(AppRadius.lg) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(AppRadius.lg) : Radius.zero,
          ),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      service.icon,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          service.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
              ),
          ],
        ),
      ),
    );
  }
}
