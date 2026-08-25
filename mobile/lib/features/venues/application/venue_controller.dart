import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/venue_api.dart';

/// Fetches the venue catalogue once, then re-polls every 30s so the
/// "vibe check" occupancy reflects the Redis-backed live state on the server.
final venueListProvider = AsyncNotifierProvider<VenueListController, List<Venue>>(
  VenueListController.new,
);

/// Bookable experiences & attractions (category = Experience).
final experiencesProvider = FutureProvider<List<Venue>>(
  (ref) => ref.watch(venueApiProvider).list(category: 8),
);

class VenueListController extends AsyncNotifier<List<Venue>> {
  Timer? _poller;

  @override
  Future<List<Venue>> build() async {
    ref.onDispose(() => _poller?.cancel());
    _poller = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    // Retry up to 3 times if the venue list comes back empty — this guards
    // against a race condition where the auth token isn't ready yet on the
    // very first load after login, causing the API to return an empty list.
    for (var attempt = 0; attempt < 3; attempt++) {
      final venues = await ref.watch(venueApiProvider).list();
      if (venues.isNotEmpty) return venues;
      await Future.delayed(const Duration(milliseconds: 800));
    }
    return ref.watch(venueApiProvider).list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.watch(venueApiProvider).list());
  }
}