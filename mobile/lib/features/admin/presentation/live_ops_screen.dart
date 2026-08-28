import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/service_area_config.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

/// The "God Map" — a full-screen live operations map locked to Pondicherry.
///
/// Renders all online drivers as green moving dots and all active
/// deliveries/rides as pulsing orange dots. Subscribes to the admin SignalR
/// hub (`/hubs/admin`) for real-time driver location updates and active
/// ride/delivery events.
///
/// SOS interception: listens for `SosAlert` events from the admin hub. When
/// an SOS is triggered, a massive red banner flashes across the top, a
/// blaring audio alarm plays, the banner shows the triggerer's phone
/// number, and tapping it focuses the map on the SOS GPS coordinates.
class LiveOpsScreen extends ConsumerStatefulWidget {
  const LiveOpsScreen({super.key});

  @override
  ConsumerState<LiveOpsScreen> createState() => _LiveOpsScreenState();
}

class _LiveOpsScreenState extends ConsumerState<LiveOpsScreen>
    with TickerProviderStateMixin {
  /// Pondicherry bounding box — the map is locked within these bounds.
  static final _pondyBounds = LatLngBounds(
    ServiceAreaConfig.southWestBound,
    ServiceAreaConfig.northEastBound,
  );
  static const _pondyCenter = ServiceAreaConfig.defaultCenter;

  final MapController _mapController = MapController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final AnimationController _bannerController;
  late final AnimationController _pulseController;

  /// The most recent active SOS alert surfaced via SignalR (for the banner).
  AdminSosAlert? _activeSos;
  StreamSubscription<AdminSignalREvent>? _eventSub;
  bool _alarmPlaying = false;

  @override
  void initState() {
    super.initState();
    // Flash the SOS banner by alternating opacity 0.4 ↔ 1.0 every 0.6s.
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.4,
      upperBound: 1.0,
    );
    // Drive the pulsing orange delivery/ride markers.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(1.0);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _bannerController.dispose();
    _pulseController.dispose();
    _stopAlarm();
    _audioPlayer.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSosAlert(AdminSosAlert alert) {
    if (!mounted) return;
    setState(() {
      _activeSos = alert;
      _bannerController
        ..reset()
        ..repeat(reverse: true);
    });
    _playAlarm();
  }

  Future<void> _playAlarm() async {
    if (_alarmPlaying) return;
    _alarmPlaying = true;
    try {
      await _audioPlayer.play(AssetSource('sounds/error.mp3'));
    } catch (_) {
      // Audio playback may be blocked until a user gesture on some browsers.
      _alarmPlaying = false;
    }
  }

  Future<void> _stopAlarm() async {
    if (!_alarmPlaying) return;
    _alarmPlaying = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  void _focusSos() {
    final alert = _activeSos;
    if (alert == null) return;
    _mapController.move(
      LatLng(alert.latitude, alert.longitude),
      16,
    );
  }

  void _dismissSos() {
    _bannerController.stop();
    _stopAlarm();
    setState(() => _activeSos = null);
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to admin SignalR events for SOS + live ops updates.
    ref.watch(adminSignalREventHandlerProvider);
    final signalr = ref.watch(adminSignalRProvider);
    signalr.whenData((event) {
      if (event.type == 'SosAlert' && event.payload != null) {
        // Avoid re-triggering for the same alert id on every rebuild.
        final alert = AdminSosAlert.fromJson(event.payload!);
        if (_activeSos?.id != alert.id) {
          _onSosAlert(alert);
        }
      }
    });

    final drivers = (ref.watch(adminDriverLocationsProvider).valueOrNull ?? [])
        .where((d) => d.isOnline)
        .toList();
    final rides = ref.watch(adminActiveRidesProvider).valueOrNull ?? [];
    final deliveries =
        ref.watch(adminActiveDeliveriesProvider).valueOrNull ?? [];
    final sosAlerts = ref.watch(adminSosAlertsProvider).valueOrNull ?? [];

    // If there are no SignalR-driven banner alerts but polling shows active
    // SOS alerts, surface the first one (defensive fallback).
    if (_activeSos == null && sosAlerts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeSos == null) {
          _onSosAlert(sosAlerts.first);
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          _GodMap(
            controller: _mapController,
            bounds: _pondyBounds,
            center: _pondyCenter,
            drivers: drivers,
            rides: rides,
            deliveries: deliveries,
            sosAlerts: sosAlerts,
            pulseAnimation: _pulseController,
            activeSosId: _activeSos?.id,
          ),
          // Stats overlay (top-left)
          Positioned(
            top: 12,
            left: 12,
            child: _StatsOverlay(
              onlineDrivers: drivers.length,
              activeRides: rides.length,
              activeDeliveries: deliveries.length,
              activeSos: sosAlerts.length,
            ),
          ),
          // SOS banner (top, full width)
          if (_activeSos != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SosBanner(
                controller: _bannerController,
                alert: _activeSos!,
                onTap: _focusSos,
                onDismiss: _dismissSos,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen God Map
// ---------------------------------------------------------------------------

class _GodMap extends StatelessWidget {
  const _GodMap({
    required this.controller,
    required this.bounds,
    required this.center,
    required this.drivers,
    required this.rides,
    required this.deliveries,
    required this.sosAlerts,
    required this.pulseAnimation,
    required this.activeSosId,
  });

  final MapController controller;
  final LatLngBounds bounds;
  final LatLng center;
  final List<DriverLocation> drivers;
  final List<AdminActiveRide> rides;
  final List<Map<String, dynamic>> deliveries;
  final List<AdminSosAlert> sosAlerts;
  final Animation<double> pulseAnimation;
  final String? activeSosId;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // Online drivers → green dots.
    for (final d in drivers) {
      markers.add(Marker(
        point: LatLng(d.lat, d.lng),
        width: 16,
        height: 16,
        child: _GreenDot(label: d.name),
      ));
    }

    // Active rides → pulsing orange dots at pickup.
    for (final r in rides) {
      if (r.pickupLatitude != null && r.pickupLongitude != null) {
        markers.add(Marker(
          point: LatLng(r.pickupLatitude!, r.pickupLongitude!),
          width: 24,
          height: 24,
          child: _PulsingOrangeDot(animation: pulseAnimation),
        ));
      }
    }

    // Active food deliveries → pulsing orange dots at driver location.
    for (final del in deliveries) {
      final lat = (del['latitude'] as num?)?.toDouble();
      final lng = (del['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 24,
          height: 24,
          child: _PulsingOrangeDot(animation: pulseAnimation, isDelivery: true),
        ));
      }
    }

    // SOS alerts → red markers.
    for (final s in sosAlerts) {
      markers.add(Marker(
        point: LatLng(s.latitude, s.longitude),
        width: 40,
        height: 40,
        child: _SosMarker(active: s.id == activeSosId),
      ));
    }

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        minZoom: 11,
        maxZoom: 18,
        // Lock the map within Pondicherry's bounding box.
        cameraConstraint: CameraConstraint.contain(bounds: bounds),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pondyconnect.admin',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Map markers
// ---------------------------------------------------------------------------

class _GreenDot extends StatelessWidget {
  const _GreenDot({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label ?? 'Online driver',
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.success,
          shape: BoxShape.circle,
          border: Border.all(color: AdminColors.textPrimary, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _PulsingOrangeDot extends StatelessWidget {
  const _PulsingOrangeDot({required this.animation, this.isDelivery = false});

  final Animation<double> animation;
  final bool isDelivery;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => child!,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing halo
          AnimatedBuilder(
            animation: animation,
            builder: (_, _) {
              final t = animation.value;
              return Transform.scale(
                scale: 0.6 + t * 0.9,
                child: Opacity(
                  opacity: (1.0 - t) * 0.6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          // Solid core
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: AdminColors.textPrimary, width: 1.5),
            ),
            child: Icon(
              isDelivery ? Icons.shopping_bag_rounded : Icons.two_wheeler_rounded,
              size: 8,
              color: AdminColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SosMarker extends StatelessWidget {
  const _SosMarker({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: active ? AdminColors.danger : AdminColors.danger.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: AdminColors.textPrimary, width: 2),
      ),
      child: const Icon(Icons.warning_rounded,
          color: Colors.white, size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats overlay
// ---------------------------------------------------------------------------

class _StatsOverlay extends StatelessWidget {
  const _StatsOverlay({
    required this.onlineDrivers,
    required this.activeRides,
    required this.activeDeliveries,
    required this.activeSos,
  });

  final int onlineDrivers;
  final int activeRides;
  final int activeDeliveries;
  final int activeSos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendRow(
            color: AdminColors.success,
            icon: Icons.navigation_rounded,
            label: 'Online Drivers',
            count: onlineDrivers,
          ),
          const SizedBox(height: 6),
          _LegendRow(
            color: Colors.orange,
            icon: Icons.two_wheeler_rounded,
            label: 'Active Rides',
            count: activeRides,
          ),
          const SizedBox(height: 6),
          _LegendRow(
            color: Colors.orange,
            icon: Icons.shopping_bag_rounded,
            label: 'Deliveries',
            count: activeDeliveries,
          ),
          if (activeSos > 0) ...[
            const SizedBox(height: 6),
            _LegendRow(
              color: AdminColors.danger,
              icon: Icons.warning_rounded,
              label: 'SOS Alerts',
              count: activeSos,
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.count,
  });

  final Color color;
  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('$count $label',
            style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SOS banner — massive, flashing, with phone number + click-to-focus
// ---------------------------------------------------------------------------

class _SosBanner extends StatelessWidget {
  const _SosBanner({
    required this.controller,
    required this.alert,
    required this.onTap,
    required this.onDismiss,
  });

  final AnimationController controller;
  final AdminSosAlert alert;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(opacity: controller.value, child: child);
      },
      child: Material(
        color: AdminColors.danger,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'EMERGENCY SOS TRIGGERED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${alert.userName}  \u2022  ${alert.userPhone.isNotEmpty ? alert.userPhone : "No phone"}  \u2022  Tap to focus map',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_off_rounded,
                      color: Colors.white),
                  tooltip: 'Silence alarm',
                  onPressed: onDismiss,
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
