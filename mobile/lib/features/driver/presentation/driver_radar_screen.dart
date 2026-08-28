import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';

/// Demand heatmap / radar screen for the Captain app.
///
/// Displays surge zones as a simple visual list of colored cards (no map).
/// Each card shows the area name, pending orders, active drivers,
/// demand/supply ratio, and surge bonus. A radar pulse animation runs in
/// the header and the list auto-refreshes every 30 seconds.
class DriverRadarScreen extends ConsumerStatefulWidget {
  const DriverRadarScreen({super.key});

  @override
  ConsumerState<DriverRadarScreen> createState() => _DriverRadarScreenState();
}

class _DriverRadarScreenState extends ConsumerState<DriverRadarScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _loadZones();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadZones(silent: true);
    });
  }

  Future<void> _loadZones({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final zones = await ref.read(driverApiProvider).getSurgeZones();
      if (mounted) {
        setState(() {
          _zones = zones;
          _errorMessage = null;
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    AppHaptics.light();
    await _loadZones(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demand Radar'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.emerald,
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(color: AppTheme.emerald),
        ),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        // RefreshIndicator needs a scrollable; keep it so pull works.
        children: [
          ErrorState(
            message: _errorMessage!,
            onRetry: () => _loadZones(),
          ),
        ],
      );
    }

    if (_zones.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.radar_outlined,
            title: 'No Surge Zones Right Now',
            subtitle:
                'Demand is balanced across all areas. Check back later for hot zones with bonus earnings.',
            actionLabel: 'Refresh',
            onAction: _onRefresh,
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPadding(
          padding: const EdgeInsets.only(
            bottom: AppSpacing.xxl,
          ),
          sliver: SliverList.builder(
            itemCount: _zones.length,
            itemBuilder: (context, index) {
              return _SurgeZoneCard(
                zone: _zones[index],
                onNavigate: () => _showNavigateSnackbar(context, _zones[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final surgeCount = _zones
        .where((z) => _readLevel(z) == 'Surge')
        .length;
    final highCount = _zones
        .where((z) => _readLevel(z) == 'High')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          // Radar pulse animation
          SizedBox(
            height: 120,
            child: Center(child: _RadarPulse(controller: _radarController)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Live Demand Heatmap',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Updated ${_formatTime(_lastUpdated)} • Auto-refresh 30s',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendChip(
                label: 'Surge',
                count: surgeCount,
                color: AppTheme.danger,
              ),
              const SizedBox(width: AppSpacing.sm),
              _LegendChip(
                label: 'High',
                count: highCount,
                color: AppTheme.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              _LegendChip(
                label: 'Moderate',
                count: _zones.length - surgeCount - highCount,
                color: AppTheme.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNavigateSnackbar(BuildContext context, Map<String, dynamic> zone) {
    AppHaptics.medium();
    final area = _readString(zone, 'areaName');
    final lat = zone['latitude'] ?? zone['lat'];
    final lng = zone['longitude'] ?? zone['lng'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lat != null && lng != null
            ? 'Head to $area ($lat, $lng) for higher demand'
            : 'Head to $area for higher demand'),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _readLevel(Map<String, dynamic> zone) {
    return _readString(zone, 'level');
  }

  String _readString(Map<String, dynamic> zone, String key) {
    final value = zone[key];
    return value == null ? '' : value.toString();
  }
}

/// Animated radar pulse with concentric expanding rings.
class _RadarPulse extends StatelessWidget {
  const _RadarPulse({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          final rings = List<Widget>.generate(3, (i) {
            final t = (controller.value + i / 3) % 1.0;
            final scale = 0.3 + 0.9 * t;
            final opacity = (1.0 - t).clamp(0.0, 1.0);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.emerald.withValues(alpha: opacity * 0.6),
                    width: 2,
                  ),
                ),
              ),
            );
          });
          return Stack(
            alignment: Alignment.center,
            children: [
              ...rings,
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.emerald.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppTheme.emerald,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.radar,
                  color: AppTheme.emerald,
                  size: 22,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small legend chip showing level color and count.
class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label $count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single surge zone card with a colored left border based on level.
class _SurgeZoneCard extends StatelessWidget {
  const _SurgeZoneCard({required this.zone, required this.onNavigate});

  final Map<String, dynamic> zone;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final level = _readString(zone, 'level');
    final color = _colorForLevel(level);
    final areaName = _readString(zone, 'areaName');
    final pending = _readInt(zone, 'pendingOrders');
    final activeDrivers = _readInt(zone, 'activeDrivers');
    final ratio = _readDouble(zone, 'demandSupplyRatio');
    final bonus = _readDouble(zone, 'surgeBonus');

    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored left border indicating heat level
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: color),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          areaName.isEmpty ? 'Unknown Area' : areaName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          level.isEmpty ? 'Moderate' : level,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _StatPill(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Pending',
                        value: '$pending',
                        color: AppTheme.info,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatPill(
                        icon: Icons.directions_car_outlined,
                        label: 'Drivers',
                        value: '$activeDrivers',
                        color: AppTheme.slate,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatPill(
                        icon: Icons.trending_up,
                        label: 'D/S',
                        value: ratio.toStringAsFixed(1),
                        color: AppTheme.emerald,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.bolt, size: 16, color: AppTheme.gold),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Surge Bonus  ₹${bonus.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.navigation_outlined, size: 18),
                      label: const Text('Navigate to Hotzone'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.emerald,
                        side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'Surge':
        return AppTheme.danger;
      case 'High':
        return AppTheme.warning;
      case 'Moderate':
      default:
        return AppTheme.gold;
    }
  }

  String _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    return value == null ? '' : value.toString();
  }

  int _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _readDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

/// Compact stat pill with icon, label, and value.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: AppTheme.slate,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
