import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/network/offline_mutation_queue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers.dart';
import '../application/driver_providers.dart';
import '../../rides/presentation/widgets/ride_map.dart';
import 'floating_trip_hud.dart';
import 'post_trip_summary_sheet.dart';

class DriverRideScreen extends ConsumerStatefulWidget {
  const DriverRideScreen({
    super.key,
    required this.rideId,
    required this.taskId,
    required this.driverId,
  });
  final String rideId;
  final String taskId;
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
  bool _fareSheetShown = false;
  Timer? _tripTimer;
  int _tripSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _tripTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      final api = ref.read(ridesApiProvider);
      final ride = await api.getRide(widget.rideId);
      if (mounted) {
        setState(() => _ride = ride);
        if (_routePoints == null) _fetchRoute(ride);
        // Start the live trip timer when the ride is already en-route.
        _syncTripTimer(ride);
        // Show fare collection sheet when ride is completed
        final status = (ride['status'] as String?).toString().toLowerCase();
        if (status == 'completed' && !_fareSheetShown) {
          _fareSheetShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showFareCollectionSheet(ride);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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

  /// Syncs the live trip timer with the server-side [startedAt] timestamp.
  /// Called on load and after the ride status becomes en-route.
  void _syncTripTimer(Map<String, dynamic> ride) {
    final status = (ride['status'] as String?).toString().toLowerCase();
    if (status != 'enroute') {
      _tripTimer?.cancel();
      return;
    }

    final startedAt = DateTime.tryParse(ride['startedAt']?.toString() ?? '');
    if (startedAt != null) {
      _tripSeconds = DateTime.now().difference(startedAt.toLocal()).inSeconds;
    } else {
      _tripSeconds = 0;
    }

    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _tripSeconds++);
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _arriveAtPickup() async {
    AppHaptics.medium();
    setState(() => _loading = true);
    try {
      final api = ref.read(ridesApiProvider);
      await api.arriveAtPickup(widget.rideId);
      _loadRide();
    } catch (e) {
      if (e is Exception && _isNetworkError(e)) {
        try {
          await ref.read(offlineMutationQueueProvider).enqueue(
                QueuedMutation(
                  id: '${widget.rideId}_arrive',
                  method: 'POST',
                  path: 'api/rides/${widget.rideId}/arrive',
                  createdAt: DateTime.now(),
                ),
              );
          if (mounted) {
            // Optimistically update status so the UI reflects arrival.
            setState(() => _ride?['status'] = 'ArrivedAtPickup');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved offline. Will sync when connection returns.'),
                backgroundColor: AppTheme.warning,
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
          }
        }
      } else if (mounted) {
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
      final api = ref.read(driverApiProvider);
      await api.startTask(widget.taskId, _otpController.text);
      _startLiveTripTimer();
      _loadRide();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && (status == 400 || status == 401 || status == 403)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid OTP. Please ask customer for the correct code.')),
          );
        }
      } else if (isNetworkError(e)) {
        try {
          await ref.read(offlineMutationQueueProvider).enqueue(
                QueuedMutation(
                  id: '${widget.taskId}_start',
                  method: 'POST',
                  path: 'api/driver/tasks/${widget.taskId}/start',
                  body: {'otp': _otpController.text},
                  createdAt: DateTime.now(),
                ),
              );
          if (mounted) {
            _ride?['status'] = 'EnRoute';
            _startLiveTripTimer();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved offline. Will sync when connection returns.'),
                backgroundColor: AppTheme.warning,
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP verification failed. Please try again.')),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verification failed: ${e.message ?? e.toString()}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verification failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Starts (or restarts) the live trip timer at 0 seconds.
  void _startLiveTripTimer() {
    _tripSeconds = 0;
    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _tripSeconds++);
    });
  }

  Future<void> _completeRide() async {
    AppHaptics.success();
    setState(() => _loading = true);
    try {
      final api = ref.read(driverApiProvider);
      await api.completeTask(widget.taskId);
      _loadRide();
    } on DioException catch (e) {
      if (isNetworkError(e)) {
        try {
          await ref.read(offlineMutationQueueProvider).enqueue(
                QueuedMutation(
                  id: '${widget.taskId}_complete',
                  method: 'POST',
                  path: 'api/driver/tasks/${widget.taskId}/complete',
                  createdAt: DateTime.now(),
                ),
              );
          if (mounted) {
            _ride?['status'] = 'Completed';
            _tripTimer?.cancel();
            if (!_fareSheetShown) {
              _fareSheetShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showFareCollectionSheet(_ride!);
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved offline. Will sync when connection returns.'),
                backgroundColor: AppTheme.warning,
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.message ?? e.toString()}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Shows the post-trip summary bottom sheet when a ride is completed.
  ///
  /// Displays a celebratory earnings breakdown (Customer Paid, 0% Platform
  /// Commission, Your Earnings) and a Done button that returns the driver
  /// to the Tasks/Radar screen.
  void _showFareCollectionSheet(Map<String, dynamic> ride) {
    final fare = ride['fare'] ?? ride['totalAmount'] ?? 0;
    final paymentMethod = (ride['paymentMethod'] as String?) ?? 'Cash';
    final fareNum = (fare is num) ? fare.toDouble() : double.tryParse(fare.toString()) ?? 0.0;

    PostTripSummarySheet.show(
      context,
      customerPaid: fareNum,
      driverEarnings: fareNum, // 0% commission → driver keeps 100%
      tripType: 'Ride',
      paymentMethod: paymentMethod,
      onDone: () {
        Navigator.pop(context); // Close the bottom sheet
        // Navigate back to the task pool (Tasks/Radar screen)
        ref.read(activeTaskProvider.notifier).state = null;
        ref.read(driverSelectedTabProvider.notifier).state = 0;
        // Refresh the wallet so the driver sees the new earnings immediately.
        ref.invalidate(driverWalletProvider);
        ref.invalidate(driverWalletDetailProvider);
        if (mounted && Navigator.canPop(context)) Navigator.pop(context); // Pop the ride screen
      },
    );
  }

  Future<void> _cancelRide() async {
    AppHaptics.heavy();
    setState(() => _loading = true);
    try {
      final api = ref.read(ridesApiProvider);
      await api.cancelByDriver(widget.rideId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (e is Exception && _isNetworkError(e)) {
        try {
          await ref.read(offlineMutationQueueProvider).enqueue(
                QueuedMutation(
                  id: '${widget.rideId}_cancel',
                  method: 'POST',
                  path: 'api/rides/${widget.rideId}/cancel-by-driver',
                  createdAt: DateTime.now(),
                ),
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved offline. Will sync when connection returns.'),
                backgroundColor: AppTheme.warning,
              ),
            );
            // Optimistically navigate back — the cancellation will sync later.
            Navigator.pop(context);
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Shows a confirmation dialog for emergency release. The driver's ride
  /// is unassigned and re-dispatched to another driver. The driver is set
  /// back to Online and not penalized.
  void _showEmergencyReleaseDialog() {
    AppHaptics.heavy();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            const SizedBox(width: 8),
            const Text('Emergency Release'),
          ],
        ),
        content: const Text(
          'Release this task? It will be sent back to the dispatch queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _performEmergencyRelease();
            },
            child: const Text('Release Task'),
          ),
        ],
      ),
    );
  }

  Future<void> _performEmergencyRelease() async {
    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).emergencyRelease(widget.rideId);
      if (mounted) {
        ref.read(activeTaskProvider.notifier).state = null;
        ref.read(driverSelectedTabProvider.notifier).state = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task released. Re-dispatched to another driver.'),
            backgroundColor: AppTheme.danger,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNavigation(double lat, double lng) async {
    // Use the native google.navigation: URL scheme for turn-by-turn
    // navigation. This launches the Google Maps app directly in
    // navigation mode, which drivers prefer over in-app maps.
    // Falls back to the web URL if the native scheme is unavailable.
    final nativeUrl = 'google.navigation:q=$lat,$lng&mode=d';
    final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

    final nativeUri = Uri.parse(nativeUrl);
    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchNavigation(String address) async {
    final encoded = Uri.encodeComponent(address);
    final nativeUrl = 'google.navigation:q=$encoded&mode=d';
    final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving';
    final nativeUri = Uri.parse(nativeUrl);
    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  /// Checks if an exception is a network error (vs a server error).
  /// Network errors are queued for retry; server errors are surfaced.
  bool _isNetworkError(Exception e) {
    if (e is DioException) return isNetworkError(e);
    final text = e.toString().toLowerCase();
    return text.contains('connection') ||
        text.contains('timeout') ||
        text.contains('network') ||
        text.contains('socket');
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
        actions: [
          IconButton(
            icon: Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            tooltip: 'Emergency / Vehicle Breakdown',
            onPressed: () => _showEmergencyReleaseDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                RideMap(
                  pickup: LatLng(pickupLat, pickupLng),
                  dropoff: LatLng(dropoffLat, dropoffLng),
                  routePoints: _routePoints,
                  zoom: 14.0,
                  fitRoute: true,
                ),
                // Floating glassmorphic trip HUD overlay
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    bottom: false,
                    child: FloatingTripHud(
                      maneuverIcon: isEnRoute
                          ? Icons.location_on_rounded
                          : Icons.navigation_rounded,
                      maneuverText: isEnRoute
                          ? 'En route to drop-off'
                          : (isDriverAssigned
                              ? 'Head to pickup'
                              : 'Active ride'),
                      etaMinutes: estimatedDurationMin,
                      distanceKm: distanceKm,
                      destinationLabel: isEnRoute
                          ? 'Drop-off: $dropoffAddress'
                          : 'Pickup: $pickupAddress',
                      onTapNavigate: () => _launchNavigation(
                        isEnRoute ? dropoffAddress : pickupAddress,
                      ),
                    ),
                  ),
                ),
              ],
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
                    // Rider info card
                    if (isDriverAssigned) ...[
                      _RiderInfoCard(
                        riderName: (_ride?['riderName'] as String?) ?? 'Customer',
                        riderPhone: _ride?['riderPhone'] as String?,
                        rating: (_ride?['riderRating'] as num?)?.toDouble(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isDriverAssigned)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _arriveAtPickup,
                          icon: const Icon(Icons.location_on),
                          label: const Text('Arrive at Pickup'),
                        ),
                      ),
                    if (isArrived) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        onChanged: (_) => setState(() {}),
                        buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
                        decoration: const InputDecoration(
                          labelText: 'Enter 4-digit OTP from rider',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.password),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading || _otpController.text.length != 4
                              ? null
                              : _verifyOtpAndStart,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Trip'),
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
                    Row(
                      children: [
                        const Icon(Icons.timer, color: AppTheme.emerald),
                        const SizedBox(width: 8),
                        Text(
                          'Trip time: ${_formatDuration(_tripSeconds)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _completeRide,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete Trip'),
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
                      icon: const Icon(Icons.cancel, color: AppTheme.danger),
                      label: const Text('Cancel Ride', style: TextStyle(color: AppTheme.danger)),
                    ),
                  ],
                  if (isCompleted)
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.emerald, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ride Completed! Collecting fare...',
                              style: TextStyle(
                                color: AppTheme.emerald,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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
          Row(children: [const Icon(Icons.location_on, color: AppTheme.emerald, size: 20), const SizedBox(width: 8), Expanded(child: Text(dropoff, maxLines: 2, overflow: TextOverflow.ellipsis))]),
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
          FareRow(label: 'Your earnings (100%)', value: '\u20B9$fare', bold: true, valueColor: AppTheme.emerald),
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

class _RiderInfoCard extends StatelessWidget {
  const _RiderInfoCard({
    required this.riderName,
    this.riderPhone,
    this.rating,
  });

  final String riderName;
  final String? riderPhone;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.emerald.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppTheme.emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(riderName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (rating != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: AppTheme.gold),
                      const SizedBox(width: 2),
                      Text('${rating!.toStringAsFixed(1)} rating',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (riderPhone != null && riderPhone!.isNotEmpty)
            IconButton.filled(
              onPressed: () {
                // Launch phone dialer
              },
              icon: const Icon(Icons.call, size: 18),
            ),
        ],
      ),
    );
  }
}
