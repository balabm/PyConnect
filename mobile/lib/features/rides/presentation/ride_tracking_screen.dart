import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../activity/presentation/post_completion_sheet.dart';
import '../application/ride_signalr_provider.dart';
import 'widgets/driver_info_card.dart';
import 'widgets/fare_card.dart';
import 'widgets/otp_card.dart';
import 'widgets/ride_completed_banner.dart';
import 'widgets/ride_map.dart';
import 'widgets/ride_status_card.dart';
import 'widgets/route_card.dart';
import 'widgets/sos_button.dart';

final rideDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, rideId) async {
  final api = ref.watch(ridesApiProvider);
  return await api.getRide(rideId);
});

class RideTrackingScreen extends ConsumerStatefulWidget {
  const RideTrackingScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  Map<String, dynamic>? _ride;
  DriverLocationUpdate? _driverLocation;
  Map<String, dynamic>? _driverInfo;
  bool _sosActive = false;
  bool _cancelling = false;
  List<LatLng>? _routePoints;
  List<LatLng>? _driverRoutePoints;
  StreamSubscription? _driverAssignedSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _arrivedSub;
  StreamSubscription? _startedSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _cancelledSub;
  Timer? _refreshTimer;
  Timer? _stalenessTimer;
  bool _completionSheetShown = false;

  /// Tracks when the last driver GPS update was received (client-side UTC).
  /// Used to detect the "Ghost Driver" scenario where the captain's phone
  /// loses signal and the car icon stops moving.
  DateTime? _lastGpsUpdateAt;

  /// Whether the driver's GPS has been stale for more than 3 minutes.
  bool _isDriverGpsStale = false;

