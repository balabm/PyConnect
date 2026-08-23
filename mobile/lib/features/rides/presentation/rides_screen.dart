import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/osm_geocoding_service.dart';
import '../../../core/network/osrm_routing_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/quick_auth_sheet.dart';
import '../../auth/presentation/waiver_sheet.dart';
import 'widgets/map_selection_mode_indicator.dart';
import 'widgets/nearby_drivers_section.dart';
import 'widgets/payment_method_selector.dart';
import 'saved_locations_screen.dart';
import 'widgets/ride_map.dart';
import 'widgets/ride_result_card.dart';
import 'widgets/route_info_bar.dart';
import 'widgets/vehicle_selector.dart';

final nearbyDriversProvider =
    FutureProvider.family<List<dynamic>, ({double lat, double lng})>((ref, params) async {
  final api = ref.watch(ridesApiProvider);
  return await api.nearbyDrivers(params.lat, params.lng);
});

final routeProvider =
    FutureProvider.family<RouteResult?, ({LatLng start, LatLng end})>((ref, params) async {
  final routing = ref.watch(routingProvider);
  return await routing.getRoute(params.start, params.end);
});

class RideHailingScreen extends ConsumerStatefulWidget {
  const RideHailingScreen({super.key});

  @override
  ConsumerState<RideHailingScreen> createState() => _RideHailingScreenState();
}

