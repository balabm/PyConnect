import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/animations/staggered_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

class AdminSosScreen extends ConsumerWidget {
  const AdminSosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(adminSosAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminSosAlertsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger)))),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64, color: AdminColors.success),
                  const SizedBox(height: 16),
                  const Text('All Clear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('No active SOS alerts', style: TextStyle(color: AdminColors.textMuted)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) => _SosAlertCard(alert: alerts[index]),
          );
        },
      ),
    );
  }
}

class _SosAlertCard extends ConsumerWidget {
  const _SosAlertCard({required this.alert});
  final AdminSosAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AdminColors.danger.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AdminColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.warning_rounded, color: AdminColors.danger, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary)),
                      Text(alert.userPhone, style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AdminColors.danger, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulsingDot(color: AdminColors.textPrimary, size: 6, duration: const Duration(milliseconds: 800)),
                      const SizedBox(width: 6),
                      Text(alert.status, style: const TextStyle(color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(icon: Icons.location_on_rounded, label: 'Location', value: '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}'),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.access_time_rounded, label: 'Triggered', value: _timeAgo(alert.triggeredAt)),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.motorcycle_rounded, label: 'Ride ID', value: alert.rideId.substring(0, 8)),
            if (alert.vehicleType != null && alert.vehicleType!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.directions_car_rounded, label: 'Vehicle', value: '${alert.vehicleType}${alert.vehiclePlate != null && alert.vehiclePlate!.isNotEmpty ? ' \u2022 ${alert.vehiclePlate}' : ''}'),
            ],
            if (alert.emergencyContactName != null && alert.emergencyContactName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.contact_emergency_rounded, label: 'Emergency Contact', value: '${alert.emergencyContactName}${alert.emergencyContactPhone != null && alert.emergencyContactPhone!.isNotEmpty ? ' \u2022 ${alert.emergencyContactPhone}' : ''}'),
            ],
            if (alert.notes != null) ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.note_rounded, label: 'Notes', value: alert.notes!),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Call button
                if (alert.userPhone.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.phone, size: 18, color: AdminColors.success),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(foregroundColor: AdminColors.success),
                    onPressed: () => _callUser(context),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Map'),
                  onPressed: () => _showMapDialog(context, ref, alert),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) {
                    if (v == 'resolve') _resolveSos(context, ref, alert);
                    if (v == 'false_alarm') _falseAlarm(context, ref, alert);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'resolve',
                      child: ListTile(
                        leading: Icon(Icons.check_rounded, color: AdminColors.success),
                        title: Text('Mark Resolved'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'false_alarm',
                      child: ListTile(
                        leading: Icon(Icons.cancel_rounded, color: AdminColors.warning),
                        title: Text('False Alarm'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _callUser(BuildContext context) async {
    final phone = alert.userPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available'), backgroundColor: AdminColors.warning),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch call to $phone'), backgroundColor: AdminColors.danger),
        );
      }
    }
  }

  void _resolveSos(BuildContext context, WidgetRef ref, AdminSosAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve SOS Alert'),
        content: const Text('Mark this SOS alert as resolved?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminApiProvider).resolveSosAlert(alert.id);
      ref.invalidate(adminSosAlertsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS alert resolved'), backgroundColor: AdminColors.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger));
      }
    }
  }

  void _falseAlarm(BuildContext context, WidgetRef ref, AdminSosAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as False Alarm?'),
        content: const Text('This will resolve the alert with a "False alarm" note.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark False Alarm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminApiProvider).resolveSosAlert(alert.id, notes: 'False alarm');
      ref.invalidate(adminSosAlertsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as false alarm'), backgroundColor: AdminColors.warning),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger));
      }
    }
  }

  void _showMapDialog(BuildContext context, WidgetRef ref, AdminSosAlert alert) {
    final driversAsync = ref.read(adminDriverLocationsProvider);

    showDialog(
      context: context,
      builder: (ctx) => _SosMapDialog(
        alert: alert,
        driversAsync: driversAsync,
        onResolve: () {
          Navigator.pop(ctx);
          _resolveSos(context, ref, alert);
        },
      ),
    );
  }
}

/// Full-screen dialog with a real FlutterMap showing the SOS location
/// and nearby drivers.
class _SosMapDialog extends ConsumerWidget {
  const _SosMapDialog({
    required this.alert,
    required this.driversAsync,
    required this.onResolve,
  });

  final AdminSosAlert alert;
  final AsyncValue<List<DriverLocation>> driversAsync;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sosLatLng = LatLng(alert.latitude, alert.longitude);
    final drivers = driversAsync.valueOrNull ?? [];

    // Calculate bounds to fit SOS + nearby drivers
    final points = <LatLng>[sosLatLng];
    for (final d in drivers) {
      points.add(LatLng(d.lat, d.lng));
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Real map
              FlutterMap(
                options: MapOptions(
                  initialCenter: sosLatLng,
                  initialZoom: 14,
                  minZoom: 3,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.pondyconnect.admin',
                  ),
                  // Driver markers
                  MarkerLayer(
                    markers: drivers.map((d) => Marker(
                      point: LatLng(d.lat, d.lng),
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: d.isOnline ? AppTheme.emerald : AdminColors.textMuted,
                          shape: BoxShape.circle,
                          border: Border.all(color: AdminColors.textPrimary, width: 2),
                        ),
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          color: AdminColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    )).toList(),
                  ),
                  // SOS marker (pulsing red)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: sosLatLng,
                        width: 50,
                        height: 50,
                        child: _PulsingSosMarker(),
                      ),
                    ],
                  ),
                ],
              ),
              // Top overlay: user info
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: AdminColors.danger, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(alert.userName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminColors.textPrimary)),
                            Text('${alert.userPhone} · ${_timeAgo(alert.triggeredAt)}',
                                style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
                          ],
                        ),
                      ),
                      if (alert.userPhone.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone, color: AdminColors.success),
                          onPressed: () async {
                            final uri = Uri.parse('tel:${alert.userPhone}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          tooltip: 'Call',
                        ),
                    ],
                  ),
                ),
              ),
              // Bottom overlay: legend + resolve button
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    // Legend
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AdminColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: AdminColors.danger, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('SOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                          const SizedBox(width: 12),
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.emerald, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Drivers (${drivers.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Resolve'),
                      style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
                      onPressed: onResolve,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing red SOS marker for the map.
class _PulsingSosMarker extends StatefulWidget {
  @override
  State<_PulsingSosMarker> createState() => _PulsingSosMarkerState();
}

class _PulsingSosMarkerState extends State<_PulsingSosMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing ring
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            return Transform.scale(
              scale: 1.0 + _controller.value * 0.8,
              child: Opacity(
                opacity: 1.0 - _controller.value,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AdminColors.danger.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
        // Solid marker
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AdminColors.danger,
            shape: BoxShape.circle,
            border: Border.all(color: AdminColors.textPrimary, width: 3),
            boxShadow: [
              BoxShadow(
                color: AdminColors.danger.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.warning, color: AdminColors.textPrimary, size: 18),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AdminColors.textMuted),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(fontSize: 13, color: AdminColors.textMuted, fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
}
