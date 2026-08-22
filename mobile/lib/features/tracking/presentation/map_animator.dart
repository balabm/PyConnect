import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// A reusable map animation utility that provides smooth marker
/// interpolation and bearing rotation for live vehicle tracking.
///
/// Unlike the existing `AnimatedVehicleMarker` which uses a 3-second
/// glide, this animator uses an 800ms duration for tighter, more
/// responsive Uber-grade movement.
///
/// Usage:
/// ```dart
/// MapAnimator(
///   start: oldGpsPoint,
///   end: newGpsPoint,
///   onPositionUpdate: (latlng) => updateMarker(latlng),
///   child: VehicleIcon(),
/// )
/// ```
class MapAnimator extends StatefulWidget {
  const MapAnimator({
    super.key,
    required this.start,
    required this.end,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.onPositionUpdate,
    this.rotateChild = true,
  });

  /// The geographic position the vehicle is moving from.
  final LatLng start;

  /// The geographic position the vehicle is moving to.
  final LatLng end;

  /// The widget to display (vehicle icon, etc.).
  final Widget child;

  /// Duration of the glide animation. Default: 800ms.
  final Duration duration;

  /// Curve for the position interpolation. Default: easeInOut.
  final Curve curve;

  /// Called on every animation frame with the interpolated [LatLng].
  final void Function(LatLng position)? onPositionUpdate;

  /// Whether to rotate the child to face the bearing. Default: true.
  final bool rotateChild;

  @override
  State<MapAnimator> createState() => _MapAnimatorState();
}

class _MapAnimatorState extends State<MapAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<LatLng> _position;
  double _targetBearing = 0;
  double _previousBearing = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _setupSegment(resetRotation: true);
    _controller.addListener(_handlePositionTick);
    _controller.forward();
  }

  void _setupSegment({bool resetRotation = false}) {
    _targetBearing = _calculateBearing(widget.start, widget.end);
    if (resetRotation) {
      _previousBearing = _targetBearing;
    }
    _previousBearing = _shortestAngle(_previousBearing, _targetBearing);
    _position = LatLngTween(
      begin: widget.start,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  void _handlePositionTick() {
    widget.onPositionUpdate?.call(_position.value);
  }

  @override
  void didUpdateWidget(MapAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.start != oldWidget.start || widget.end != oldWidget.end) {
      _previousBearing = _targetBearing;
      _setupSegment();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePositionTick);
    _controller.dispose();
    super.dispose();
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLng = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return math.atan2(y, x) * 180 / math.pi;
  }

  double _shortestAngle(double from, double to) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return from + diff;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.rotateChild) return widget.child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _previousBearing, end: _targetBearing),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, angleDegrees, child) {
        return Transform.rotate(
          angle: angleDegrees * math.pi / 180,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A [Tween] that interpolates between two [LatLng] coordinates.
/// Reused from the existing `animated_vehicle_marker.dart` but
/// exported here for broader use across tracking screens.
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    if (t == 0) return begin!;
    if (t == 1) return end!;
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}

/// Utility for calculating the distance between two [LatLng] points
/// in meters, used to determine if the camera should re-frame.
double distanceBetweenMeters(LatLng a, LatLng b) {
  // Haversine formula
  const r = 6371000.0; // Earth radius in meters
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) *
      math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return r * c;
}
