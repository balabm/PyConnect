import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers.dart';
import '../../rides/presentation/widgets/ride_map.dart';

class DriverRideScreen extends ConsumerStatefulWidget {
  const DriverRideScreen({super.key, required this.rideId, required this.driverId});
  final String rideId;
  final String driverId;

  @override
  ConsumerState<DriverRideScreen> createState() => _DriverRideScreenState();
}

class _DriverRideScreenState extends ConsumerState<DriverRideScreen> {
  Map<String, dynamic>? _ride;
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<LatLng>? _routePoints;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      final api = ref.read(ridesApiProvider);
      final ride = await api.getRide(widget.rideId);
      if (mounted) {
        setState(() => _ride = ride);
        if (_routePoints == null) _fetchRoute(ride);
        // Auto-fill ride OTP for testing when ride is accepted/arrived
        _autofillRideOtp(ride);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Testing helper: peeks the ride-start OTP from the backend and
  /// auto-fills the OTP input. Retries up to 5 times with 500ms delay.
  /// Silent no-op in production.
  Future<void> _autofillRideOtp(Map<String, dynamic> ride) async {
    final status = (ride['status'] as String?).toString().toLowerCase();
    if (status != 'accepted' && status != 'arrivedatpickup') return;
    if (_otpController.text.isNotEmpty) return;

    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        if (!mounted || _otpController.text.isNotEmpty) return;

        final api = ref.read(ridesApiProvider);
        final otp = await api.peekRideOtp(widget.rideId);
        if (otp != null && otp.isNotEmpty && mounted) {
          _otpController.text = otp;
          setState(() {});
          return;
        }

        if (attempt < 4) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (_) {
      // Silent — autofill is a testing convenience
    }
  }

  Future<void> _fetchRoute(Map<String, dynamic> ride) async {
    final pickupLat = (ride['pickupLat'] as num?)?.toDouble();
    final pickupLng = (ride['pickupLng'] as num?)?.toDouble();
    final dropoffLat = (ride['dropoffLat'] as num?)?.toDouble();
    final dropoffLng = (ride['dropoffLng'] as num?)?.toDouble();
    if (pickupLat == null || pickupLng == null || dropoffLat == null || dropoffLng == null) return;

    // Prefer route points from backend if available
    final routePointsFromServer = ride['routePoints'] as List<dynamic>?;
    if (routePointsFromServer != null && routePointsFromServer.isNotEmpty) {
      final points = routePointsFromServer
          .whereType<Map>()
          .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
          .toList();
      if (points.isNotEmpty && mounted) {
        setState(() => _routePoints = points);
        return;
      }
    }

    // Fallback: compute route via OSRM
    try {
      final routing = ref.read(routingProvider);
      final route = await routing.getRoute(
        LatLng(pickupLat, pickupLng),
        LatLng(dropoffLat, dropoffLng),
      );
      if (mounted && route != null) setState(() => _routePoints = route.points);
    } catch (_) {}
  }

  Future<void> _arriveAtPickup() async {
    AppHaptics.medium();
    setState(() => _loading = true);
    try {
      final api = ref.read(ridesApiProvider);
      await api.arriveAtPickup(widget.rideId);
      _loadRide();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtpAndStart() async {
    AppHaptics.medium();
    if (_otpController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 4-digit OTP shown by the rider')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(ridesApiProvider);
      await api.verifyOtpAndStart(widget.rideId, _otpController.text);
      _loadRide();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP verification failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeRide() async {
    AppHaptics.success();
    setState(() => _loading = true);
    try {
      final api = ref.read(ridesApiProvider);
      // Use actual distance/duration from ride data (or estimated as fallback)
      final distance = (_ride?['distanceKm'] as num?)?.toDouble() ?? 1.0;
      final duration = (_ride?['estimatedDurationMin'] as num?)?.toInt() ?? 10;
      await api.completeWithMetrics(widget.rideId, distance, duration);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride completed!'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelRide() async {
    AppHaptics.heavy();
    setState(() => _loading = true);
    try {
      final api = ref.read(ridesApiProvider);
      await api.cancelByDriver(widget.rideId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Ride')),
        body: Center(
        child: _error != null
            ? ErrorState(message: _error!)
            : const ShimmerList(withImage: false, count: 3),
      ),
      );
    }

    final status = _ride!['status'] as String? ?? 'Unknown';
    final pickupAddress = _ride!['pickupAddress'] as String? ?? '';
    final dropoffAddress = _ride!['dropoffAddress'] as String? ?? '';
    final fare = _ride!['fare'] ?? 0;
    final totalAmount = _ride!['totalAmount'] ?? 0;
    final distanceKm = _ride!['distanceKm'] ?? 0;
    final estimatedDurationMin = _ride!['estimatedDurationMin'] ?? 0;
    final vehicleType = _ride!['vehicleType'] as String? ?? 'Bike';
    final paymentMethod = _ride!['paymentMethod'] as String? ?? 'Cash';

    final pickupLat = (_ride!['pickupLat'] as num?)?.toDouble() ?? 11.9356;
    final pickupLng = (_ride!['pickupLng'] as num?)?.toDouble() ?? 79.8301;
    final dropoffLat = (_ride!['dropoffLat'] as num?)?.toDouble() ?? 11.9370;
    final dropoffLng = (_ride!['dropoffLng'] as num?)?.toDouble() ?? 79.8338;

    final isDriverAssigned = status.toLowerCase() == 'driverassigned';
    final isArrived = status.toLowerCase() == 'arrivedatpickup';
    final isEnRoute = status.toLowerCase() == 'enroute';
    final isCompleted = status.toLowerCase() == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Ride'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: RideMap(
              pickup: LatLng(pickupLat, pickupLng),
              dropoff: LatLng(dropoffLat, dropoffLng),
              routePoints: _routePoints,
              zoom: 14.0,
              fitRoute: true,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label: _formatStatus(status),
                    variant: _statusVariant(status),
                  ),
                  const SizedBox(height: 16),
                  _RouteInfo(pickup: pickupAddress, dropoff: dropoffAddress, distance: '$distanceKm km', eta: '$estimatedDurationMin min'),
                  const SizedBox(height: 16),
                  _FareInfo(fare: '$fare', total: '$totalAmount', payment: paymentMethod, vehicle: vehicleType),
                  const SizedBox(height: 24),
                  if (isDriverAssigned || isArrived) ...[
                    if (isDriverAssigned)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _arriveAtPickup,
                          icon: const Icon(Icons.location_on),
                          label: const Text('Arrive at Pickup'),
                        ),
                      ),
                    if (isDriverAssigned || isArrived) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'Enter OTP from rider',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.password),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _verifyOtpAndStart,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Verify OTP & Start Ride'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openNavigation(pickupLat, pickupLng),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate to Pickup'),
                      ),
                    ),
                  ],
                  if (isEnRoute) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _completeRide,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete Ride'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openNavigation(dropoffLat, dropoffLng),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate to Dropoff'),
                      ),
                    ),
                  ],
                  if (!isCompleted && !isEnRoute) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _loading ? null : _cancelRide,
                      icon: const Icon(Icons.cancel, color: AppTheme.coral),
                      label: const Text('Cancel Ride', style: TextStyle(color: AppTheme.coral)),
                    ),
                  ],
                  if (isCompleted)
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.lagoon, size: 32),
                          SizedBox(width: 12),
                          Text('Ride Completed!', style: TextStyle(color: AppTheme.lagoon, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteInfo extends StatelessWidget {
  const _RouteInfo({required this.pickup, required this.dropoff, required this.distance, required this.eta});
  final String pickup;
  final String dropoff;
  final String distance;
  final String eta;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.my_location, color: AppTheme.sky, size: 20), const SizedBox(width: 8), Expanded(child: Text(pickup, maxLines: 2, overflow: TextOverflow.ellipsis))]),
          Padding(padding: const EdgeInsets.only(left: 10), child: Container(width: 2, height: 20, color: Theme.of(context).dividerColor)),
          Row(children: [const Icon(Icons.location_on, color: AppTheme.coral, size: 20), const SizedBox(width: 8), Expanded(child: Text(dropoff, maxLines: 2, overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Distance: $distance', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)), Text('ETA: $eta', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))]),
        ],
      ),
    );
  }
}

class _FareInfo extends StatelessWidget {
  const _FareInfo({required this.fare, required this.total, required this.payment, required this.vehicle});
  final String fare;
  final String total;
  final String payment;
  final String vehicle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FareRow(label: 'Your earnings (100%)', value: '\u20B9$fare', bold: true, valueColor: AppTheme.lagoon),
          const SizedBox(height: 8),
          FareRow(label: 'Payment: $payment', value: 'Vehicle: $vehicle', small: true),
        ],
      ),
    );
  }
}

String _formatStatus(String status) {
  return status.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}').trim();
}

BadgeVariant _statusVariant(String status) {
  switch (status.toLowerCase()) {
    case 'completed': return BadgeVariant.success;
    case 'cancelled':
    case 'drivercancelled': return BadgeVariant.danger;
    case 'enroute': return BadgeVariant.info;
    case 'arrivedatpickup': return BadgeVariant.warning;
    default: return BadgeVariant.neutral;
  }
}
