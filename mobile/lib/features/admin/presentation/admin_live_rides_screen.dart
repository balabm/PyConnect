import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/service_area_config.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

class AdminLiveRidesScreen extends ConsumerStatefulWidget {
  const AdminLiveRidesScreen({super.key});

  @override
  ConsumerState<AdminLiveRidesScreen> createState() => _AdminLiveRidesScreenState();
}

class _AdminLiveRidesScreenState extends ConsumerState<AdminLiveRidesScreen> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(adminActiveRidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Ops'),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list_rounded : Icons.map_outlined),
            onPressed: () => setState(() => _showMap = !_showMap),
            tooltip: _showMap ? 'Show list' : 'Show map',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminActiveRidesProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
        error: (e, _) => Center(child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))))),
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_outlined, size: 64, color: AdminColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('No Active Rides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('All rides are completed or cancelled', style: TextStyle(color: AdminColors.textMuted)),
                ],
              ),
            );
          }
          if (_showMap) {
            final deliveriesAsync = ref.watch(adminActiveDeliveriesProvider);
            final deliveries = deliveriesAsync.valueOrNull ?? [];
            final driversAsync = ref.watch(adminDriverLocationsProvider);
            final drivers = (driversAsync.valueOrNull ?? [])
                .where((d) => d.isOnline)
                .toList();
            final onlineDrivers = drivers.length;
            return Stack(
              children: [
                _LiveOpsMap(rides: rides, deliveries: deliveries, drivers: drivers),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminColors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 10, color: AdminColors.success),
                        const SizedBox(width: 6),
                        Text(
                          '$onlineDrivers online',
                          style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.two_wheeler, size: 14, color: AdminColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          '${rides.length} rides',
                          style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.shopping_bag_rounded, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '${deliveries.length} deliveries',
                          style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              return _RideCard(ride: ride);
            },
          );
        },
      ),
    );
  }
}

/// Global map showing all active rides, online drivers, and food deliveries.
class _LiveOpsMap extends StatelessWidget {
  const _LiveOpsMap({required this.rides, this.deliveries = const [], this.drivers = const []});

  final List<AdminActiveRide> rides;
  final List<Map<String, dynamic>> deliveries;
  final List<DriverLocation> drivers;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final ride in rides) {
      if (ride.pickupLatitude != null && ride.pickupLongitude != null) {
        markers.add(Marker(
          point: LatLng(ride.pickupLatitude!, ride.pickupLongitude!),
          width: 40,
          height: 40,
          child: Icon(_vehicleIcon(ride.vehicleType), color: _statusColor(ride.status), size: 28),
        ));
      }
      if (ride.dropLatitude != null && ride.dropLongitude != null) {
        markers.add(Marker(
          point: LatLng(ride.dropLatitude!, ride.dropLongitude!),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: AdminColors.danger, size: 28),
        ));
      }
    }
    // Add food delivery markers (orange shopping bag icon at driver location).
    for (final del in deliveries) {
      final lat = (del['latitude'] as num?)?.toDouble();
      final lng = (del['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: const Icon(Icons.shopping_bag_rounded, color: Colors.orange, size: 28),
        ));
      }
    }
    // Add online driver markers (emerald navigation icon).
    for (final d in drivers) {
      markers.add(Marker(
        point: LatLng(d.lat, d.lng),
        width: 40,
        height: 40,
        child: const Icon(Icons.navigation, color: AdminColors.accent, size: 26),
      ));
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: ServiceAreaConfig.defaultCenter,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pondyconnect.admin',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});
  final AdminActiveRide ride;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AdminColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_vehicleIcon(ride.vehicleType), color: AdminColors.accent, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride.riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary)),
                      Text(ride.riderPhone, style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                    ],
                  ),
                ),
                _StatusChip(status: ride.status),
              ],
            ),
            const Divider(height: 24),
            if (ride.driverName != null) ...[
              _InfoRow(icon: Icons.person_rounded, label: 'Driver', value: '${ride.driverName} (${ride.driverPhone})'),
              const SizedBox(height: 8),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 18, color: AdminColors.warning),
                  const SizedBox(width: 8),
                  Text('Searching for driver...', style: TextStyle(color: AdminColors.warning, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ),
            _InfoRow(icon: Icons.location_on_rounded, label: 'Pickup', value: _coords(ride.pickupLatitude, ride.pickupLongitude)),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_off_rounded, label: 'Drop', value: _coords(ride.dropLatitude, ride.dropLongitude)),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.payments_rounded, label: 'Fare', value: '₹${ride.estimatedFare.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.access_time_rounded, label: 'Requested', value: _timeAgo(ride.createdAt)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'searching': case 'requested': return AdminColors.warning;
      case 'driverassigned': case 'accepted': return AdminColors.info;
      case 'arrivedatpickup': return AppTheme.coral;
      case 'enroute': return AdminColors.accent;
      default: return AdminColors.textMuted;
    }
  }
}


class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AdminColors.textMuted),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(fontSize: 13, color: AdminColors.textMuted, fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

IconData _vehicleIcon(String type) {
  switch (type.toLowerCase()) {
    case 'car': return Icons.directions_car_rounded;
    case 'auto': return Icons.local_taxi_rounded;
    default: return Icons.two_wheeler_rounded;
  }
}

Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'searching': case 'requested': return AdminColors.warning;
    case 'driverassigned': case 'accepted': return AdminColors.info;
    case 'arrivedatpickup': return AppTheme.coral;
    case 'enroute': return AdminColors.accent;
    default: return AdminColors.textMuted;
  }
}

String _coords(double? lat, double? lng) {
  if (lat == null || lng == null) return 'N/A';
  return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}
