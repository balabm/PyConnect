import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/venue_controller.dart';
import '../data/venue_api.dart';
import 'vibe.dart';

class VenueListScreen extends ConsumerStatefulWidget {
  const VenueListScreen({super.key, this.initialCategory, this.initialFilter});

  final String? initialCategory;
  final String? initialFilter;

  @override
  ConsumerState<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends ConsumerState<VenueListScreen> {
  String _searchQuery = '';
  String? _categoryFilter;

  static const _categories = ['All', 'Nightlife', 'Bar', 'Club', 'Cafe', 'Restaurant', 'Lounge', 'Pub'];

  static const _nightlifeCategories = {'Bar', 'Club', 'Pub'};

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter == 'nightlife') {
      _categoryFilter = 'Nightlife';
    } else if (widget.initialCategory != null) {
      _categoryFilter = widget.initialCategory;
    }
  }

  List<Venue> _filterVenues(List<Venue> venues) {
    return venues.where((v) {
      final matchesSearch = _searchQuery.isEmpty || v.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final catLower = v.category.toLowerCase();
      final matchesCategory = _categoryFilter == null ||
          _categoryFilter == 'All' ||
          (_categoryFilter == 'Nightlife' && _nightlifeCategories.any((c) => c.toLowerCase() == catLower)) ||
          catLower == _categoryFilter!.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venueListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find your vibe'),
        actions: [
          IconButton(
            onPressed: () => ref.read(venueListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search venues...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: AppTheme.lagoon, width: 2),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _categories.map((cat) {
                  final selected = _categoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _categoryFilter = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.lagoon : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: selected ? AppTheme.lagoon : Theme.of(context).dividerColor,
                          ),
                          boxShadow: selected
                              ? [BoxShadow(color: AppTheme.lagoon.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: venuesAsync.when(
              loading: () => _VenueShimmer(),
              error: (e, _) => _ErrorState(e: e, onRetry: () => ref.read(venueListProvider.notifier).refresh()),
              data: (venues) {
                final filtered = _filterVenues(venues);
                if (filtered.isEmpty) {
                  return const _EmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(venueListProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => FadeSlideIn(
                      delay: Duration(milliseconds: index * 80),
                      child: _VenueCard(venue: filtered[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ShimmerList(count: 6, withImage: true);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.search_off,
      title: 'No venues found',
      subtitle: 'Try a different search or category.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.e, required this.onRetry});
  final Object e;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(message: e.toString(), onRetry: onRetry);
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final vibe = Vibe.fromOccupancy(venue.occupancy);
    final occupancyPct = venue.occupancy.clamp(0, 100);

    return AppCard(
      imageUrl: venue.imageUrl,
      imageHeight: 100,
      gradient: LinearGradient(
        colors: [vibe.color.withValues(alpha: 0.6), vibe.color],
      ),
      badge: venue.isPriorityPingActive
          ? const StatusBadge(
              label: 'Priority Ping',
              variant: BadgeVariant.warning,
              icon: Icons.bolt,
            )
          : venue.isOpen
              ? const StatusBadge(label: 'Open', variant: BadgeVariant.success, icon: Icons.circle)
              : const StatusBadge(label: 'Closed', variant: BadgeVariant.danger),
      onTap: () => context.push('/venues/${venue.id}', extra: venue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  venue.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (venue.rating != null) ...[
                RatingStars(rating: venue.rating!, reviewCount: venue.reviewCount),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.place, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  venue.address ?? venue.category,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(vibe.icon, size: 16, color: vibe.color),
              const SizedBox(width: 4),
              Text(
                '${vibe.label} · $occupancyPct% full',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: vibe.color,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }
}