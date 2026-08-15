import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(venue.name)),
      body: RefreshIndicator(
        onRefresh: _refreshVenue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Hero image
            if (venue.imageUrl != null)
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      imageUrl: venue.imageUrl!,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.image_not_supported,
                      fallbackColor: AppTheme.lagoon.withValues(alpha: 0.2),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              venue.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                          ),
                          if (venue.isPriorityPingActive)
                            const StatusBadge(
                              label: 'Priority Ping',
                              variant: BadgeVariant.warning,
                              icon: Icons.bolt,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 600),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
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
                        icon: const Icon(Icons.event_seat),
                        label: const Text('Book cover / reservations'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          Icon(icon, size: 20, color: AppTheme.lagoon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}