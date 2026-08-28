import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/config/service_area_config.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../home/presentation/contextual_home.dart';
import '../application/venue_controller.dart';
import '../data/venue_api.dart';
import 'vibe.dart';
import '../../../core/widgets/skeleton_loaders.dart';

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

  static const _categories = ['All', 'Restobars', 'Cafes', 'Pizzerias', 'Beach Clubs', 'Colonial Dining'];

  /// Maps MasterPlan category names to the venue categories returned by the API.
  static const _categoryMapping = {
    'Restobars': ['Restaurant', 'Restobar', 'Bar', 'Pub', 'Nightlife', 'Club', 'Lounge'],
    'Cafes': ['Cafe'],
    'Pizzerias': ['Pizzeria', 'Pizza'],
    'Beach Clubs': ['Beach Club', 'Pub', 'Bar'],
    'Colonial Dining': ['Restaurant', 'Lounge', 'Fine Dining'],
  };

  /// Categories that count as "nightlife" for the default filter.
  static const _nightlifeCategories = ['Bar', 'Club', 'Pub', 'Nightlife', 'Restobar', 'Lounge'];

  /// Curated Pondicherry fallback images by category.
  /// Used when a venue has no imageUrl or the URL fails to load.
  static const _fallbackImages = {
    'nightlife': [
      'https://images.unsplash.com/photo-1572116469696-31def3a40c2c?w=800',
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800',
    ],
    'bar': [
      'https://images.unsplash.com/photo-1572116469696-31def3a40c2c?w=800',
    ],
    'pub': [
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800',
    ],
    'club': [
      'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800',
    ],
    'cafe': [
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
      'https://images.unsplash.com/photo-1500514934834-1f5b9e6d6c7e?w=800',
    ],
    'restaurant': [
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
    ],
    'lounge': [
      'https://images.unsplash.com/photo-1580587774553-5e7e8a4f5d1c?w=800',
    ],
    'default': [
      'https://images.unsplash.com/photo-1580587774553-5e7e8a4f5d1c?w=800',
      'https://images.unsplash.com/photo-1600598546430-3a1e4e9d3e2c?w=800',
      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
    ],
  };

  Widget _buildPartyBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GestureDetector(
        onTap: () {
          AppHaptics.light();
          context.push('/party');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A2E1F), const Color(0xFF0D1A12)]
                  : [const Color(0xFF0D5C3F), const Color(0xFF0A4A33)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.celebration, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Host a Party',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DJ · Bartender · Catering · Sound System',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D5C3F)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fallbackImageFor(String category) {
    final catLower = category.toLowerCase();
    final list = _fallbackImages[catLower] ?? _fallbackImages['default']!;
    return list[category.hashCode.abs() % list.length];
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter == 'nightlife') {
      _categoryFilter = 'Restobars';
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
          (_categoryMapping[_categoryFilter]?.any((c) => c.toLowerCase() == catLower) ?? false) ||
          catLower == _categoryFilter!.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venueListProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Contextual home header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: const ContextualHome(),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                      borderSide: const BorderSide(color: AppTheme.emerald, width: 2),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
          ),

          // Category filters
          SliverToBoxAdapter(
            child: FadeSlideIn(
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
                            color: selected
                                ? AppTheme.charcoal
                                : Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.darkCard
                                    : AppTheme.searchFill,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.slate,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Host a Party banner
          SliverToBoxAdapter(
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _buildPartyBanner(context),
            ),
          ),

          // Venue list
          venuesAsync.when(
            loading: () => const SliverFillRemaining(
              child: const SkeletonList(type: SkeletonType.venue, count: 6),
            ),
            error: (e, _) => SliverFillRemaining(
              child: EmptyStateView(
                isError: true,
                icon: Icons.cloud_off_rounded,
                title: 'Something went wrong',
                subtitle: 'Could not load venues. Please try again.',
                actionLabel: 'Retry',
                onAction: () => ref.read(venueListProvider.notifier).refresh(),
              ),
            ),
            data: (venues) {
              final filtered = _filterVenues(venues);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Icons.search_off,
                    title: 'No venues found',
                    subtitle: 'Try a different search or category.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      AppHaptics.light();
                      setState(() {
                        _searchQuery = '';
                        _categoryFilter = null;
                      });
                    },
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.separated(
                  itemCount: filtered.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${filtered.length} venue${filtered.length == 1 ? '' : 's'} found',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final venueIndex = index - 1;
                    return FadeSlideIn(
                      delay: Duration(milliseconds: venueIndex * 60),
                      child: _VenueCard(
                        venue: filtered[venueIndex],
                        fallbackImage: _fallbackImageFor(filtered[venueIndex].category),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Zomato-style dense venue card with full-width image and overlaid pills.
class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.fallbackImage});

  final Venue venue;
  final String fallbackImage;

  @override
  Widget build(BuildContext context) {
    final vibe = Vibe.fromOccupancy(venue.occupancy);
    final occupancyPct = venue.occupancy.clamp(0, 100);
    final imageUrl = (venue.imageUrl != null && venue.imageUrl!.isNotEmpty)
        ? venue.imageUrl!
        : fallbackImage;

    return Semantics(
      button: true,
      label: '${venue.name}, ${venue.isOpen ? 'open' : 'closed'} now, ${occupancyPct}% busy',
      hint: 'Tap to view venue details',
      child: GestureDetector(
        onTap: () {
          AppHaptics.light();
          context.push('/venues/${venue.id}', extra: venue);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Theme.of(context).brightness == Brightness.dark
                ? Border.all(color: AppTheme.darkBorder)
                : null,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.3)
                    : AppTheme.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section with overlaid pills
              Stack(
                children: [
                  ExcludeSemantics(
                    child: AppNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.local_bar_outlined,
                    ),
                  ),
                // Bottom gradient for pill readability
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                      ),
                    ),
                  ),
                ),
                // Open/Closed pill (top-left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: venue.isOpen
                          ? AppTheme.emerald
                          : AppTheme.danger,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          venue.isOpen ? Icons.circle : Icons.close,
                          size: 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          venue.isOpen ? 'Open' : 'Closed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Priority Ping pill (top-right) — emerald, not orange
                if (venue.isPriorityPingActive)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Priority',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Rating pill (bottom-right)
                if (venue.rating != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 12, color: AppTheme.gold),
                          const SizedBox(width: 3),
                          Text(
                            '${venue.rating!.toStringAsFixed(1)} (${venue.reviewCount})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Vibe pill (bottom-left)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(vibe.icon, size: 12, color: vibe.color),
                        const SizedBox(width: 3),
                        Text(
                          '${vibe.label} \u2022 $occupancyPct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Text section below image
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${venue.category} · ${venue.address ?? 'Pondicherry'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkTextSecondary
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Distance from Pondicherry center (service area).
                      Text(
                        '${_distanceFromCenter(venue.latitude, venue.longitude).toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.emerald,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Haversine distance (km) from the Pondicherry service-area center
/// to the given coordinates. Used as a fallback when
/// the user's exact GPS position is not available.
double _distanceFromCenter(double lat, double lng) {
  final centerLat = ServiceAreaConfig.defaultCenter.latitude;
  final centerLng = ServiceAreaConfig.defaultCenter.longitude;
  const r = 6371.0; // Earth radius in km
  final dLat = _toRad(lat - centerLat);
  final dLng = _toRad(lng - centerLng);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(centerLat)) *
          math.cos(_toRad(lat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _toRad(double deg) => deg * math.pi / 180.0;