import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/waiver_sheet.dart';
import '../../rides/presentation/rides_screen.dart';
import '../../vendor/data/vendor_api.dart';
import '../application/transit_controller.dart';
import '../data/luggage_api.dart';
import '../data/rental_api.dart';
import '../data/transit_api.dart';

/// The unified "Transit & Ride" hub: ride hailing, intercity pickup sync,
/// luggage cloak network, and hyper-local mobility (rentals / bike taxis).
///
/// Replaces the standalone RideHailingScreen tab and the separate Transit
/// route. Ride hailing is the first (default) sub-tab since it's the most
/// frequently used feature.
class TransitScreen extends ConsumerStatefulWidget {
  const TransitScreen({super.key});

  @override
  ConsumerState<TransitScreen> createState() => _TransitScreenState();
}

class _TransitScreenState extends ConsumerState<TransitScreen> {
  int _index = 0;

  bool get _authed => ref.read(authTokenProvider) != null;

  @override
  Widget build(BuildContext context) {
    // The Ride tab (index 0) is a full-screen map experience.
    // Use extendBody so the map extends behind the nav bar,
    // giving the bottom sheet 100% of vertical real estate.
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          RideHailingScreen(),
          _TripsPickupTab(),
          _LuggageCloakTab(),
          _MobilityTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Ride',
          ),
          NavigationDestination(
            icon: Icon(Icons.tour_outlined),
            selectedIcon: Icon(Icons.tour),
            label: 'Pickups',
          ),
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: 'Luggage',
          ),
          NavigationDestination(
            icon: Icon(Icons.electric_scooter_outlined),
            selectedIcon: Icon(Icons.electric_scooter),
            label: 'Rentals',
          ),
        ],
      ),
    );
  }
}

