import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/app_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../application/time_context_controller.dart';

/// Context-aware home that displays a clean greeting and curated
/// photography-driven collections based on the time of day.
/// No solid-color blocks — the UI stays invisible so imagery stands out.
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

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.greeting,
    required this.subtitle,
  });

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.slate,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A curated, 16:9 image card with a bottom scrim for legible text.
class _CuratedCard extends StatefulWidget {
  const _CuratedCard({
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.route,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? route;

  @override
  State<_CuratedCard> createState() => _CuratedCardState();
}

class _CuratedCardState extends State<_CuratedCard>
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
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
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
        if (widget.route != null) context.go(widget.route!);
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          width: 220,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.4)
                    : AppTheme.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                imageUrl: widget.imageUrl,
                height: double.infinity,
                width: double.infinity,
                fit: BoxFit.cover,
                fallbackIcon: Icons.image_outlined,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.bottomImageScrim,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal section containing a title and a scrollable row of curated image cards.
class _CuratedCollectionsSection extends StatelessWidget {
  const _CuratedCollectionsSection({
    required this.title,
    required this.cards,
  });

  final String title;
  final List<_CuratedCard> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeSlideIn(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.charcoal,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: cards,
          ),
        ),
      ],
    );
  }
}

// --- Time-of-day home variants ---

class _MorningArrival extends StatelessWidget {
  const _MorningArrival({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('morning'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroHeader(
            greeting: 'Good morning!',
            subtitle: 'Arriving in Pondy? Let\'s get you sorted.',
          ),
          const SizedBox(height: 20),
          _CuratedCollectionsSection(
            title: 'Start the Day',
            cards: [
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
                title: 'Artisanal Breakfast',
                subtitle: 'Bakeries & cafés',
                route: '/food',
              ),
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
                title: 'Beach Vibes',
                subtitle: 'Promenade walks',
                route: '/venues',
              ),
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
                title: 'Coastal Coffee',
                subtitle: 'Cool cafés nearby',
                route: '/venues?category=Cafe',
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroHeader(
            greeting: 'Beat the heat',
            subtitle: 'AC cafés, chilled drinks & cool spots',
          ),
          const SizedBox(height: 20),
          _CuratedCollectionsSection(
            title: 'Cool Down',
            cards: [
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
                title: 'AC Cafes',
                subtitle: 'Iced coffee & bites',
                route: '/venues?category=Cafe',
              ),
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1563729784474-d877f61cd093?w=800',
                title: 'Gelato & Chill',
                subtitle: 'Desserts to cool off',
                route: '/food',
              ),
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
                title: 'Beachside Rentals',
                subtitle: 'Scooters & luggage drop',
                route: '/transit',
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroHeader(
            greeting: 'Nightlife tonight',
            subtitle: 'Pubs, clubs & live crowd in Pondy',
          ),
          const SizedBox(height: 20),
          _CuratedCollectionsSection(
            title: 'Tonight',
            cards: [
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1572116469696-31def3a40c2c?w=800',
                title: 'Pub Entry',
                subtitle: 'Skip the line',
                route: '/venues?filter=nightlife',
              ),
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800',
                title: 'Clubs & DJs',
                subtitle: 'Dance floors nearby',
                route: '/venues?filter=nightlife',
              ),
              _CuratedCard(
                imageUrl: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
                title: 'Dinner First',
                subtitle: 'Restaurants open now',
                route: '/food',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
