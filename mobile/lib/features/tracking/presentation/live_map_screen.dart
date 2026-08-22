import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_animator.dart';

/// A live tracking map with auto-framing camera that dynamically
/// zooms and pans to keep both the driver's moving car and the
/// drop-off pin centered, accounting for 40% bottom-sheet padding.
///
/// The camera re-frames using [LatLngBounds] and animates with a
/// 1-second [Curves.easeInOut] curve every time the driver moves
/// more than 50 meters.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.driverLocationStream,
    this.routePoints = const [],
    this.bottomSheetHeightFraction = 0.40,
    this.reframeThresholdMeters = 50.0,
    this.tileLayer,
  });

  /// Pickup location pin.
  final LatLng pickup;

  /// Drop-off location pin.
  final LatLng dropoff;

  /// Stream of driver GPS updates (latitude, longitude).
  final Stream<LatLng> driverLocationStream;

  /// Optional route polyline points.
  final List<LatLng> routePoints;

  /// Fraction of screen height reserved for the bottom sheet.
  /// Default: 0.40 (40%).
  final double bottomSheetHeightFraction;

  /// Minimum distance the driver must move before the camera
  /// re-frames. Default: 50 meters.
  final double reframeThresholdMeters;

  /// Optional custom tile layer widget. If null, uses CartoDB Positron.
  final Widget? tileLayer;

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<LatLng>? _driverSub;
  LatLng? _currentDriverLocation;
  LatLng? _previousDriverLocation;
  LatLng? _animatedDriverLocation;

  // Animation state for the driver marker
  LatLng? _animStart;
  LatLng? _animEnd;

  static const _positronTiles =
      'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  static const _darkMatterTiles =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _driverSub = widget.driverLocationStream.listen(_onDriverLocationUpdate);
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onDriverLocationUpdate(LatLng newLocation) {
    if (!mounted) return;

    setState(() {
      _previousDriverLocation = _currentDriverLocation;
      _currentDriverLocation = newLocation;

      // Set up animation segment
      if (_previousDriverLocation != null) {
        _animStart = _animatedDriverLocation ?? _previousDriverLocation!;
        _animEnd = newLocation;
      } else {
        _animStart = newLocation;
        _animEnd = newLocation;
        _animatedDriverLocation = newLocation;
      }
    });

    // Check if we should re-frame the camera
    final lastFramedLocation = _previousDriverLocation;
    if (lastFramedLocation == null ||
        distanceBetweenMeters(lastFramedLocation, newLocation) >
            widget.reframeThresholdMeters) {
      _reframeCamera(newLocation);
    }
  }

  /// Auto-frames the camera to include both the driver and drop-off
  /// pin, with padding for the bottom sheet.
  void _reframeCamera(LatLng driverLocation) {
    final bounds = LatLngBounds.fromPoints([
      driverLocation,
      widget.dropoff,
      if (_animatedDriverLocation != null) _animatedDriverLocation!,
    ]);

    // Calculate padding: 40% bottom sheet + margins
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = screenHeight * widget.bottomSheetHeightFraction;
    final sidePadding = 80.0;

    // Use fitCamera with padding for the bottom sheet
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.fromLTRB(
          sidePadding,
          80,
          sidePadding,
          bottomPadding,
        ),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final markers = <Marker>[
      // Pickup marker
      Marker(
        point: widget.pickup,
        width: 44,
        height: 56,
        child: _buildPinMarker(Colors.teal, 'A'),
      ),
      // Dropoff marker
      if (widget.pickup != widget.dropoff)
        Marker(
          point: widget.dropoff,
          width: 44,
          height: 56,
          child: _buildPinMarker(Colors.red, 'B'),
        ),
      // Driver marker with smooth animation
      if (_currentDriverLocation != null &&
          _animStart != null &&
          _animEnd != null)
        Marker(
          point: _animatedDriverLocation ?? _currentDriverLocation!,
          width: 44,
          height: 44,
          child: MapAnimator(
            key: ValueKey(
                '${_animStart!.latitude},${_animStart!.longitude}'
                '->${_animEnd!.latitude},${_animEnd!.longitude}'),
            start: _animStart!,
            end: _animEnd!,
            onPositionUpdate: (latlng) {
              if (mounted) setState(() => _animatedDriverLocation = latlng);
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D290), Color(0xFF10E3A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00D290).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.two_wheeler,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.pickup,
        initialZoom: 14.0,
        keepAlive: true,
      ),
      children: [
        // Tile layer
        widget.tileLayer ??
            TileLayer(
              urlTemplate: isDark ? _darkMatterTiles : _positronTiles,
              userAgentPackageName: 'com.pondyconnect.app',
              retinaMode: true,
            ),
        // Route polyline
        if (widget.routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                color: const Color(0xFF00D290),
                strokeWidth: 4,
              ),
            ],
          ),
        // Markers
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildPinMarker(Color color, String label) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
