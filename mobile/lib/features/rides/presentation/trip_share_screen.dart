import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/osrm_routing_service.dart';
import '../../../core/providers.dart';
import 'widgets/ride_map.dart';

final _tripRouteProvider = FutureProvider.family<RouteResult?, ({LatLng start, LatLng end})>((ref, params) async {
  final routing = ref.watch(routingProvider);
  return await routing.getRoute(params.start, params.end);
});

class TripShareScreen extends ConsumerStatefulWidget {
  const TripShareScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<TripShareScreen> createState() => _TripShareScreenState();
}

class _TripShareScreenState extends ConsumerState<TripShareScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final api = ref.read(ridesApiProvider);
      final trip = await api.getTripShare(widget.token);
      if (mounted) setState(() { _trip = trip; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Trip')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!)
              : _TripBody(trip: _trip!),
    );
  }
}

class _TripBody extends ConsumerWidget {
  const _TripBody({required this.trip});
  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = trip['status'] as String? ?? '';
    final pickupAddress = trip['pickupAddress'] as String? ?? '';
    final dropoffAddress = trip['dropoffAddress'] as String? ?? '';
    final driverName = trip['driverName'] as String?;
    final vehicleType = trip['vehicleType'] as String? ?? 'Bike';
    final vehiclePlate = trip['vehiclePlate'] as String?;
    final driverRating = (trip['driverRating'] as num?)?.toDouble();
    final driverLat = (trip['driverLatitude'] as num?)?.toDouble();
    final driverLng = (trip['driverLongitude'] as num?)?.toDouble();

    final pickupLat = (trip['pickupLat'] as num?)?.toDouble() ?? 11.9356;
    final pickupLng = (trip['pickupLng'] as num?)?.toDouble() ?? 79.8301;
    final dropoffLat = (trip['dropoffLat'] as num?)?.toDouble() ?? 11.9370;
    final dropoffLng = (trip['dropoffLng'] as num?)?.toDouble() ?? 79.8338;

    final pickup = LatLng(pickupLat, pickupLng);
    final dropoff = LatLng(dropoffLat, dropoffLng);

    // Try route points from server first, otherwise fetch via OSRM
    final routePointsFromServer = trip['routePoints'] as List<dynamic>?;
    List<LatLng>? routePoints;
    if (routePointsFromServer != null && routePointsFromServer.isNotEmpty) {
      routePoints = routePointsFromServer
          .whereType<Map>()
          .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
          .toList();
    }

    final routeAsync = routePoints == null
        ? ref.watch(_tripRouteProvider((start: pickup, end: dropoff)))
        : null;

    final effectiveRoutePoints = routePoints ?? routeAsync?.valueOrNull?.points;

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: RideMap(
            pickup: pickup,
            dropoff: dropoff,
            driverLocation: (driverLat != null && driverLng != null) ? LatLng(driverLat, driverLng) : null,
            routePoints: effectiveRoutePoints,
            fitRoute: true,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}').trim(),
                    style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                if (driverName != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(_vehicleIcon(vehicleType), color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (vehiclePlate != null)
                                  Text(vehiclePlate, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                                if (driverRating != null)
                                  Row(children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    Text(' ${driverRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
                                  ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [const Icon(Icons.my_location, color: Colors.blue, size: 20), const SizedBox(width: 8), Expanded(child: Text(pickupAddress, maxLines: 2, overflow: TextOverflow.ellipsis))]),
                        Padding(padding: const EdgeInsets.only(left: 10), child: Container(width: 2, height: 20, color: Theme.of(context).dividerColor)),
                        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(dropoffAddress, maxLines: 2, overflow: TextOverflow.ellipsis))]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are viewing a live trip share. Location updates in real-time.',
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'cancelled':
      case 'drivercancelled': return Colors.red;
      case 'enroute': return Colors.blue;
      default: return Colors.orange;
    }
  }

  IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike': return Icons.two_wheeler;
      case 'auto': return Icons.local_taxi;
      case 'car': return Icons.directions_car;
      default: return Icons.directions;
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('Trip not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('This trip share link may have expired or been disabled.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
