import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/haptic.dart';
import '../../core/animations/staggered_animations.dart';
import '../../core/theme/app_theme.dart';

/// A grid of secondary services that were moved out of the bottom navigation.
/// Accessible from the "More" tab.
class ServicesHubScreen extends StatelessWidget {
  const ServicesHubScreen({super.key});

  static const _services = [
    _HubService(
      icon: Icons.directions_bus_outlined,
      title: 'Transit',
      subtitle: 'Bus, ferry & luggage cloak',
      gradient: AppTheme.oceanGradient,
      route: '/transit',
    ),
    _HubService(
      icon: Icons.shopping_bag_outlined,
      title: 'Shop',
      subtitle: 'Essentials & daily needs',
      gradient: AppTheme.lagoonGradient,
      route: '/essentials',
    ),
    _HubService(
      icon: Icons.museum_outlined,
      title: 'Explore',
      subtitle: 'Experiences & safety tips',
      gradient: AppTheme.sunsetGradient,
      route: '/experiences',
    ),
    _HubService(
      icon: Icons.person_outline,
      title: 'Profile',
      subtitle: 'Account, themes & settings',
      gradient: const LinearGradient(
        colors: [AppTheme.night, AppTheme.lagoonDark],
      ),
      route: '/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More Services')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.1,
        children: _services.map((s) {
          final index = _services.indexOf(s);
          return FadeSlideIn(
            delay: Duration(milliseconds: index * 80),
            child: _HubCard(service: s),
          );
        }).toList(),
      ),
    );
  }
}

class _HubService {
  const _HubService({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final String route;
}

class _HubCard extends StatefulWidget {
  const _HubCard({required this.service});
  final _HubService service;

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        AppHaptics.light();
        context.go(widget.service.route);
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.service.gradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: widget.service.gradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.service.icon, color: Colors.white, size: 26),
                ),
                const Spacer(),
                Text(
                  widget.service.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.service.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
