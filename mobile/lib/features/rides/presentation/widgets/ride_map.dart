import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/nearby_driver.dart';
import 'animated_vehicle_marker.dart';

/// CartoDB Positron (light) and Dark Matter (dark) tiles per MasterPlan spec.
/// Falls back to OSM standard tiles if CartoDB is unavailable.
const _positronTiles = 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
const _darkMatterTiles = 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Active trip polyline color — bright teal for high contrast on dark map.
const _activeRouteColor = Color(0xFF00E676);
const _activeRouteGlowColor = Color(0x3300E676);

/// User location puck color — glowing blue/teal.
const _userPuckColor = Color(0xFF00B4D8);
const _userPuckGlowColor = Color(0x3300B4D8);

/// Interactive map widget for ride tracking. Shows pickup/dropoff pins,
/// optional route polyline, and a live driver marker that updates in real-time.
/// Uses a premium dark vector tile style for an Uber-style aesthetic.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.driverLocation,
    this.userLocation,
    this.routePoints,
    this.driverRoutePoints,
    this.nearbyDrivers,
    this.zoom = 14.0,
    this.onMapTap,
    this.fitRoute = false,
    this.focusLocation,
    this.focusNonce = 0,
    this.focusZoom = 16.5,
  });

  final LatLng pickup;
  final LatLng dropoff;
  final LatLng? driverLocation;
  final LatLng? userLocation;
  final List<LatLng>? routePoints;
  /// Route from the driver's current location to the pickup point.
  /// Rendered as a dashed muted-color line distinct from the main route.
  final List<LatLng>? driverRoutePoints;
  /// Nearby driver locations to show as markers on the map.
  final List<NearbyDriver>? nearbyDrivers;
  final double zoom;
  final void Function(LatLng)? onMapTap;
  final bool fitRoute;

  /// When [focusNonce] changes, the map camera animates to this location at
  /// [focusZoom]. Used to smoothly frame the user's GPS fix after locate.
  final LatLng? focusLocation;

  /// Monotonically-increasing counter; a change triggers an animated camera
  /// move to [focusLocation]. Bumping the nonce re-triggers the animation even
  /// when the target location is unchanged.
  final int focusNonce;

  final double focusZoom;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  bool _hasFitRoute = false;

  /// Lightweight animated-camera controller. Drives a per-frame
  /// [_mapController.move] call to ease from the current center/zoom to the
  /// target focus location, avoiding a new dependency on
  /// `flutter_map_animations`.
  AnimationController? _focusAnim;
  LatLng? _focusFrom;
  LatLng? _focusTo;
  double _focusFromZoom = 14.0;
  double _focusToZoom = 16.5;
  int _lastFocusNonce = -1;

  /// The geographic position the driver marker is currently displayed at.
  /// This is updated every animation frame by [AnimatedVehicleMarker] so the
  /// marker glides smoothly from the previous GPS fix to the new one.
  LatLng? _animatedDriverLocation;

  /// The start (previous) and end (new) positions for the current glide
  /// segment. When a new driver location arrives, [_animStart] is set to the
  /// currently displayed position and [_animEnd] to the new fix.
  LatLng? _animStart;
  LatLng? _animEnd;

  /// Currently-displayed (animated) positions of nearby drivers, keyed by
  /// driver id. Updated each animation frame by each driver's
  /// [AnimatedVehicleMarker] so the marker glides between polling refreshes.
  final Map<String, LatLng> _nearbyAnimatedPositions = {};

  /// The previous fix per nearby driver, used as the glide start point when a
  /// new polling refresh arrives.
  final Map<String, LatLng> _nearbyPreviousPositions = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Seed the animated position with the initial driver location (if any) so
    // the first fix doesn't animate from nowhere.
    _animatedDriverLocation = widget.driverLocation;
    _animStart = widget.driverLocation;
    _animEnd = widget.driverLocation;
    _seedNearbyPositions();
  }

  /// Seeds the animated/previous position maps for any newly-arrived nearby
  /// drivers so their first frame is placed at the reported fix (no glide
  /// from origin).
  void _seedNearbyPositions() {
    if (widget.nearbyDrivers == null) return;
    for (final d in widget.nearbyDrivers!) {
      _nearbyAnimatedPositions.putIfAbsent(d.id, () => d.location);
      _nearbyPreviousPositions.putIfAbsent(d.id, () => d.location);
    }
  }

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When a new driver location arrives, begin a new glide segment from the
    // currently displayed position to the new fix. The [AnimatedVehicleMarker]
    // (keyed by this segment) drives [_animatedDriverLocation] via callback.
    if (widget.driverLocation != null &&
        widget.driverLocation != oldWidget.driverLocation) {
      if (_animatedDriverLocation == null) {
        // First fix — no animation, just place the marker.
        _animatedDriverLocation = widget.driverLocation;
        _animStart = widget.driverLocation;
        _animEnd = widget.driverLocation;
      } else {
        _animStart = _animatedDriverLocation;
        _animEnd = widget.driverLocation;
      }
    }

    if (widget.fitRoute && !_hasFitRoute && widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      _fitBounds();
      _hasFitRoute = true;
    }
    if (widget.driverLocation != null && widget.driverLocation != oldWidget.driverLocation && !widget.fitRoute) {
      _mapController.move(widget.driverLocation!, widget.zoom);
    }
    // Reset fit flag when route changes
    if (widget.routePoints != oldWidget.routePoints) {
      _hasFitRoute = false;
    }

    // For nearby drivers: when a new polling refresh arrives, record the
    // currently displayed position as the glide start point. The
    // [AnimatedVehicleMarker] (keyed by id+segment) will animate from that
    // start to the new fix and update [_nearbyAnimatedPositions] each frame
    // via its callback. For first appearances, seed both maps to the fix so
    // the marker is placed without animating from origin.
    if (widget.nearbyDrivers != null) {
      for (final d in widget.nearbyDrivers!) {
        if (!_nearbyAnimatedPositions.containsKey(d.id)) {
          _nearbyAnimatedPositions[d.id] = d.location;
          _nearbyPreviousPositions[d.id] = d.location;
        } else {
          _nearbyPreviousPositions[d.id] = _nearbyAnimatedPositions[d.id]!;
        }
      }
    }

    // Animated camera framing: when the focus nonce changes, ease the map
    // center/zoom to the requested focus location.
    if (widget.focusLocation != null &&
        widget.focusNonce != _lastFocusNonce) {
      _lastFocusNonce = widget.focusNonce;
      _animateCameraTo(widget.focusLocation!, widget.focusZoom);
    }
  }

  /// Eases the map camera from its current center/zoom to [target] at
  /// [targetZoom] over ~700ms using a per-frame [MapController.move] call.
  /// This avoids adding the `flutter_map_animations` dependency.
  void _animateCameraTo(LatLng target, double targetZoom) {
    _focusAnim?.dispose();
    final currentCenter = _mapController.camera.center;
    _focusFrom = currentCenter;
    _focusTo = target;
    _focusFromZoom = _mapController.camera.zoom;
    _focusToZoom = targetZoom;
    _focusAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_focusAnim!.value);
        final lat =
            _focusFrom!.latitude + (_focusTo!.latitude - _focusFrom!.latitude) * t;
        final lng = _focusFrom!.longitude +
            (_focusTo!.longitude - _focusFrom!.longitude) * t;
        final z = _focusFromZoom + (_focusToZoom - _focusFromZoom) * t;
        _mapController.move(LatLng(lat, lng), z);
      })
      ..forward();
  }

  @override
  void dispose() {
    _focusAnim?.dispose();
    super.dispose();
  }

  void _fitBounds() {
    final points = <LatLng>[widget.pickup, widget.dropoff];
    if (widget.routePoints != null) points.addAll(widget.routePoints!);
    if (widget.driverRoutePoints != null) points.addAll(widget.driverRoutePoints!);
    if (widget.driverLocation != null) points.add(widget.driverLocation!);

    final latitudes = points.map((p) => p.latitude).toList();
    final longitudes = points.map((p) => p.longitude).toList();
    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLng = longitudes.reduce((a, b) => a < b ? a : b);
    final maxLng = longitudes.reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      // User location puck — glowing blue/teal dot (Uber-style)
      if (widget.userLocation != null)
        Marker(
          point: widget.userLocation!,
          width: 50,
          height: 50,
          child: const _UserPuck(),
        ),
      // Pickup marker — teardrop pin with lagoon color
      Marker(
        point: widget.pickup,
        width: 44,
        height: 56,
        child: _PinMarker(
          color: AppTheme.emerald,
          icon: Icons.radio_button_checked,
          label: 'A',
        ),
      ),
      // Dropoff marker — only if different from pickup
      if (widget.pickup != widget.dropoff)
        Marker(
          point: widget.dropoff,
          width: 44,
          height: 56,
          child: _PinMarker(
            color: AppTheme.danger,
            icon: Icons.location_on,
            label: 'B',
          ),
        ),
      // Driver marker — glides smoothly between GPS fixes and rotates to
      // face the direction of travel. The marker point is the animated
      // position; the child widget drives that position via callback.
      if (widget.driverLocation != null &&
          _animatedDriverLocation != null &&
          _animStart != null &&
          _animEnd != null)
        Marker(
          point: _animatedDriverLocation!,
          width: 44,
          height: 44,
          child: AnimatedVehicleMarker(
            // Keying by the segment ensures the animation restarts whenever a
            // new GPS fix arrives, while persisting across the per-frame
            // rebuilds triggered by the position callback.
            key: ValueKey('${_animStart!.latitude},${_animStart!.longitude}'
                '->${_animEnd!.latitude},${_animEnd!.longitude}'),
            startLatLng: _animStart!,
            endLatLng: _animEnd!,
            icon: Icons.directions_car,
            onPositionUpdate: (latlng) {
              if (mounted) setState(() => _animatedDriverLocation = latlng);
            },
          ),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.pickup,
        initialZoom: widget.zoom,
        onTap: (tapPosition, point) => widget.onMapTap?.call(point),
        // No compass, no zoom controls — clean Uber-style look
        keepAlive: true,
      ),
      children: [
        // Tile layer — CartoDB Positron (light) / Dark Matter (dark) per MasterPlan.
        // Wrapped in a Builder so it rebuilds reactively on theme changes.
        Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return TileLayer(
              urlTemplate: isDark ? _darkMatterTiles : _positronTiles,
              userAgentPackageName: 'com.pondyconnect.app',
              retinaMode: true,
            );
          },
        ),
        // Driver → Pickup polyline — dashed muted line (slate/grey)
        if (widget.driverRoutePoints != null &&
            widget.driverRoutePoints!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.driverRoutePoints!,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                strokeWidth: 4,
                pattern: StrokePattern.dashed(
                  segments: const [8, 8],
                ),
                strokeCap: StrokeCap.round,
              ),
            ],
          ),
        // Route polyline — glow effect + bright teal line
        if (widget.routePoints != null && widget.routePoints!.isNotEmpty) ...[
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints!,
                color: _activeRouteGlowColor,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
              ),
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints!,
                color: _activeRouteColor,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
              ),
            ],
          ),
        ],
        // Nearby driver markers — one animated, vehicle-type-specific marker
        // per driver. Each marker glides from its previous fix to the new one
        // and rotates to face the direction of travel.
        if (widget.nearbyDrivers != null && widget.nearbyDrivers!.isNotEmpty)
          MarkerLayer(
            markers: widget.nearbyDrivers!
                .map((d) {
                    final start = _nearbyPreviousPositions[d.id] ?? d.location;
                    final end = d.location;
                    final point = _nearbyAnimatedPositions[d.id] ?? d.location;
                    return Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: AnimatedVehicleMarker(
                        key: ValueKey(
                            'nearby-${d.id}-${start.latitude},${start.longitude}->${end.latitude},${end.longitude}'),
                        startLatLng: start,
                        endLatLng: end,
                        icon: d.icon,
                        size: 20.0,
                        onPositionUpdate: (latlng) {
                          if (mounted) {
                            setState(() {
                              _nearbyAnimatedPositions[d.id] = latlng;
                            });
                          }
                        },
                      ),
                    );
                  })
                .toList(),
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

