import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Capacity management for LuggageCloak vendors.
/// Shows current cloak occupancy with a visual capacity bar and stored bags list.
class CloakCapacityScreen extends ConsumerStatefulWidget {
  const CloakCapacityScreen({super.key});

  @override
  ConsumerState<CloakCapacityScreen> createState() => _CloakCapacityScreenState();
}

class _CloakCapacityScreenState extends ConsumerState<CloakCapacityScreen> {
  List<BookingSummary> _stored = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  static const int _maxCapacity = 50;

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
      final bookings = await ref.read(vendorDashboardApiProvider).getBookings();
      if (mounted) {
        setState(() {
          _stored = bookings.where((b) =>
              b.status.toLowerCase() == 'confirmed' ||
              b.status.toLowerCase() == 'inprogress').toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Color get _capacityColor {
    final ratio = _stored.length / _maxCapacity;
    if (ratio > 0.85) return AppTheme.danger;
    if (ratio > 0.6) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () { AppHaptics.light(); _loadData(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: AppTheme.emerald,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCapacityBar(),
                      const SizedBox(height: 24),
                      Text('Stored Bags',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_stored.isEmpty)
                        _buildEmpty()
                      else
                        ..._stored.map((b) => _BagCard(booking: b)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(icon: Icon(Icons.qr_code),
        label: Text('New Bag Drop'),
        onPressed: _showBagDropDialog,
      ),
    );
  }

  void _showBagDropDialog() {
    AppHaptics.light();
    final nameController = TextEditingController();
    final bagCountController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text('New Bag Drop', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Customer Name',
                labelStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.54)),
                hintText: 'Enter customer name',
                hintStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.24)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bagCountController,
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bag Count',
                labelStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () {
              final name = nameController.text.trim();
              final bagCount = int.tryParse(bagCountController.text) ?? 1;
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              _showClaimCheckQR(name, bagCount);
            },
            child: Text('Generate Claim Check'),
          ),
        ],
      ),
    );
  }

  void _showClaimCheckQR(String customerName, int bagCount) async {
    AppHaptics.medium();

    // Show a loading dialog while creating the claim check
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final api = ref.read(vendorDashboardApiProvider);
      final result = await api.createClaimCheck(
        customerName: customerName,
        bagCount: bagCount,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      // Show the QR claim check dialog with real data from the backend
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Claim Check QR',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer: ${result.customerName} · ${result.bagCount} ${result.bagCount == 1 ? 'bag' : 'bags'}',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 20),
              QrImageView(
                data: result.qrPayload,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.claimCheckId,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(),
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadData();
                },
                child: Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create claim check: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Widget _buildCapacityBar() {
    final color = _capacityColor;
    final pct = (_stored.length / _maxCapacity * 100).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Occupancy',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${_stored.length} / $_maxCapacity',
                  style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _stored.length / _maxCapacity,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text('${pct.toStringAsFixed(0)}% full',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.luggage, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No bags stored',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14)),
            const SizedBox(height: 4),
            Text('Check in bags via the Scanner tab',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25), fontSize: 12)),
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
            Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Could not load capacity',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 18)),
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

class _BagCard extends StatelessWidget {
  const _BagCard({required this.booking});
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.luggage, color: AppTheme.success, size: 24),
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Text('\u20B9${booking.amount.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
