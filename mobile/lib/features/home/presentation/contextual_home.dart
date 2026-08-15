import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/modern_animations.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../application/time_context_controller.dart';

/// Context-aware home that changes its greeting, suggestions, and color
/// palette based on the time of day. Uses spring-based animations instead
/// of native animations for test compatibility.
class ContextualHome extends ConsumerWidget {
  const ContextualHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeContext = ref.watch(timeContextProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
      child: _buildContent(context, timeContext),
    );
  }

  Widget _buildContent(BuildContext context, TimeContextState state) {
    switch (state) {
      case TimeContextState.morningArrival:
        return const _MorningArrival(key: ValueKey('morning'));
      case TimeContextState.afternoonHeat:
        return const _AfternoonHeat(key: ValueKey('afternoon'));
      case TimeContextState.eveningNightlife:
        return const _EveningNightlife(key: ValueKey('evening'));
    }
  }
}

/// A premium contextual card with gradient background, icon, and tap animation.
class _ContextualCard extends StatefulWidget {
  const _ContextualCard({
    super.key,
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

  @override
  State<_ContextualCard> createState() => _ContextualCardState();
}

class _ContextualCardState extends State<_ContextualCard>
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
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
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
        context.go(widget.route);
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated hero header with gradient background and greeting.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.greeting,
    required this.subtitle,
    required this.gradient,
    required this.icon,
  });

  final String greeting;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return BounceIn(
      duration: const Duration(milliseconds: 600),
      child: AnimatedGradientHeader(
        colors: gradient,
        borderRadius: AppRadius.xl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MorningArrival extends StatelessWidget {
  const _MorningArrival({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('morning'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const _HeroHeader(
            greeting: 'Good morning!',
            subtitle: 'Arriving in Pondy? Let\'s get you sorted.',
            gradient: [AppTheme.lagoon, AppTheme.lagoonDark],
            icon: Icons.wb_sunny,
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            child: Text(
              'Quick Start',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: const _ContextualCard(
                  key: ValueKey('luggage'),
                  icon: Icons.luggage,
                  title: 'Drop Luggage',
                  subtitle: 'Cloak your bags near the bus stand',
                  gradient: AppTheme.lagoonGradient,
                  route: '/transit',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: const _ContextualCard(
                  key: ValueKey('scooter'),
                  icon: Icons.two_wheeler,
                  title: 'Rent Scooter',
                  subtitle: 'Explore White Town on two wheels',
                  gradient: AppTheme.oceanGradient,
                  route: '/transit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AfternoonHeat extends StatelessWidget {
  const _AfternoonHeat({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('afternoon'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const _HeroHeader(
            greeting: 'Beat the heat!',
            subtitle: 'AC cafes, chilled drinks & cool spots',
            gradient: [AppTheme.lagoon, AppTheme.lagoonDark],
            icon: Icons.icecream,
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            child: Text(
              'Cool Down',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: const _ContextualCard(
                  key: ValueKey('cafe'),
                  icon: Icons.local_cafe,
                  title: 'AC Cafes',
                  subtitle: 'Cool down with iced coffee & bites',
                  gradient: LinearGradient(
                    colors: [AppTheme.lagoon, AppTheme.lagoonDark],
                  ),
                  route: '/venues?category=Cafe',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: const _ContextualCard(
                  key: ValueKey('lunch'),
                  icon: Icons.restaurant,
                  title: 'Lunch',
                  subtitle: 'Wood-fired pizza & local cuisine',
                  gradient: const LinearGradient(
                    colors: [AppTheme.lagoonDark, AppTheme.night],
                  ),
                  route: '/food',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EveningNightlife extends StatelessWidget {
  const _EveningNightlife({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('evening'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _HeroHeader(
            greeting: 'Nightlife tonight!',
            subtitle: 'Pubs, clubs & live crowd in Pondy',
            gradient: [Theme.of(context).colorScheme.onSurface, Color(0xFF6A11CB)],
            icon: Icons.nightlife,
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            child: Text(
              'Tonight',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: const _ContextualCard(
                  key: ValueKey('pub'),
                  icon: Icons.local_bar,
                  title: 'Pub Entry',
                  subtitle: 'Skip the line with cover charge pass',
                  gradient: AppTheme.nightGradient,
                  route: '/venues?filter=nightlife',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: const _ContextualCard(
                  key: ValueKey('vibe'),
                  icon: Icons.people,
                  title: 'Live Crowd Density',
                  subtitle: 'Check real-time venue capacity',
                  gradient: LinearGradient(
                    colors: [AppTheme.lagoonDark, AppTheme.lagoon],
                  ),
                  route: '/venues',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