/// Intercity pickup sync: pick bus stand/airport, tell us your arrival, get a
/// transparently-priced pickup booked.
class _TripsPickupTab extends ConsumerWidget {
  const _TripsPickupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authTokenProvider) != null;
    final hubs = ref.watch(transitHubsProvider);
    final trips = ref.watch(userTripsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: SectionHeader(
            icon: Icons.tour,
            title: 'Intercity Transit Sync',
            subtitle: 'Arriving by bus from Bengaluru/Chennai or a flight to PNY? '
                'We pre-book a transparently priced pickup at the stand or airport.',
          ),
        ),
        const SizedBox(height: 4),
        hubs.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Text('Could not load transit hubs: $e', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
          ),
          data: (hubs) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < hubs.length; i++)
                FadeSlideIn(
                  delay: Duration(milliseconds: i * 80),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [BoxShadow(color: AppTheme.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        onTap: authed
                            ? () { AppHaptics.light(); _openBookingSheet(context, hubs[i]); }
                            : () { AppHaptics.light(); _promptLogin(context); },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.emerald.withValues(alpha: 0.15),
                                child: Icon(
                                  hubs[i].kind == 'Airport' ? Icons.flight_takeoff : Icons.directions_bus,
                                  color: AppTheme.emerald,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(hubs[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    Text(hubs[i].address ?? hubs[i].kind, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (authed) ...[
          const SizedBox(height: 16),
          Text('Your Pickups', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          trips.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('$e', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(Icons.tour_outlined, size: 32, color: AppTheme.emerald.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 12),
                          Text('No pickups booked yet.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final t in items)
                        _TripCard(trip: t),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  void _promptLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log in to book a pickup.')),
    );
  }

  Future<void> _openBookingSheet(BuildContext context, TransitHub hub) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripBookingSheet(hub: hub),
    );
  }
}

StatusBadge _tripStatusBadge(String status) {
  return switch (status) {
    'Pending' => const StatusBadge(label: 'Pending', variant: BadgeVariant.warning, icon: Icons.hourglass_top),
    'Assigned' => const StatusBadge(label: 'Assigned', variant: BadgeVariant.info, icon: Icons.local_taxi),
    'InProgress' => const StatusBadge(label: 'En route', variant: BadgeVariant.info, icon: Icons.directions_car),
    'Completed' => const StatusBadge(label: 'Completed', variant: BadgeVariant.success, icon: Icons.check_circle),
    'Cancelled' => const StatusBadge(label: 'Cancelled', variant: BadgeVariant.danger, icon: Icons.cancel),
    _ => StatusBadge(label: status),
  };
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TransitTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppTheme.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    trip.arrivalMode == 'Flight' ? Icons.flight_takeoff
                        : trip.arrivalMode == 'Train' ? Icons.train
                        : Icons.directions_bus,
                    color: AppTheme.emerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.hubName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'From ${trip.arrivalFrom} · ${trip.arrivalAt.day}/${trip.arrivalAt.month} '
                        '${trip.arrivalAt.hour}:${trip.arrivalAt.minute < 10 ? '0' : ''}${trip.arrivalAt.minute}',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _tripStatusBadge(trip.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (trip.dropOffLocation != null)
                  Text('To: ${trip.dropOffLocation}',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))
                else
                  Text('${trip.partySize} pax',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(
                  '\u20B9${trip.price.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripBookingSheet extends ConsumerStatefulWidget {
  const _TripBookingSheet({required this.hub});

  final TransitHub hub;

  @override
  ConsumerState<_TripBookingSheet> createState() => _TripBookingSheetState();
}

class _TripBookingSheetState extends ConsumerState<_TripBookingSheet> {
  final _from = TextEditingController();
  String _mode = 'Bus';
  DateTime _arrival = DateTime.now().add(const Duration(hours: 2));
  int _party = 1;
  final _dropoff = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _baseFare = 250.0; // transparent flat pickup price

  @override
  void dispose() {
    _from.dispose();
    _dropoff.dispose();
    super.dispose();
  }

  double get _price => _baseFare + (_party > 3 ? 50 * (_party - 3) : 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
          ),
          Text(
            'Book pickup · ${widget.hub.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _from,
            decoration: InputDecoration(
              labelText: 'Arriving from (e.g. Bengaluru)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Bus', label: Text('Bus')),
              ButtonSegment(value: 'Flight', label: Text('Flight')),
              ButtonSegment(value: 'Train', label: Text('Train')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule, color: AppTheme.emerald),
            title: const Text('Arrival time'),
            subtitle: Text(
              '${_arrival.day}/${_arrival.month} ${_arrival.hour}:${_arrival.minute > 9 ? '' : '0'}${_arrival.minute}',
            ),
            trailing: const Icon(Icons.edit_calendar, color: AppTheme.emerald),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _arrival,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 14)),
              );
              if (picked == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_arrival),
              );
              if (time == null || !context.mounted) return;
              setState(() {
                _arrival = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
              });
            },
          ),
          Row(
            children: [
              const Text('Party size'),
              const Spacer(),
              IconButton(
                onPressed: _party > 1 ? () => setState(() => _party--) : null,
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.emerald),
              ),
              Text('$_party', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: _party < 10 ? () => setState(() => _party++) : null,
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.emerald),
              ),
            ],
          ),
          TextField(
            controller: _dropoff,
            decoration: InputDecoration(
              labelText: 'Drop-off (hotel / area) — optional',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Estimated fare: \u20B9${_price.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.emerald, fontWeight: FontWeight.bold),
          ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                : const Text('Confirm pickup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_from.text.trim().isEmpty) {
      setState(() => _error = 'Please enter where you\'re arriving from.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(transitApiProvider).createTrip(
        hubId: widget.hub.id,
        arrivalFrom: _from.text.trim(),
        arrivalMode: _mode,
        arrivalAt: _arrival,
        partySize: _party,
        price: _price,
        dropOffLocation: _dropoff.text.trim().isEmpty ? null : _dropoff.text.trim(),
      );
      if (mounted) {
        ref.invalidate(userTripsProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup request created! A driver will be assigned.')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// Luggage cloak network tab.
class _LuggageCloakTab extends ConsumerWidget {
  const _LuggageCloakTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authTokenProvider) != null;
    final dropOffs = ref.watch(userLuggageProvider);
    final vendors = ref.watch(luggageCloakVendorsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: SectionHeader(
            icon: Icons.luggage,
            title: 'Luggage Cloak Network',
            subtitle: 'Drop bags with trusted partners near Rock Beach and transit hubs '
                'for hourly secure storage.',
          ),
        ),
        const SizedBox(height: 4),
        if (!authed)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: AppTheme.emerald, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Log in to book luggage storage near your arrival hub.',
                    style: TextStyle(color: AppTheme.emerald, fontSize: 14))),
              ],
            ),
          )
        else ...[
          // Vendor list
          vendors.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('Could not load cloak points: $e', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
            data: (vendorList) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Cloak Points (${vendorList.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (int i = 0; i < vendorList.length; i++)
                  FadeSlideIn(
                    delay: Duration(milliseconds: i * 80),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [BoxShadow(color: AppTheme.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () async {
                            AppHaptics.light();
                            final created = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _LuggageBookingSheet(vendor: vendorList[i]),
                            );
                            if (created == true && context.mounted) {
                              ref.invalidate(userLuggageProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Luggage slot reserved!')),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.emerald.withValues(alpha: 0.15),
                                  child: const Icon(Icons.storefront, color: AppTheme.emerald),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(vendorList[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      Text(vendorList[i].contactPhone != null
                                          ? 'Call ${vendorList[i].contactPhone}'
                                          : 'Secure hourly storage',
                                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: const Text(
                                    '\u20B960/hr',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Existing bookings
          Text('Your Bookings', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          dropOffs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('$e', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(Icons.luggage_outlined, size: 32, color: AppTheme.emerald.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 12),
                          Text('No luggage drop-offs yet.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final l in items)
                        _LuggageBookingCard(
                          dropOff: l,
                          onCancel: l.status == 'Reserved' ? () async {
                            try {
                              await ref.read(luggageApiProvider).cancelDropOff(l.id);
                              if (context.mounted) {
                                ref.invalidate(userLuggageProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Booking cancelled.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not cancel: $e')),
                                );
                              }
                            }
                          } : null,
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

/// Status badge color mapping for luggage bookings.
StatusBadge _luggageStatusBadge(String status) {
  return switch (status) {
    'Reserved' => const StatusBadge(label: 'Reserved', variant: BadgeVariant.info, icon: Icons.bookmark),
    'Dropped' => const StatusBadge(label: 'Dropped', variant: BadgeVariant.warning, icon: Icons.luggage),
    'Collected' => const StatusBadge(label: 'Collected', variant: BadgeVariant.success, icon: Icons.check_circle),
    'Cancelled' => const StatusBadge(label: 'Cancelled', variant: BadgeVariant.danger, icon: Icons.cancel),
    _ => StatusBadge(label: status),
  };
}

class _LuggageBookingCard extends StatelessWidget {
  const _LuggageBookingCard({required this.dropOff, this.onCancel});

  final LuggageDropOff dropOff;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppTheme.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.luggage, color: AppTheme.emerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${dropOff.bagCount} bags · ${dropOff.vendorName}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Dropped ${dropOff.droppedAt.day}/${dropOff.droppedAt.month} '
                        '${dropOff.droppedAt.hour}:${dropOff.droppedAt.minute < 10 ? '0' : ''}${dropOff.droppedAt.minute}',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _luggageStatusBadge(dropOff.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\u20B9${dropOff.totalAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                ),
                if (onCancel != null)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LuggageBookingSheet extends ConsumerStatefulWidget {
  const _LuggageBookingSheet({required this.vendor});

  final Vendor vendor;

  @override
  ConsumerState<_LuggageBookingSheet> createState() => _LuggageBookingSheetState();
}

class _LuggageBookingSheetState extends ConsumerState<_LuggageBookingSheet> {
  static const _rate = 60.0;
  DateTime _dropAt = DateTime.now().add(const Duration(hours: 1));
  int _bags = 2;
  int _hours = 4;
  bool _submitting = false;
  String? _error;

  double get _total => _rate * _bags * _hours;

  static String _date(DateTime d) => '${d.day}/${d.month} ${d.hour}:${d.minute < 10 ? '0' : ''}${d.minute}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
          ),
          Text('Reserve at ${widget.vendor.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule, color: AppTheme.emerald),
            title: const Text('Drop time'),
            subtitle: Text(_date(_dropAt)),
            trailing: const Icon(Icons.edit_calendar, color: AppTheme.emerald),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (t == null || !context.mounted) return;
              setState(() {
                _dropAt = DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, t.hour, t.minute)
                    .add(const Duration(hours: 1));
              });
            },
          ),
          Row(children: [
            const Text('Bags'),
            const Spacer(),
            IconButton(onPressed: _bags > 1 ? () => setState(() => _bags--) : null, icon: const Icon(Icons.remove_circle_outline, color: AppTheme.emerald)),
            Text('$_bags', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(onPressed: _bags < 10 ? () => setState(() => _bags++) : null, icon: const Icon(Icons.add_circle_outline, color: AppTheme.emerald)),
          ]),
          Row(children: [
            const Text('Hours'),
            const Spacer(),
            IconButton(onPressed: _hours > 1 ? () => setState(() => _hours--) : null, icon: const Icon(Icons.remove_circle_outline, color: AppTheme.emerald)),
            Text('$_hours', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(onPressed: _hours < 24 ? () => setState(() => _hours++) : null, icon: const Icon(Icons.add_circle_outline, color: AppTheme.emerald)),
          ]),
          Text('Total: \u20B9${_total.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                : const Text('Reserve', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(luggageApiProvider).createDropOff(
        vendorId: widget.vendor.id,
        scheduledFor: _dropAt,
        droppedAt: _dropAt,
        bagCount: _bags,
        ratePerHour: _rate,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// Hyper-local mobility (scooter rentals).
class _MobilityTab extends ConsumerWidget {
  const _MobilityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authTokenProvider) != null;
    final rentals = ref.watch(userRentalsProvider);
    final vendors = ref.watch(scooterRentalVendorsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: SectionHeader(
            icon: Icons.two_wheeler,
            title: 'Hyper-local Mobility',
            subtitle: 'Vetted scooter rental partners with hourly metered pricing. '
                'No bargaining.',
          ),
        ),
        const SizedBox(height: 4),
        if (!authed)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: AppTheme.emerald, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Log in to book scooter rentals.',
                    style: TextStyle(color: AppTheme.emerald, fontSize: 14))),
              ],
            ),
          )
        else ...[
          vendors.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('Could not load rental partners: $e', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
            data: (vendorList) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Rental Partners (${vendorList.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (int i = 0; i < vendorList.length; i++)
                  FadeSlideIn(
                    delay: Duration(milliseconds: i * 80),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [BoxShadow(color: AppTheme.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () async {
                            AppHaptics.light();
                            final created = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _RentalBookingSheet(vendor: vendorList[i]),
                            );
                            if (created == true && context.mounted) {
                              ref.invalidate(userRentalsProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Scooter reserved!')),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.emerald.withValues(alpha: 0.15),
                                  child: const Icon(Icons.two_wheeler, color: AppTheme.emerald),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(vendorList[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      Text(vendorList[i].contactPhone != null
                                          ? 'Call ${vendorList[i].contactPhone}'
                                          : 'Scooters & bikes',
                                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: const Text(
                                    '\u20B9140/hr',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Your Rentals', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          rentals.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('$e', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(Icons.two_wheeler_outlined, size: 32, color: AppTheme.emerald.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 12),
                          Text('No rentals yet.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final r in items)
                        _RentalCard(rental: r),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

StatusBadge _rentalStatusBadge(String status) {
  return switch (status) {
    'Reserved' => const StatusBadge(label: 'Reserved', variant: BadgeVariant.info, icon: Icons.bookmark),
    'Active' => const StatusBadge(label: 'Active', variant: BadgeVariant.warning, icon: Icons.two_wheeler),
    'Completed' => const StatusBadge(label: 'Completed', variant: BadgeVariant.success, icon: Icons.check_circle),
    'Cancelled' => const StatusBadge(label: 'Cancelled', variant: BadgeVariant.danger, icon: Icons.cancel),
    _ => StatusBadge(label: status),
  };
}

class _RentalCard extends StatelessWidget {
  const _RentalCard({required this.rental});

  final ScooterRental rental;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppTheme.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.two_wheeler, color: AppTheme.emerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rental.vehicleName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        '${rental.rentalStart.day}/${rental.rentalStart.month} — '
                        '${rental.rentalEnd.day}/${rental.rentalEnd.month} '
                        '${rental.rentalEnd.hour}:${rental.rentalEnd.minute < 10 ? '0' : ''}${rental.rentalEnd.minute}',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _rentalStatusBadge(rental.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rental.vendorName,
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(
                  '\u20B9${rental.totalAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalBookingSheet extends ConsumerStatefulWidget {
  const _RentalBookingSheet({required this.vendor});

  final Vendor vendor;

  @override
  ConsumerState<_RentalBookingSheet> createState() => _RentalBookingSheetState();
}

class _RentalBookingSheetState extends ConsumerState<_RentalBookingSheet> {
  static const _rate = 140.0;
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  int _hours = 4;
  bool _submitting = false;
  String? _error;

  double get _total => _rate * _hours;

  @override
  Widget build(BuildContext context) {
    final end = _start.add(Duration(hours: _hours));
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
          ),
          Text('Book from ${widget.vendor.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule, color: AppTheme.emerald),
            title: const Text('Rental start'),
            subtitle: Text('${_start.day}/${_start.month} ${_start.hour}:${_start.minute < 10 ? '0' : ''}${_start.minute}'),
            trailing: const Icon(Icons.edit_calendar, color: AppTheme.emerald),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _start,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked == null || !context.mounted) return;
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (t == null || !context.mounted) return;
              setState(() {
                _start = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
              });
            },
          ),
          Row(children: [
            const Text('Duration (hours)'),
            const Spacer(),
            IconButton(onPressed: _hours > 1 ? () => setState(() => _hours--) : null, icon: const Icon(Icons.remove_circle_outline, color: AppTheme.emerald)),
            Text('$_hours', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(onPressed: _hours < 24 ? () => setState(() => _hours++) : null, icon: const Icon(Icons.add_circle_outline, color: AppTheme.emerald)),
          ]),
          Text('Due $_hours h for \u20B9${_total.toStringAsFixed(0)} · end ${end.hour}:${end.minute < 10 ? '0' : ''}${end.minute}',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                : const Text('Reserve scooter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(rentalApiProvider).createRental(
        vendorId: widget.vendor.id,
        vehicleName: 'Suzuki Access / TVS NTorq',
        rentalStart: _start,
        rentalEnd: _start.add(Duration(hours: _hours)),
        ratePerHour: _rate,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on WaiverRequiredException {
      if (mounted) {
        final accepted = await WaiverSheet.show(context);
        if (accepted == true && mounted) {
          _submit(); // Retry after waiver acceptance
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}