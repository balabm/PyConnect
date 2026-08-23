import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/admin_providers.dart';

/// Live map pane showing real driver locations on an interactive map.
/// Uses CartoDB Dark Matter tiles for a sleek, high-contrast dark map
/// that makes route lines and markers pop (Uber-style).
class HeatmapPane extends ConsumerStatefulWidget {
  const HeatmapPane({super.key});

  @override
  ConsumerState<HeatmapPane> createState() => _HeatmapPaneState();
}

class _HeatmapPaneState extends ConsumerState<HeatmapPane> {
  late final MapController _mapController;

  // Pondicherry center
  static const _pondyCenter = LatLng(11.9356, 79.8301);

  // CartoDB Dark Matter — pitch black, muted greys, no noise.
  static const _darkTiles =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const _subdomains = ['a', 'b', 'c', 'd'];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(adminDriverLocationsProvider);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _pondyCenter,
            initialZoom: 13.5,
            minZoom: 10,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: _darkTiles,
              subdomains: _subdomains,
              userAgentPackageName: 'com.pondyconnect.admin',
            ),
            driversAsync.when(
              loading: () => const MarkerLayer(markers: []),
              error: (_, _) => const MarkerLayer(markers: []),
              data: (drivers) => MarkerLayer(
                markers: drivers.map((d) => Marker(
                  point: LatLng(d.lat, d.lng),
                  width: 44,
                  height: 44,
                  child: _DriverMarker(name: d.name, isOnline: d.isOnline),
                )).toList(),
              ),
            ),
          ],
        ),
        // Title overlay
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AdminColors.bg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: AdminColors.accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Live Driver Map — Pondicherry',
                  style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        // Driver count badge
        Positioned(
          top: 8,
          right: 8,
          child: driversAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (drivers) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AdminColors.accent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AdminColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.two_wheeler, color: AdminColors.textPrimary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${drivers.where((d) => d.isOnline).length} online',
                    style: const TextStyle(color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Loading overlay
        if (driversAsync.isLoading)
          Positioned.fill(
            child: Container(
              color: AdminColors.bg.withValues(alpha: 0.2),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.accent),
              ),
            ),
          ),
      ],
    );
  }
}

/// Animated driver marker with pulsing online indicator.
class _DriverMarker extends StatefulWidget {
  const _DriverMarker({required this.name, required this.isOnline});
  final String name;
  final bool isOnline;

  @override
  State<_DriverMarker> createState() => _DriverMarkerState();
}

class _DriverMarkerState extends State<_DriverMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isOnline) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(_DriverMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !oldWidget.isOnline) {
      _pulseController.repeat();
    } else if (!widget.isOnline && oldWidget.isOnline) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline ? AdminColors.accent : AdminColors.textMuted;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Pulsing ring for online drivers
        if (widget.isOnline)
          Positioned(
            left: -6, top: -6,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, _) {
                final scale = 1.0 + 0.5 * _pulseController.value;
                final opacity = 1.0 - _pulseController.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: opacity * 0.6), width: 2),
                    ),
                  ),
                );
              },
            ),
          ),
        // Marker body
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isOnline
                  ? [AdminColors.accent, AdminColors.accentLight]
                  : [AdminColors.surfaceHover, AdminColors.textMuted],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: AdminColors.textPrimary, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.two_wheeler,
            color: AdminColors.textPrimary,
            size: 20,
          ),
        ),
      ],
    );
  }
}
