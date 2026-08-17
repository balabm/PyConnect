import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/venue_controller.dart';
import '../data/venue_api.dart';
import 'vibe.dart';

/// Detailed view of a single venue with an inline booking (cover charge) sheet.
class VenueDetailScreen extends ConsumerStatefulWidget {
  const VenueDetailScreen({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  Venue? _venue;
  bool _loadingDetail = false;
  final _galleryController = PageController();
  int _galleryPage = 0;

  static const _positronTiles = 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  static const _darkMatterTiles = 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venueListProvider);
    final venues = venuesAsync.valueOrNull ?? const <Venue>[];

    _venue ??= venues.cast<Venue?>().firstWhere(
      (v) => v != null && v.id == widget.venueId,
      orElse: () => null,
    );

    // If not in cached list and not loading, fetch from API as fallback.
    if (_venue == null && !_loadingDetail) {
      _loadingDetail = true;
      _fetchVenueFromApi();
    }

    if (_venue == null) {
      final isLoading = venuesAsync.isLoading || _loadingDetail;
      return Scaffold(
        appBar: AppBar(title: const Text('Venue')),
        body: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    const Text('Venue not found'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
        ),
      );
    }

    final venue = _venue!;
    final vibe = Vibe.fromOccupancy(venue.occupancy);
    final occupancyPct = venue.occupancy.clamp(0, 100).toInt();
    final isAtCapacity = occupancyPct >= 100;
    final isClosed = !venue.isOpen;
    final bookingsDisabled = isAtCapacity || isClosed;

    // Use curated fallback image when no venue image is available.
    final heroImageUrl = (venue.imageUrl != null && venue.imageUrl!.isNotEmpty)
        ? venue.imageUrl!
        : _fallbackImageFor(venue.category);

    // Gallery images: use venue image + curated fallbacks
    final galleryImages = [
      heroImageUrl,
      ..._galleryFallbacksFor(venue.category),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshVenue,
        child: CustomScrollView(
          slivers: [
            // Hero image in SliverAppBar — shrinks on scroll
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              floating: false,
              snap: false,
              backgroundColor: AppTheme.night,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  AppHaptics.light();
                  context.pop();
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  tooltip: 'Share venue',
                  onPressed: () { _shareVenue(venue); },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                stretchModes: const [StretchMode.zoomBackground],
                title: Text(
                  venue.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                    ],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _galleryController,
                      itemCount: galleryImages.length,
                      onPageChanged: (i) => setState(() => _galleryPage = i),
                      itemBuilder: (context, i) => AppNetworkImage(
                        imageUrl: galleryImages[i],
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.local_bar_outlined,
                      ),
                    ),
                    // Gallery page dots
                    if (galleryImages.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(galleryImages.length, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _galleryPage ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _galleryPage
                                    ? AppTheme.emerald
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                    // Gradient overlay for title readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                          stops: const [0, 0.5, 1],
                        ),
                      ),
                    ),
                    // Priority Ping badge
                    if (venue.isPriorityPingActive)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        right: 16,
                        child: SafeArea(
                          top: true,
                          child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald,
                            borderRadius: BorderRadius.circular(16),
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
                    ),
                  ],
                ),
              ),
            ),
            // Detail content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Rating + vibe row
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Row(
                      children: [
                        if (venue.rating != null)
                          RatingStars(rating: venue.rating!, reviewCount: venue.reviewCount)
                        else
                          Text(venue.category, style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        StatusBadge(
                          label: venue.isOpen ? 'Open' : 'Closed',
                          variant: venue.isOpen ? BadgeVariant.success : BadgeVariant.danger,
                          icon: venue.isOpen ? Icons.circle : Icons.cancel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Vibe gauge
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: vibe.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        children: [
                          Icon(vibe.icon, color: vibe.color, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${vibe.label} now',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: vibe.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: occupancyPct / 100,
                                  backgroundColor: vibe.color.withValues(alpha: 0.2),
                                  color: vibe.color,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$occupancyPct% capacity${venue.maxCapacity != null ? " / ${venue.maxCapacity}" : ""}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Proactive closed banner
                  if (isClosed)
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.do_not_disturb, color: AppTheme.danger, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Currently Unavailable — Closed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.danger,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'This venue is not accepting bookings right now. Check the operating hours below or try another spot.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.danger.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Proactive capacity banner
                  if (isAtCapacity)
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.do_not_disturb, color: AppTheme.danger, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sold Out — At Full Capacity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.danger,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'This venue is fully booked for now. Check back later or try another spot.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.danger.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (venue.address != null)
                    FadeSlideIn(delay: const Duration(milliseconds: 300), child: _InfoTile(icon: Icons.place_outlined, text: venue.address!)),
                  if (venue.description != null) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 400),
                      child: SectionHeader(icon: Icons.info_outline, title: 'About'),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 450),
                      child: Text(venue.description!, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (venue.availability != null && venue.availability!.isNotEmpty) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 500),
                      child: SectionHeader(icon: Icons.schedule, title: 'Operating Hours'),
                    ),
                    const SizedBox(height: 8),
                    ...venue.availability!.map((a) => FadeSlideIn(
                          delay: const Duration(milliseconds: 550),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_dayOfWeekLabel(a.dayOfWeek),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        )),
                                Text(
                                  '${_formatTime(a.opensAt)} – ${_formatTime(a.closesAt)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                  const SizedBox(height: 24),
                  if (_amenitiesFor(venue.category).isNotEmpty) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 560),
                      child: const SectionHeader(icon: Icons.auto_awesome, title: 'Amenities'),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 580),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _amenitiesFor(venue.category)
                            .map((a) => Chip(
                                  label: Text(a),
                                  backgroundColor: AppTheme.emerald.withValues(alpha: 0.08),
                                  side: BorderSide.none,
                                  labelStyle: const TextStyle(color: AppTheme.emerald, fontSize: 12),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 590),
                    child: _InfoTile(icon: Icons.checkroom, text: _dressCodeFor(venue.category)),
                  ),
                  const SizedBox(height: 28),
                  // Menu Highlights
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 570),
                    child: const SectionHeader(icon: Icons.restaurant_menu, title: 'Menu Highlights'),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 580),
                    child: SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _menuHighlightsFor(venue.category).length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _menuHighlightsFor(venue.category)[index];
                          return _MenuHighlightCard(name: item);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Interactive location map
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 590),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 200,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(venue.latitude, venue.longitude),
                                initialZoom: 14,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: Theme.of(context).brightness == Brightness.dark ? _darkMatterTiles : _positronTiles,
                                  userAgentPackageName: 'com.pondyconnect.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(venue.latitude, venue.longitude),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: AppTheme.emerald,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (venue.address != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            venue.address!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.directions, color: AppTheme.emerald),
                            label: const Text('Get Directions'),
                            onPressed: () {
                              AppHaptics.light();
                              final url = Uri.parse(
                                'https://www.openstreetmap.org/directions?from=&to=${venue.latitude}%2C${venue.longitude}',
                              );
                              launchUrl(url, mode: LaunchMode.externalApplication);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 600),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: bookingsDisabled
                            ? null
                            : () async {
                                AppHaptics.light();
                                final booked = await context.push<bool>(
                                  '/venues/${venue.id}/book',
                                  extra: venue,
                                );
                                if (booked == true && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Booking confirmed')),
                                  );
                                }
                              },
                        icon: Icon(bookingsDisabled ? Icons.do_not_disturb : Icons.event_seat),
                        label: Text(
                          isClosed
                              ? 'Closed — Not accepting bookings'
                              : isAtCapacity
                                  ? 'Sold Out - At Full Capacity'
                                  : 'Book cover / reservations',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Curated Pondicherry fallback images by category.
  static const _fallbackImages = {
    'nightlife': 'https://images.unsplash.com/photo-1572116469696-31def3a40c2c?w=800',
    'bar': 'https://images.unsplash.com/photo-1572116469696-31def3a40c2c?w=800',
    'pub': 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800',
    'club': 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800',
    'cafe': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
    'restaurant': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
    'lounge': 'https://images.unsplash.com/photo-1580587774553-5e7e8a4f5d1c?w=800',
  };

  String _fallbackImageFor(String category) {
    final catLower = category.toLowerCase();
    return _fallbackImages[catLower] ??
        'https://images.unsplash.com/photo-1600598546430-3a1e4a9e2c8e?w=800';
  }

  List<String> _galleryFallbacksFor(String category) {
    final catLower = category.toLowerCase();
    final base = _fallbackImages[catLower] ??
        'https://images.unsplash.com/photo-1600598546430-3a1e4a9e2c8e?w=800';
    return [
      base,
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
      'https://images.unsplash.com/photo-1572116469696-31de77f4a8d1?w=800',
    ];
  }

  Future<void> _fetchVenueFromApi() async {
    try {
      final venue = await ref.read(venueApiProvider).getById(widget.venueId);
      if (mounted) {
        setState(() {
          _venue = venue;
          _loadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  Future<void> _refreshVenue() async {
    setState(() {
      _venue = null;
      _loadingDetail = true;
    });
    await _fetchVenueFromApi();
    ref.invalidate(venueListProvider);
  }

  Future<void> _shareVenue(Venue venue) async {
    await Share.share(
      'Check out ${venue.name} on PY Connect! https://pyconnect.run.place/venue/${venue.id}',
      subject: venue.name,
    );
  }

  String _dayOfWeekLabel(DayOfWeek day) {
    const labels = {
      DayOfWeek.monday: 'Mon',
      DayOfWeek.tuesday: 'Tue',
      DayOfWeek.wednesday: 'Wed',
      DayOfWeek.thursday: 'Thu',
      DayOfWeek.friday: 'Fri',
      DayOfWeek.saturday: 'Sat',
      DayOfWeek.sunday: 'Sun',
    };
    return labels[day] ?? day.name;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  List<String> _amenitiesFor(String category) {
    final c = category.toLowerCase();
    if (['pub', 'bar', 'club', 'nightlife', 'lounge'].contains(c)) {
      return const ['DJ', 'Dance Floor', 'Smoking Area', 'WiFi', 'Air Conditioning'];
    }
    if (['restaurant', 'cafe'].contains(c)) {
      return const ['Air Conditioning', 'Outdoor Seating', 'WiFi', 'Valet Parking'];
    }
    return const ['WiFi', 'Parking', 'Air Conditioning'];
  }

  String _dressCodeFor(String category) {
    final c = category.toLowerCase();
    if (['pub', 'bar', 'club', 'nightlife', 'lounge'].contains(c)) {
      return 'Smart casual. No flip-flops or beachwear after 7 PM.';
    }
    if (['restaurant', 'cafe'].contains(c)) {
      return 'Casual. Family-friendly attire welcome.';
    }
    return 'Casual';
  }

  List<String> _menuHighlightsFor(String category) {
    final c = category.toLowerCase();
    if (['pub', 'bar', 'club', 'nightlife', 'lounge'].contains(c)) {
      return const ['Cocktails', 'Beer Tower', 'Mocktails', 'Tapas', 'Shots'];
    }
    if (['restaurant'].contains(c)) {
      return const ['Chef Special', 'Biryani', 'Pasta', 'Pizza', 'Desserts'];
    }
    if (['cafe'].contains(c)) {
      return const ['Cold Brew', 'Cappuccino', 'Croissant', 'Cheesecake', 'Sandwich'];
    }
    if (['pizzeria'].contains(c)) {
      return const ['Margherita', 'Pepperoni', 'Calzone', 'Garlic Bread', 'Tiramisu'];
    }
    return const ['Popular', 'Specials', 'Drinks', 'Desserts'];
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.emerald),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MenuHighlightCard extends StatelessWidget {
  const _MenuHighlightCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant, color: AppTheme.emerald, size: 24),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}