class _RideHailingScreenState extends ConsumerState<RideHailingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedVehicle = 0;
  int _selectedPayment = 0;

  LatLng? _pickupLocation;
  String _pickupAddress = '';
  LatLng? _dropoffLocation;
  String _dropoffAddress = '';

  Map<String, dynamic>? _rideResult;
  bool _loading = false;
  bool _selectingPickup = true;
  bool _locating = false;
  String? _inlineError;

  static const _vehicles = [
    ('Bike', Icons.two_wheeler, 8.0, 15.0, 30.0, 2, 1, false),
    ('Auto', Icons.local_taxi, 12.0, 25.0, 50.0, 4, 3, false),
    ('Car', Icons.directions_car, 15.0, 40.0, 70.0, 6, 4, true),
  ];

  static const _paymentMethods = ['Cash', 'UPI', 'Card'];

  final LatLng _defaultCenter = LatLng(11.9356, 79.8301);

  @override
  void initState() {
    super.initState();
    _pickupLocation = _defaultCenter;
    _pickupAddress = 'Locating...';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLocate();
      ref.read(razorpayPaymentProvider).init();
    });
  }

  Future<void> _autoLocate() async {
    setState(() => _locating = true);
    try {
      final locService = ref.read(locationServiceProvider);
      final pos = await locService.getCurrentLocation();
      if (pos != null && mounted) {
        final geocoding = ref.read(geocodingProvider);
        final result = await geocoding.reverse(pos.latitude, pos.longitude);
        final address = result?.displayName ??
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        setState(() {
          _pickupLocation = pos;
          _pickupAddress = address;
        });
      } else if (mounted) {
        // GPS not available — keep default center but show generic label
        setState(() {
          _pickupAddress = 'Pondicherry (tap map to set exact pickup)';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickupAddress = 'Pondicherry (tap map to set exact pickup)';
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double _calculateFare(int vehicleIndex, double distanceKm, int durationMin) {
    final (_, _, ratePerKm, baseFare, minFare, _, _, _) = _vehicles[vehicleIndex];
    final perMinRate = vehicleIndex == 0 ? 1.0 : vehicleIndex == 1 ? 1.5 : 2.0;
    var fare = baseFare +
        (distanceKm * ratePerKm).ceil() +
        (durationMin * perMinRate).ceil();
    if (fare < minFare) fare = minFare;
    return fare.toDouble();
  }

  int _estimateEta(int vehicleIndex) {
    return _vehicles[vehicleIndex].$6;
  }

  Future<void> _onMapTap(LatLng point) async {
    final geocoding = ref.read(geocodingProvider);
    final result =
        await geocoding.reverse(point.latitude, point.longitude);
    final address = result?.displayName ??
        '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';

    setState(() {
      if (_selectingPickup) {
        _pickupLocation = point;
        _pickupAddress = address;
      } else {
        _dropoffLocation = point;
        _dropoffAddress = address;
      }
      if (_selectingPickup && _dropoffLocation == null) {
        _selectingPickup = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = _pickupLocation != null && _dropoffLocation != null;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _MapActionButton(
              icon: Icons.arrow_back,
              onPressed: () => context.pop(),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: PopupMenuButton<String>(
                offset: const Offset(0, 40),
                icon: const _MapActionButtonIcon(Icons.more_vert),
                onSelected: (value) => context.push(value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: '/rides/history',
                      child: Row(children: [
                        Icon(Icons.history),
                        SizedBox(width: 8),
                        Text('Ride History')
                      ])),
                  const PopupMenuItem(
                      value: '/rides/scheduled',
                      child: Row(children: [
                        Icon(Icons.schedule),
                        SizedBox(width: 8),
                        Text('Scheduled Rides')
                      ])),
                  const PopupMenuItem(
                      value: '/rides/saved-locations',
                      child: Row(children: [
                        Icon(Icons.bookmark),
                        SizedBox(width: 8),
                        Text('Saved Places')
                      ])),
                  const PopupMenuItem(
                      value: '/rides/emergency-contacts',
                      child: Row(children: [
                        Icon(Icons.contact_phone),
                        SizedBox(width: 8),
                        Text('Emergency Contacts')
                      ])),
                  const PopupMenuItem(
                      value: '/rides/driver/earnings',
                      child: Row(children: [
                        Icon(Icons.payments),
                        SizedBox(width: 8),
                        Text('Driver Earnings')
                      ])),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map fills the entire screen behind the bottom sheet
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, _) {
                // Fetch nearby drivers for map markers
                List<LatLng>? driverMarkers;
                if (_pickupLocation != null) {
                  final driversAsync = ref.watch(nearbyDriversProvider(
                      (lat: _pickupLocation!.latitude,
                      lng: _pickupLocation!.longitude)));
                  driverMarkers = driversAsync.maybeWhen(
                    data: (drivers) => drivers
                        .whereType<Map<String, dynamic>>()
                        .map((d) {
                          final lat = (d['latitude'] as num?)?.toDouble() ??
                              (d['lat'] as num?)?.toDouble();
                          final lng = (d['longitude'] as num?)?.toDouble() ??
                              (d['lng'] as num?)?.toDouble();
                          if (lat == null || lng == null) return null;
                          return LatLng(lat, lng);
                        })
                        .whereType<LatLng>()
                        .toList(),
                    orElse: () => null,
                  );
                }
                return RideMap(
                  pickup: _pickupLocation ?? _defaultCenter,
                  dropoff: _dropoffLocation ?? _pickupLocation ?? _defaultCenter,
                  userLocation: _pickupLocation,
                  routePoints: hasRoute
                      ? ref
                          .watch(routeProvider(
                              (start: _pickupLocation!, end: _dropoffLocation!)))
                          .valueOrNull
                          ?.points
                      : null,
                  nearbyDrivers: driverMarkers,
                  zoom: 14.0,
                  onMapTap: _onMapTap,
                  fitRoute: hasRoute,
                );
              },
            ),
          ),

          // Floating selection mode indicator — positioned safely below AppBar
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: MapSelectionModeIndicator(
                  isSelectingPickup: _selectingPickup,
                  canToggle: _dropoffLocation != null,
                  onToggle: () =>
                      setState(() => _selectingPickup = !_selectingPickup),
                ),
              ),
            ),
          ),

          // My-location FAB — positioned above the collapsed sheet
          Positioned(
            right: 16,
            bottom: screenHeight * 0.42 + 12,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              child: FloatingActionButton.small(
                onPressed: _locating ? null : _autoLocate,
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: AppTheme.emerald,
                child: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ),

          // Draggable bottom sheet — Uber/Swiggy style
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.4)
                          : const Color(0x1A000000),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Address fields in a connected card
                            _buildAddressCard(),

                            // Inline error pill
                            if (_inlineError != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, size: 16, color: AppTheme.danger),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _inlineError!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.danger,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _inlineError = null),
                                      child: Icon(Icons.close, size: 16, color: AppTheme.danger),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (hasRoute)
                              Consumer(
                                builder: (context, ref, _) {
                                  final routeAsync = ref.watch(routeProvider(
                                      (start: _pickupLocation!,
                                      end: _dropoffLocation!)));
                                  return routeAsync.when(
                                    loading: () => _buildRouteLoading(),
                                    error: (_, _) => const SizedBox.shrink(),
                                    data: (route) {
                                      if (route == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration: const Duration(
                                            milliseconds: 300),
                                        builder: (context, value, child) {
                                          return Opacity(opacity: value, child: child);
                                        },
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 12),
                                            RouteInfoBar(
                                              distanceKm: route.distanceKm,
                                              durationMin: route.durationMin,
                                            ),
                                            const SizedBox(height: 16),
                                            const Text('Select Vehicle',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            const SizedBox(height: 10),
                                            VehicleSelector(
                                              vehicles: _vehicles,
                                              selectedIndex: _selectedVehicle,
                                              fares: List.generate(
                                                  _vehicles.length, (i) {
                                                return _calculateFare(
                                                    i,
                                                    route.distanceKm,
                                                    route.durationMin);
                                              }),
                                              etas: List.generate(
                                                  _vehicles.length, (i) {
                                                return _estimateEta(i);
                                              }),
                                              onSelected: (i) => setState(
                                                  () => _selectedVehicle = i),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),

                            const SizedBox(height: 16),
                            const Text('Payment Method',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            PaymentMethodSelector(
                              methods: _paymentMethods,
                              selectedIndex: _selectedPayment,
                              onSelected: (i) =>
                                  setState(() => _selectedPayment = i),
                            ),

                            const SizedBox(height: 16),
                            // Nearby drivers
                            if (_pickupLocation != null)
                              Consumer(
                                builder: (context, ref, _) {
                                  final driversAsync = ref.watch(
                                      nearbyDriversProvider(
                                          (lat: _pickupLocation!.latitude,
                                          lng: _pickupLocation!.longitude)));
                                  return driversAsync.when(
                                    loading: () => const SizedBox(
                                        height: 40,
                                        child: Center(
                                            child:
                                                LinearProgressIndicator())),
                                    error: (_, _) =>
                                        const SizedBox.shrink(),
                                    data: (drivers) =>
                                        NearbyDriversSection(drivers: drivers),
                                  );
                                },
                              ),

                            if (_rideResult != null) ...[
                              const SizedBox(height: 16),
                              RideResultCard(
                                result: _rideResult!,
                                onTrack: () => context.push(
                                    '/rides/${_rideResult!['rideId']}'),
                              ),
                            ],

                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                  ),
                                ),
                                onPressed:
                                    _loading || !hasRoute ? null : () { AppHaptics.light(); _requestRide(); },
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (hasRoute) ...[
                                            const Icon(Icons.local_taxi,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                                'Request ${_vehicles[_selectedVehicle].$1} \u2022 \u20B9${_calculateFare(_selectedVehicle, ref.read(routeProvider((start: _pickupLocation!, end: _dropoffLocation!))).valueOrNull?.distanceKm ?? 0, ref.read(routeProvider((start: _pickupLocation!, end: _dropoffLocation!))).valueOrNull?.durationMin ?? 0).toInt()}',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ] else
                                            const Text(
                                                'Set pickup & dropoff'),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openDropoffSearchOverlay() async {
    AppHaptics.light();
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const _DropoffSearchOverlay(),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _dropoffLocation = result['location'] as LatLng;
        _dropoffAddress = result['address'] as String;
        _selectingPickup = false;
      });
    }
  }

  Widget _buildAddressCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pickup
          _AddressRow(
            icon: Icons.radio_button_checked,
            iconColor: AppTheme.emerald,
            label: 'Pickup',
            initialText: _pickupAddress,
            initialLocation: _pickupLocation,
            onSelected: (address, location) => setState(() {
              _pickupLocation = location;
              _pickupAddress = address;
            }),
          ),
          // Divider with connecting line
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Container(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
          // Dropoff
          _AddressRow(
            icon: Icons.location_on,
            iconColor: AppTheme.danger,
            label: 'Dropoff',
            onSelected: (address, location) => setState(() {
              _dropoffLocation = location;
              _dropoffAddress = address;
            }),
            onSearchTap: () => _openDropoffSearchOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteLoading() {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Future<void> _requestRide() async {
    // Fat-finger guard: compute straight-line distance before requesting.
    // If the dropoff is more than 50km away for local bikes/autos, block the
    // request to prevent accidental ₹10,000+ fares. Intercity cabs (index 2)
    // are allowed longer distances.
    if (_pickupLocation != null && _dropoffLocation != null) {
      const distance = Distance();
      final straightLineKm = distance.as(
        LengthUnit.Kilometer,
        _pickupLocation!,
        _dropoffLocation!,
      );
      const maxLocalDistanceKm = 50.0;
      final isLocalVehicle = _selectedVehicle < 2; // Bike (0) or Auto (1)
      if (isLocalVehicle && straightLineKm > maxLocalDistanceKm) {
        AppHaptics.error();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Dropoff location is outside our local service area. Please select an Intercity Cab for longer distances.'),
              backgroundColor: AppTheme.danger,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    final route = ref
        .read(routeProvider((start: _pickupLocation!, end: _dropoffLocation!)))
        .valueOrNull;
    if (route == null) return;

    // Check auth — if not signed in, show QuickAuthSheet before proceeding
    final isAuthed = ref.read(authTokenProvider)?.isNotEmpty ?? false;
    if (!isAuthed) {
      final authenticated = await QuickAuthSheet.show(
        context,
        ref,
        title: 'Sign in to book a ride',
      );
      if (authenticated != true || !mounted) return;
    }

    final fare = _calculateFare(_selectedVehicle, route.distanceKm, route.durationMin);
    final vehicleName = _vehicles[_selectedVehicle].$1;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RideConfirmSheet(
        vehicleName: vehicleName,
        fare: fare,
        distanceKm: route.distanceKm,
        durationMin: route.durationMin,
        pickupAddress: _pickupAddress,
        dropoffAddress: _dropoffAddress,
        paymentMethod: _paymentMethods[_selectedPayment],
      ),
    );

    if (confirmed != true || !mounted) return;

    AppHaptics.medium();
    setState(() => _loading = true);
    try {
      final api = ref.read(ridesApiProvider);
      final result = await api.requestRide({
        'pickupLatitude': _pickupLocation!.latitude,
        'pickupLongitude': _pickupLocation!.longitude,
        'pickupAddress': _pickupAddress,
        'dropoffLatitude': _dropoffLocation!.latitude,
        'dropoffLongitude': _dropoffLocation!.longitude,
        'dropoffAddress': _dropoffAddress,
        'distanceKm': route.distanceKm,
        'vehicleType': _selectedVehicle + 1,
        'paymentMethod': _selectedPayment + 1,
      });
      setState(() => _rideResult = result);
    } on AuthRequiredException {
      if (mounted) {
        setState(() => _inlineError = 'Please sign in to book a ride.');
      }
    } on WaiverRequiredException {
      if (mounted) {
        final accepted = await WaiverSheet.show(context);
        if (accepted == true && mounted) {
          _requestRide(); // Retry after waiver acceptance
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _inlineError = e.message.isNotEmpty ? e.message : 'Could not request ride. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = 'Could not request ride. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// Swiggy-style ride confirmation bottom sheet with rounded top border.
/// Shows ride summary before confirming.
class _RideConfirmSheet extends StatelessWidget {
  const _RideConfirmSheet({
    required this.vehicleName,
    required this.fare,
    required this.distanceKm,
    required this.durationMin,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.paymentMethod,
  });

  final String vehicleName;
  final double fare;
  final double distanceKm;
  final int durationMin;
  final String pickupAddress;
  final String dropoffAddress;
  final String paymentMethod;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Text('Confirm Ride', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(vehicleName,
                        style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Route summary
              _RouteRow(icon: Icons.radio_button_checked, color: AppTheme.emerald, label: 'Pickup', address: pickupAddress),
              Padding(
                padding: const EdgeInsets.only(left: 11),
                child: Container(
                  height: 24,
                  width: 2,
                  color: Theme.of(context).dividerColor,
                ),
              ),
              _RouteRow(icon: Icons.location_on, color: AppTheme.danger, label: 'Dropoff', address: dropoffAddress),
              const SizedBox(height: 16),
              // Trip stats
              Row(
                children: [
                  _StatChip(icon: Icons.route, label: '${distanceKm.toStringAsFixed(1)} km'),
                  const SizedBox(width: 12),
                  _StatChip(icon: Icons.access_time, label: '~$durationMin min'),
                  const SizedBox(width: 12),
                  _StatChip(icon: Icons.payments_outlined, label: paymentMethod),
                ],
              ),
              const Divider(height: 24),
              // Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Fare', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('\u20B9${fare.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 20),
              // Confirm button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.icon, required this.color, required this.label, required this.address});
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Compact address row used inside the connected address card.
class _AddressRow extends ConsumerStatefulWidget {
  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onSelected,
    this.initialText,
    this.initialLocation,
    this.onSearchTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final void Function(String address, LatLng location) onSelected;
  final String? initialText;
  final LatLng? initialLocation;
  final VoidCallback? onSearchTap;

  @override
  ConsumerState<_AddressRow> createState() => _AddressRowState();
}

class _AddressRowState extends ConsumerState<_AddressRow> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<dynamic> _suggestions = [];
  bool _loading = false;
  bool _showSuggestions = false;
  String? _selectedDisplayName;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText ?? '';
    _selectedDisplayName = widget.initialText;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      } else if (_controller.text.isNotEmpty &&
          _controller.text != _selectedDisplayName) {
        setState(() => _showSuggestions = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value == _selectedDisplayName) return;
    setState(() {
      _showSuggestions = true;
      _selectedDisplayName = null;
    });
    _debouncedSearch(value);
  }

  DateTime? _lastSearchTime;
  void _debouncedSearch(String query) {
    _lastSearchTime = DateTime.now();
    final searchTime = _lastSearchTime!;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (searchTime == _lastSearchTime && query.trim().length >= 3) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _loading = true);
    try {
      final service = ref.read(geocodingProvider);
      final results = await service.search(query, countryCodes: ['in'], limit: 5);
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectSuggestion(dynamic result) {
    final displayName = result.displayName as String;
    final location = result.location as LatLng;
    _controller.text = displayName;
    _selectedDisplayName = displayName;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    widget.onSelected(displayName, location);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: 'Search address...',
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixIcon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {
                                    _suggestions = [];
                                    _selectedDisplayName = null;
                                  });
                                },
                              )
                            : null,
                  ),
                  onChanged: _onChanged,
                ),
              ),
            ],
          ),
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(left: 34, top: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final result = _suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.location_on,
                          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      title: Text(
                        result.displayName as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () => _selectSuggestion(result),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating circular map action button with a frosted glass or solid surface look.
class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppTheme.darkCard : AppTheme.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
      ),
    );
  }
}

/// Icon-only variant used as the `icon` of a [PopupMenuButton].
class _MapActionButtonIcon extends StatelessWidget {
  const _MapActionButtonIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 22,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
      ),
    );
  }
}

/// Full-screen search overlay for selecting a dropoff location.
/// Shows autocomplete search results, saved places, and recent locations.
class _DropoffSearchOverlay extends ConsumerStatefulWidget {
  const _DropoffSearchOverlay();

  @override
  ConsumerState<_DropoffSearchOverlay> createState() => _DropoffSearchOverlayState();
}

class _DropoffSearchOverlayState extends ConsumerState<_DropoffSearchOverlay> {
  final _searchController = TextEditingController();
  List<GeocodingResult> _results = [];
  bool _isSearching = false;
  Timer? _debounce;
  List<Map<String, dynamic>> _recentLocations = [];
  static const _recentKey = 'recent_dropoff_locations';

  @override
  void initState() {
    super.initState();
    _loadRecentLocations();
  }

  Future<void> _loadRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        if (mounted) {
          setState(() => _recentLocations = list.cast<Map<String, dynamic>>());
        }
      } catch (_) {}
    }
  }

  Future<void> _saveRecentLocation(LatLng location, String address) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': address,
      'savedAt': DateTime.now().toIso8601String(),
    };
    // Remove duplicates by address, prepend, cap at 5
    _recentLocations.removeWhere((e) => e['address'] == address);
    _recentLocations.insert(0, entry);
    if (_recentLocations.length > 5) {
      _recentLocations = _recentLocations.sublist(0, 5);
    }
    await prefs.setString(_recentKey, jsonEncode(_recentLocations));
  }

  void _selectRecentLocation(Map<String, dynamic> loc) {
    AppHaptics.light();
    final lat = (loc['latitude'] as num?)?.toDouble() ?? 11.9356;
    final lng = (loc['longitude'] as num?)?.toDouble() ?? 79.8301;
    final address = loc['address'] as String? ?? 'Recent location';
    Navigator.of(context).pop({
      'location': LatLng(lat, lng),
      'address': address,
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final geocoding = ref.read(geocodingProvider);
        final results = await geocoding.search(
          query,
          countryCodes: const ['in'],
          limit: 8,
        );
        if (mounted) {
          setState(() {
            _results = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not search addresses'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _selectResult(GeocodingResult result) {
    AppHaptics.light();
    _saveRecentLocation(result.location, result.displayName);
    Navigator.of(context).pop({
      'location': result.location,
      'address': result.displayName,
    });
  }

  void _selectSavedLocation(dynamic loc) {
    AppHaptics.light();
    final lat = (loc['latitude'] as num?)?.toDouble() ?? 11.9356;
    final lng = (loc['longitude'] as num?)?.toDouble() ?? 79.8301;
    final address = loc['address'] as String? ?? loc['label'] as String? ?? 'Saved location';
    _saveRecentLocation(LatLng(lat, lng), address);
    Navigator.of(context).pop({
      'location': LatLng(lat, lng),
      'address': address,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final savedLocationsAsync = ref.watch(savedLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Where to?',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: Column(
        children: [
          // Search results
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final r = _results[index];
                  return ListTile(
                    leading: Icon(Icons.location_on, color: AppTheme.emerald, size: 22),
                    title: Text(r.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectResult(r),
                  );
                },
              ),
            )
          else ...[
            // Saved places section
            savedLocationsAsync.when(
              data: (locations) {
                if (locations.isEmpty) return const SizedBox.shrink();
                return Expanded(
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'SAVED PLACES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                          ),
                        ),
                      ),
                      ...locations.map((loc) => ListTile(
                            leading: Icon(Icons.bookmark, color: AppTheme.emerald, size: 22),
                            title: Text(loc['label'] as String? ?? 'Saved place'),
                            subtitle: Text(
                              loc['address'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSavedLocation(loc),
                          )),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            // Recent locations (shown when no active search results)
            if (_results.isEmpty && _recentLocations.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'Recent Locations',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ..._recentLocations.map((loc) => ListTile(
                    leading: Icon(Icons.history, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
                    title: Text(
                      loc['address'] as String? ?? 'Recent location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectRecentLocation(loc),
                  )),
            ],
            // Empty state placeholder (only when no recents and no saved places)
            if (_results.isEmpty &&
                _recentLocations.isEmpty &&
                savedLocationsAsync.maybeWhen(data: (l) => l.isEmpty, orElse: () => false))
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'Search for a destination',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try "Rock Beach", "Auroville", or "White Town"',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

