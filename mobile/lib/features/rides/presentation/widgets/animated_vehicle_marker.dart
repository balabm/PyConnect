import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';

/// A [Tween] that interpolates between two [LatLng] coordinates by linearly
/// lerping their latitude and longitude components.
///
/// This is used to glide a map marker smoothly from one geographic point to
/// another instead of teleporting instantly when a new GPS fix arrives.
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

/// A vehicle marker that glides smoothly from [startLatLng] to [endLatLng]
/// over ~3 seconds with an ease-in-out curve, and rotates to face the
/// direction of travel (bearing).
///
/// The position interpolation is driven by an [AnimationController] whose
/// listener reports the current interpolated [LatLng] via [onPositionUpdate]
/// so the parent (which owns the flutter_map [Marker] point) can rebuild the
/// marker at the correct geographic location each frame.
///
/// The bearing rotation is eased independently via [TweenAnimationBuilder]
/// so the icon smoothly rotates from its previous heading to the new one
/// rather than snapping abruptly.
class AnimatedVehicleMarker extends StatefulWidget {
  const AnimatedVehicleMarker({
    super.key,
    required this.startLatLng,
    required this.endLatLng,
    this.icon = Icons.directions_car,
    this.size = 22.0,
    this.onPositionUpdate,
  });

  /// The geographic position the vehicle is moving from.
  final LatLng startLatLng;

  /// The geographic position the vehicle is moving to.
  final LatLng endLatLng;

  /// The vehicle icon to display (rotated to face the bearing).
  final IconData icon;

  /// Size of the vehicle icon.
  final double size;

  /// Called on every animation frame with the current interpolated [LatLng].
  /// The parent uses this to update the flutter_map marker's [Marker.point]
  /// so the marker glides across the map.
  final void Function(LatLng position)? onPositionUpdate;

  @override
  State<AnimatedVehicleMarker> createState() => _AnimatedVehicleMarkerState();
}

class _AnimatedVehicleMarkerState extends State<AnimatedVehicleMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<LatLng> _position;

  /// Bearing (in degrees, 0 = north) for the current segment.
  double _targetBearing = 0;

  /// Bearing the icon was showing before this segment started, so the
  /// rotation eases from the old heading to the new one.
  double _previousBearing = 0;

  /// Duration of the glide between two GPS fixes.
  static const _glideDuration = Duration(seconds: 3);

  /// Duration of the heading rotation ease.
  static const _rotateDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _glideDuration,
    );
    _setupSegment(resetRotation: true);
    _controller.addListener(_handlePositionTick);
    _controller.forward();
  }

  void _setupSegment({bool resetRotation = false}) {
    _targetBearing = _calculateBearing(widget.startLatLng, widget.endLatLng);
    if (resetRotation) {
      _previousBearing = _targetBearing;
    }
    // Normalize the angular difference to the shortest rotational path so the
    // icon never spins more than 180° to reach the new heading.
    _previousBearing = _shortestAngle(_previousBearing, _targetBearing);

    _position = LatLngTween(
      begin: widget.startLatLng,
      end: widget.endLatLng,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  /// Reports the interpolated position to the parent so the marker point can
  /// be updated. Runs via the controller listener (outside build), so it is
  /// safe for the parent to call setState here.
  void _handlePositionTick() {
    widget.onPositionUpdate?.call(_position.value);
  }

  @override
  void didUpdateWidget(covariant AnimatedVehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startLatLng != oldWidget.startLatLng ||
        widget.endLatLng != oldWidget.endLatLng) {
      // Carry over the current heading as the rotation start point so the icon
      // eases from where it was pointing to the new bearing.
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

  /// Calculates the initial bearing (forward azimuth) in degrees from
  /// [start] to [end] using the great-circle bearing formula.
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLng = (end.longitude - start.longitude) * pi / 180;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return atan2(y, x) * 180 / pi;
  }

  /// Returns [from] adjusted so the rotation from [from] to [to] takes the
  /// shortest angular path (<= 180°).
  double _shortestAngle(double from, double to) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return from + diff;
  }

  @override
  Widget build(BuildContext context) {
    // Ease the heading rotation from the previous bearing to the target so
    // the icon turns smoothly instead of snapping when direction changes.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _previousBearing, end: _targetBearing),
      duration: _rotateDuration,
      curve: Curves.easeInOut,
      builder: (context, angleDegrees, child) {
        return Transform.rotate(
          angle: angleDegrees * pi / 180,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.emerald, AppTheme.emeraldLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: widget.size),
      ),
    );
  }
}
