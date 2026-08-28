import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Fleet management for ScooterRental vendors.
/// Shows scooter inventory with status and availability toggle.
class FleetManagementScreen extends ConsumerStatefulWidget {
  const FleetManagementScreen({super.key});

  @override
  ConsumerState<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends ConsumerState<FleetManagementScreen> {
  List<BookingSummary> _bookings = [];
  List<ScooterFleetModel> _fleet = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ref.read(vendorDashboardApiProvider).getBookings(),
        ref.read(vendorDashboardApiProvider).getScooterFleet(),
      ]);
      if (mounted) {
        setState(() {
          _bookings = results[0] as List<BookingSummary>;
          _fleet = results[1] as List<ScooterFleetModel>;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadFleet() async {
    try {
      final fleet = await ref.read(vendorDashboardApiProvider).getScooterFleet();
      if (mounted) setState(() => _fleet = fleet);
    } catch (e) {
      debugPrint('Failed to load fleet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRentals = _bookings.where((b) =>
        b.status.toLowerCase() == 'confirmed' ||
        b.status.toLowerCase() == 'inprogress' ||
        b.status.toLowerCase() == 'reserved').toList();
    final available = _bookings.where((b) =>
        b.status.toLowerCase() == 'completed' ||
        b.status.toLowerCase() == 'cancelled').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          title: Text('Fleet', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () { AppHaptics.light(); _loadData(); },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pedal_bike), text: 'Rentals'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Inventory'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
            : _error != null
                ? _buildError()
                : TabBarView(
                    children: [
                      // Tab 1: Active Rentals (existing)
                      RefreshIndicator(
                        color: AppTheme.emerald,
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildStatRow(activeRentals.length, available.length),
                            const SizedBox(height: 16),
                            Text('Active Rentals',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            if (activeRentals.isEmpty)
                              _buildEmpty('No active rentals', Icons.pedal_bike)
                            else
                              ...activeRentals.map((b) => _ScooterCard(booking: b, isActive: true)),
                            const SizedBox(height: 24),
                            Text('Available / Returned',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            if (available.isEmpty)
                              _buildEmpty('No returned scooters', Icons.history)
                            else
                              ...available.map((b) => _ScooterCard(booking: b, isActive: false)),
                          ],
                        ),
                      ),
                      // Tab 2: Fleet Inventory (new)
                      _buildInventoryTab(),
                    ],
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddScooterDialog,
          backgroundColor: AppTheme.emerald,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    final availableCount = _fleet.where((s) => s.isAvailable && !s.isRented).length;
    final rentedCount = _fleet.where((s) => s.isRented).length;
    final totalCount = _fleet.length;

    return RefreshIndicator(
      color: AppTheme.emerald,
      onRefresh: _loadFleet,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats row
          Row(
            children: [
              Expanded(child: _StatTile(
                icon: Icons.inventory_2, label: 'Total', value: totalCount, color: AppTheme.info)),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(
                icon: Icons.check_circle, label: 'Available', value: availableCount, color: AppTheme.success)),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(
                icon: Icons.pedal_bike, label: 'Rented', value: rentedCount, color: AppTheme.gold)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Fleet Inventory',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_fleet.isEmpty)
            _buildEmpty('No scooters in inventory.\nTap + to add your first scooter.', Icons.pedal_bike)
          else
            ..._fleet.map((scooter) => _FleetItemCard(
              scooter: scooter,
              onToggleAvailability: () async {
                AppHaptics.light();
                try {
                  await ref.read(vendorDashboardApiProvider).toggleScooterAvailability(scooter.id);
                  _loadFleet();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
                    );
                  }
                }
              },
              onEdit: () => _showEditScooterDialog(scooter),
              onDelete: () => _confirmDelete(scooter),
            )),
        ],
      ),
    );
  }

  void _showAddScooterDialog() {
    final modelController = TextEditingController();
    final rateController = TextEditingController(text: '50');
    final plateController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Scooter'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: 'Model (e.g. Honda Activa)',
                  prefixIcon: Icon(Icons.pedal_bike),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rate per hour (\u20B9)',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateController,
                decoration: const InputDecoration(
                  labelText: 'Plate number (optional)',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final model = modelController.text.trim();
              final rate = double.tryParse(rateController.text.trim()) ?? 0;
              final plate = plateController.text.trim();
              if (model.isEmpty || rate <= 0) return;
              Navigator.pop(ctx);
              try {
                await ref.read(vendorDashboardApiProvider).addScooter(
                  model: model,
                  ratePerHour: rate,
                  plateNumber: plate.isEmpty ? null : plate,
                );
                _loadFleet();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scooter added!'), backgroundColor: AppTheme.emerald),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditScooterDialog(ScooterFleetModel scooter) {
    final modelController = TextEditingController(text: scooter.model);
    final rateController = TextEditingController(text: scooter.ratePerHour.toStringAsFixed(0));
    final plateController = TextEditingController(text: scooter.plateNumber ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Scooter'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.pedal_bike),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rate per hour (\u20B9)',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateController,
                decoration: const InputDecoration(
                  labelText: 'Plate number',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final model = modelController.text.trim();
              final rate = double.tryParse(rateController.text.trim());
              final plate = plateController.text.trim();
              Navigator.pop(ctx);
              try {
                await ref.read(vendorDashboardApiProvider).updateScooter(
                  scooter.id,
                  model: model.isEmpty ? null : model,
                  ratePerHour: rate,
                  plateNumber: plate.isEmpty ? null : plate,
                );
                _loadFleet();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scooter updated!'), backgroundColor: AppTheme.emerald),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ScooterFleetModel scooter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Scooter?'),
        content: Text('Remove "${scooter.model}" from your fleet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(vendorDashboardApiProvider).removeScooter(scooter.id);
                _loadFleet();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scooter removed'), backgroundColor: AppTheme.danger),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(int active, int available) {
    return Row(
      children: [
        Expanded(child: _StatTile(
          icon: Icons.electric_scooter, label: 'Active', value: active, color: AppTheme.info)),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(
          icon: Icons.check_circle, label: 'Available', value: available, color: AppTheme.success)),
      ],
    );
  }

  Widget _buildEmpty(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Could not load fleet',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              onPressed: () { setState(() => _loading = true); _loadData(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon; final String label; final int value; final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScooterCard extends StatelessWidget {
  const _ScooterCard({required this.booking, required this.isActive});
  final BookingSummary booking; final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isActive ? AppTheme.info : AppTheme.success).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (isActive ? AppTheme.info : AppTheme.success).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.electric_scooter,
                color: isActive ? AppTheme.info : AppTheme.success, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.customerName,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(booking.serviceType,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\u20B9${booking.amount.toStringAsFixed(0)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isActive ? AppTheme.info : AppTheme.success).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(booking.status,
                    style: TextStyle(
                      color: isActive ? AppTheme.info : AppTheme.success,
                      fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _FleetItemCard extends StatelessWidget {
  const _FleetItemCard({
    required this.scooter,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDelete,
  });

  final ScooterFleetModel scooter;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = scooter.isRented
        ? AppTheme.gold
        : scooter.isAvailable
            ? AppTheme.emerald
            : AppTheme.slate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                scooter.isElectric ? Icons.electric_scooter : Icons.pedal_bike,
                color: statusColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scooter.model,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (scooter.plateNumber != null)
                      Text(
                        scooter.plateNumber!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scooter.isRented
                      ? 'Rented'
                      : scooter.isAvailable
                          ? 'Available'
                          : 'Unavailable',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '\u20B9${scooter.ratePerHour.toStringAsFixed(0)}/hr',
                style: TextStyle(
                  color: AppTheme.emerald,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scooter.ratePerDay != null) ...[
                const SizedBox(width: 8),
                Text(
                  '\u20B9${scooter.ratePerDay!.toStringAsFixed(0)}/day',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
              if (scooter.isElectric && scooter.batteryPercent != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.battery_full, size: 14, color: AppTheme.emerald),
                const SizedBox(width: 2),
                Text('${scooter.batteryPercent}%', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleAvailability,
                icon: Icon(
                  scooter.isAvailable ? Icons.pause_circle : Icons.play_circle,
                  size: 16,
                ),
                label: Text(scooter.isAvailable ? 'Disable' : 'Enable'),
                style: TextButton.styleFrom(
                  foregroundColor: scooter.isAvailable ? AppTheme.gold : AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}