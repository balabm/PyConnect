import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/map_tile_config.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/address_provider.dart';

/// A full-screen map picker where the user drags the map under a fixed
/// center pin to select a location. The center coordinates are reverse-
/// geocoded via the Nominatim API and shown in a bottom bar. Tapping
/// "Confirm Location" returns the selected [Address] via [Navigator.pop].
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key, this.initialLocation});

  /// Optional initial center for the map. Falls back to the user's current
  /// saved location, then to Pondicherry's center.
  final LatLng? initialLocation;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _center;
  String _formattedAddress = '';
  bool _geocoding = false;
  bool _geocodeFailed = false;

  /// A standalone Dio instance for Nominatim reverse-geocoding requests.
  /// Nominatim requires a descriptive User-Agent header per its usage policy.
  final Dio _nominatim = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'com.pondyconnect.app',
    },
  ));

  @override
  void initState() {
    super.initState();
    _center = widget.initialLocation ??
        ref.read(currentLocationProvider)?.toLatLng() ??
        const LatLng(11.9356, 79.8301);
  }

  @override
  void dispose() {
    _nominatim.close();
    super.dispose();
  }

  /// Reverse-geocodes the given [lat], [lng] using the Nominatim API and
  /// updates the bottom bar with the formatted address. On failure, shows
  /// the raw coordinates instead so the user can still confirm.
  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() {
      _geocoding = true;
      _geocodeFailed = false;
    });

    try {
      final response = await _nominatim.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': lat.toString(),
          'lon': lng.toString(),
        },
      );

      final data = response.data;
      final displayName = data is Map ? data['display_name'] as String? : null;

      if (!mounted) return;
      setState(() {
        _geocoding = false;
        if (displayName != null && displayName.isNotEmpty) {
          _formattedAddress = displayName;
          _geocodeFailed = false;
        } else {
          _formattedAddress =
              'Pinned location (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
          _geocodeFailed = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _geocoding = false;
        _formattedAddress =
            'Pinned location (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
        _geocodeFailed = true;
      });
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      final center = event.camera.center;
      _center = center;
      AppHaptics.light();
      _reverseGeocode(center.latitude, center.longitude);
    }
  }

  void _confirm() {
    AppHaptics.success();
    final address = Address(
      latitude: _center.latitude,
      longitude: _center.longitude,
      tag: 'Other',
      formattedAddress: _formattedAddress.isNotEmpty
          ? _formattedAddress
          : 'Pinned location (${_center.latitude.toStringAsFixed(5)}, '
              '${_center.longitude.toStringAsFixed(5)})',
    );
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- Full-screen map ---
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 16,
                onMapEvent: _onMapEvent,
                onPositionChanged: (camera, hasGesture) {
                  // Track the live center without rebuilding on every frame.
                  // The reverse-geocode is triggered on move-end via onMapEvent.
                  _center = camera.center;
                },
              ),
              children: [
                MapTileConfig.forTheme(context),
              ],
            ),
          ),

          // --- Fixed center pin (does NOT move) ---
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pin shadow
                Container(
                  width: 2,
                  height: 0,
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // The pin itself
                const Icon(
                  Icons.location_pin,
                  size: 48,
                  color: AppTheme.danger,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                // Small pointer tip to mark exact center
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Top bar with back button and hint ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            'Drag the map to position the pin',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Bottom bar with address + confirm button ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _geocodeFailed
                              ? Icons.location_off_outlined
                              : Icons.location_on,
                          size: 20,
                          color: _geocodeFailed
                              ? AppTheme.warning
                              : AppTheme.emerald,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _geocoding
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Looking up address…',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                )
                              : Text(
                                  _formattedAddress.isNotEmpty
                                      ? _formattedAddress
                                      : 'Drag the map to select a location',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm Location'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