/// Custom teardrop pin marker with label.
class _PinMarker extends StatelessWidget {
  const _PinMarker({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Pin body
        Positioned(
          top: 0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        // Pin tip
        Positioned(
          top: 30,
          left: 0,
          child: CustomPaint(
            size: const Size(36, 16),
            painter: _PinTipPainter(color: color),
          ),
        ),
      ],
    );
  }
}

/// Draws the triangular tip below the pin circle.
class _PinTipPainter extends CustomPainter {
  _PinTipPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.75, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTipPainter oldDelegate) => color != oldDelegate.color;
}

/// Glowing user location puck — Uber-style blue/teal dot with pulsing glow.
/// Uses an animated outer ring that breathes to indicate active location.
class _UserPuck extends StatefulWidget {
  const _UserPuck();

  @override
  State<_UserPuck> createState() => _UserPuckState();
}

class _UserPuckState extends State<_UserPuck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        // Scale from 1x to 2x and fade opacity from 0.4 to 0
        final scale = 1.0 + _pulse.value; // 1.0 → 2.0
        final opacity = 0.4 * (1.0 - _pulse.value); // 0.4 → 0.0
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring — same color as the user puck
            Transform.scale(
              scale: scale,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _userPuckColor.withValues(alpha: opacity),
                ),
              ),
            ),
            // Inner solid dot
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _userPuckColor,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _userPuckColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