  /// Stale-GPS threshold for showing the warning banner and waiving fees.
  static const _staleGpsThreshold = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _setupSignalR();
    // Fallback polling in case SignalR fails
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshRide());
    // Staleness checker — runs every 15 seconds to detect Ghost Driver
    _stalenessTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkGpsStaleness());
  }

  Future<void> _setupSignalR() async {
    final signalR = ref.read(rideSignalRProvider);
    try {
      await signalR.joinRide(widget.rideId);

      _driverAssignedSub = signalR.driverAssignedStream.listen((args) {
        if (args.isNotEmpty) {
          final data = args[0];
          if (data is Map) {
            setState(() {
              _driverInfo = Map<String, dynamic>.from(data);
            });
          }
        }
      });

      _locationSub = signalR.driverLocationUpdateStream.listen((args) {
        if (args.isNotEmpty) {
          final data = args[0];
          if (data is Map) {
            final lat = (data['latitude'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              // Parse the server timestamp; fall back to client clock.
              final serverTs = data['serverTimestamp'] as String?;
              DateTime? ts;
              if (serverTs != null) {
                ts = DateTime.tryParse(serverTs);
              }
              ts ??= DateTime.now().toUtc();

              setState(() {
                _driverLocation = DriverLocationUpdate(
                  latitude: lat,
                  longitude: lng,
                  heading: (data['heading'] as num?)?.toDouble(),
                  distanceToPickupKm: (data['distanceToPickupKm'] as num?)?.toDouble(),
                  etaToPickupMin: (data['etaToPickupMin'] as num?)?.toInt(),
                  serverTimestamp: ts,
                );
                _lastGpsUpdateAt = ts;
                // Fresh update — clear stale flag.
                _isDriverGpsStale = false;
              });
            }
          }
        }
      });

      _arrivedSub = signalR.driverArrivedStream.listen((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver has arrived at pickup!'), backgroundColor: AppTheme.success),
          );
        }
      });

      _startedSub = signalR.rideStartedStream.listen((_) => _refreshRide());
      _completedSub = signalR.rideCompletedStream.listen((_) => _refreshRide());
      _cancelledSub = signalR.rideCancelledStream.listen((_) => _refreshRide());
    } catch (_) {
      // SignalR connection failed — fallback polling will keep data fresh
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _stalenessTimer?.cancel();
    _driverAssignedSub?.cancel();
    _locationSub?.cancel();
    _arrivedSub?.cancel();
    _startedSub?.cancel();
    _completedSub?.cancel();
    _cancelledSub?.cancel();
    ref.read(rideSignalRProvider).leaveRide(widget.rideId);
    super.dispose();
  }

  /// Checks whether the driver's GPS has been stale for more than 3 minutes.
  /// If so, sets the stale flag so the warning banner appears and the
  /// cancellation fee is automatically waived.
  void _checkGpsStaleness() {
    if (_lastGpsUpdateAt == null) return;
    final elapsed = DateTime.now().toUtc().difference(_lastGpsUpdateAt!);
    final isStale = elapsed > _staleGpsThreshold;
    if (isStale != _isDriverGpsStale && mounted) {
      setState(() => _isDriverGpsStale = isStale);
    }
  }

  Future<void> _refreshRide() async {
    try {
      final api = ref.read(ridesApiProvider);
      final ride = await api.getRide(widget.rideId);
      if (!mounted) return;
      setState(() => _ride = ride);
      // Fetch route polyline from OSRM if we have coordinates and haven't yet
      if (_routePoints == null) {
        _fetchRoute(ride);
      }
      // Show the post-completion rating sheet when the ride completes.
      _maybeShowCompletionSheet(ride);
    } catch (_) {}
  }

  void _maybeShowCompletionSheet(Map<String, dynamic> ride) {
    final status = (ride['status'] as String?)?.toLowerCase() ?? '';
    if (status != 'completed' || _completionSheetShown) return;
    _completionSheetShown = true;

    final driverId = ride['driverId']?.toString();
    final rideId = (ride['rideId'] ?? ride['id'])?.toString();
    final driverName = _driverInfo?['driverName'] as String? ?? 'your driver';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PostCompletionSheet.show(
        context,
        title: driverName,
        subtitle: 'How was your ride?',
        driverId: driverId,
        rideId: rideId,
      );
    });
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

    // Fetch driver→pickup route for dual-layer polyline
    _fetchDriverRoute(ride, pickupLat, pickupLng);
  }

  /// Fetches the driver→pickup route for the dual-layer polyline overlay.
  Future<void> _fetchDriverRoute(
    Map<String, dynamic> ride,
    double pickupLat,
    double pickupLng,
  ) async {
    if (_driverRoutePoints != null) return;

    // Try driver's current location from the ride data
    final driverLat = (ride['driverLat'] as num?)?.toDouble() ??
        (ride['currentLat'] as num?)?.toDouble();
    final driverLng = (ride['driverLng'] as num?)?.toDouble() ??
        (ride['currentLng'] as num?)?.toDouble();

    // Fall back to driver location update stream
    final dLoc = _driverLocation;
    final dLat = driverLat ?? dLoc?.latitude;
    final dLng = driverLng ?? dLoc?.longitude;

    if (dLat == null || dLng == null) return;

    try {
      final routing = ref.read(routingProvider);
      final route = await routing.getRoute(
        LatLng(dLat, dLng),
        LatLng(pickupLat, pickupLng),
      );
      if (mounted && route != null) {
        setState(() => _driverRoutePoints = route.points);
      }
    } catch (_) {}
  }

  Future<void> _cancelRide() async {
    AppHaptics.heavy();
    setState(() => _cancelling = true);
    try {
      final api = ref.read(ridesApiProvider);
      // If the driver's GPS has been stale for > 3 minutes, request a fee
      // waiver so the rider is not penalised for a driver-side issue.
      final result = await api.cancelByRider(
        widget.rideId,
        reason: _isDriverGpsStale ? 'Driver GPS stale' : null,
        waiveFee: _isDriverGpsStale,
      );
      final fee = result['cancellationFee'];
      final feeWaived = result['feeWaived'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feeWaived
                ? 'Ride cancelled. Fee waived (driver network issue).'
                : fee != null && fee > 0
                    ? 'Ride cancelled. Cancellation fee: \u20B9$fee'
                    : 'Ride cancelled'),
          ),
        );
        _refreshRide();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _triggerSos() async {
    AppHaptics.error();
    try {
      final api = ref.read(ridesApiProvider);
      final loc = _driverLocation;
      await api.triggerSos(widget.rideId, loc?.latitude ?? 11.9356, loc?.longitude ?? 79.8301);
      if (mounted) {
        setState(() => _sosActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS triggered. Emergency contacts notified. Help is on the way.'),
            backgroundColor: AppTheme.danger,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SOS failed: $e')));
      }
    }
  }

  Future<void> _shareTrip() async {
    AppHaptics.light();
    try {
      final api = ref.read(ridesApiProvider);
      final result = await api.enableTripSharing(widget.rideId);
      final token = result['tripShareToken'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip share link: /trip/$token')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(rideDetailProvider(widget.rideId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Ride'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Trip',
            onPressed: _shareTrip,
          ),
        ],
      ),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(rideDetailProvider(widget.rideId)),
        ),
        data: (ride) {
          _ride ??= ride;
          return _TrackingBody(
            ride: _ride ?? ride,
            driverLocation: _driverLocation,
            driverInfo: _driverInfo,
            sosActive: _sosActive,
            onCancel: _cancelRide,
            cancelling: _cancelling,
            onSos: _triggerSos,
            routePoints: _routePoints,
            driverRoutePoints: _driverRoutePoints,
            isDriverGpsStale: _isDriverGpsStale,
          );
        },
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({
    required this.ride,
    required this.driverLocation,
    required this.driverInfo,
    required this.sosActive,
    required this.onCancel,
    required this.cancelling,
    required this.onSos,
    required this.routePoints,
    this.driverRoutePoints,
    this.isDriverGpsStale = false,
  });

  final Map<String, dynamic> ride;
  final DriverLocationUpdate? driverLocation;
  final Map<String, dynamic>? driverInfo;
  final bool sosActive;
  final VoidCallback onCancel;
  final bool cancelling;
  final VoidCallback onSos;
  final List<LatLng>? routePoints;
  final List<LatLng>? driverRoutePoints;
  final bool isDriverGpsStale;

  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? 'Unknown';
    final vehicleType = ride['vehicleType'] as String? ?? 'Bike';
    final fare = ride['fare'] ?? 0;
    final totalAmount = ride['totalAmount'] ?? 0;
    final platformBookingFee = ride['platformBookingFee'] ?? 0;
    final distanceKm = ride['distanceKm'] ?? 0;
    final estimatedDurationMin = ride['estimatedDurationMin'] ?? 0;
    final paymentMethod = ride['paymentMethod'] as String? ?? 'Cash';
    final surgeMultiplier = (ride['surgeMultiplier'] as num?)?.toDouble() ?? 1.0;
    final surgeReason = ride['surgeReason'] as String?;

    final isCompleted = status.toLowerCase() == 'completed';
    final isCancelled = status.toLowerCase() == 'cancelled';
    final canCancel = !isCompleted && !isCancelled && status.toLowerCase() != 'enroute';

    final pickupLat = (ride['pickupLat'] as num?)?.toDouble() ?? 11.9356;
    final pickupLng = (ride['pickupLng'] as num?)?.toDouble() ?? 79.8301;
    final dropoffLat = (ride['dropoffLat'] as num?)?.toDouble() ?? 11.9370;
    final dropoffLng = (ride['dropoffLng'] as num?)?.toDouble() ?? 79.8338;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Live map
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RideMap(
                  pickup: LatLng(pickupLat, pickupLng),
                  dropoff: LatLng(dropoffLat, dropoffLng),
                  driverLocation: driverLocation != null
                      ? LatLng(driverLocation!.latitude, driverLocation!.longitude)
                      : null,
                  routePoints: routePoints,
                  driverRoutePoints: driverRoutePoints,
                  fitRoute: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            RideStatusCard(status: status),
            // Ghost Driver warning — persistent banner when GPS is stale > 3 min
            if (isDriverGpsStale) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.signal_wifi_off, color: AppTheme.warning, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Captain is experiencing network issues',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Their GPS hasn\'t updated in a while. You can cancel without a fee.',
                            style: TextStyle(
                              color: AppTheme.warning.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // OTP display for rider (show when driver assigned, before ride starts)
            if (status.toLowerCase() == 'driverassigned' || status.toLowerCase() == 'arrivedatpickup')
              OtpCard(ride: ride),
            if (status.toLowerCase() == 'driverassigned' || status.toLowerCase() == 'arrivedatpickup')
              const SizedBox(height: 16),
            if (driverInfo != null || status.toLowerCase() != 'requested')
              DriverInfoCard(
                driverInfo: driverInfo,
                vehicleType: vehicleType,
                paymentMethod: paymentMethod,
                etaToPickup: driverLocation?.etaToPickupMin,
              ),
            if (driverInfo != null) const SizedBox(height: 16),
            RouteCard(ride: ride),
            const SizedBox(height: 16),
            FareCard(
              fare: fare,
              platformBookingFee: platformBookingFee,
              totalAmount: totalAmount,
              distanceKm: distanceKm,
              estimatedDurationMin: estimatedDurationMin,
              surgeMultiplier: surgeMultiplier,
              surgeReason: surgeReason,
            ),
            const SizedBox(height: 24),
            if (canCancel)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: cancelling ? null : onCancel,
                  icon: cancelling
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel, color: AppTheme.danger),
                  label: const Text('Cancel Ride', style: TextStyle(color: AppTheme.danger)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
                ),
              ),
            if (isCompleted)
              const RideCompletedBanner(),
            if (isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final driverName = driverInfo?['driverName'] as String? ?? 'Driver';
                        context.push('/rides/${ride['rideId'] ?? ride['id']}/rate?driver=$driverName');
                      },
                      icon: const Icon(Icons.star),
                      label: const Text('Rate Ride'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final rideId = ride['rideId'] ?? ride['id'];
                        context.push('/rides/$rideId/receipt');
                      },
                      icon: const Icon(Icons.receipt),
                      label: const Text('Receipt'),
                    ),
                  ),
                ],
              ),
            ],
            if (isCancelled)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.cancel, color: AppTheme.danger, size: 32),
                    SizedBox(width: 12),
                    Text('Ride Cancelled', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            const SizedBox(height: 80), // Space for SOS button
          ],
        ),
        // SOS button floating at bottom
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: SosButton(onTrigger: onSos, active: sosActive),
          ),
        ),
      ],
    );
  }
}
