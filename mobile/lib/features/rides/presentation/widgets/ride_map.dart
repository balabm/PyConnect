import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';

/// Fallback CartoDB Dark Matter raster tiles (free, no API key).
/// Gives a premium Uber-style muted-slate dark map aesthetic.
const _fallbackDarkRaster =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const _fallbackSubdomains = ['a', 'b', 'c', 'd'];

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
    this.zoom = 14.0,
    this.onMapTap,
    this.fitRoute = false,
  });

  final LatLng pickup;
  final LatLng dropoff;
  final LatLng? driverLocation;
  final LatLng? userLocation;
  final List<LatLng>? routePoints;
  final double zoom;
  final void Function(LatLng)? onMapTap;
  final bool fitRoute;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  late final MapController _mapController;
  bool _hasFitRoute = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
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
  }

  void _fitBounds() {
    final points = <LatLng>[widget.pickup, widget.dropoff];
    if (widget.routePoints != null) points.addAll(widget.routePoints!);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: AppTheme.coral,
            icon: Icons.location_on,
            label: 'B',
          ),
        ),
      // Driver marker — pulsing green circle
      if (widget.driverLocation != null)
        Marker(
          point: widget.driverLocation!,
          width: 44,
          height: 44,
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
            child: const Icon(Icons.directions_car, color: Colors.white, size: 22),
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
        // Dark tile layer — CartoDB Dark Matter (free, no API key)
        // Gives a premium Uber-style muted-slate dark map aesthetic
        if (isDark)
          TileLayer(
            urlTemplate: _fallbackDarkRaster,
            subdomains: _fallbackSubdomains,
            userAgentPackageName: 'com.pondyconnect.app',
            retinaMode: true,
          )
        else
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.pondyconnect.app',
            retinaMode: true,
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
        final scale = 1.0 + (_pulse.value * 0.4);
        final opacity = (1.0 - _pulse.value) * 0.5;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing glow ring
            Transform.scale(
              scale: scale,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _userPuckGlowColor.withValues(alpha: opacity),
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
