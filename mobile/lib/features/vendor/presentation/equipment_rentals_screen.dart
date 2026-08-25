import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/equipment_api.dart';

/// Asset-tracking Kanban board for equipment vendors.
/// Replaces KDS with three columns: To Deliver, Active in Field, Awaiting Return.
class EquipmentRentalsScreen extends ConsumerStatefulWidget {
  const EquipmentRentalsScreen({super.key});

  @override
  ConsumerState<EquipmentRentalsScreen> createState() =>
      _EquipmentRentalsScreenState();
}

class _EquipmentRentalsScreenState
    extends ConsumerState<EquipmentRentalsScreen> {
  List<EquipmentRentalModel> _rentals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rentals = await ref.read(equipmentApiProvider).getRentals();
      if (mounted) {
        setState(() {
          _rentals = rentals;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<EquipmentRentalModel> _filterByStatus(String status) {
    return _rentals.where((r) => r.status == status).toList();
  }

  Future<void> _advanceStatus(EquipmentRentalModel rental, String newStatus) async {
    AppHaptics.light();
    try {
      await ref.read(equipmentApiProvider).updateRentalStatus(
            rentalId: rental.id,
            newStatus: newStatus,
          );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to $newStatus'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _showReturnDialog(EquipmentRentalModel rental) async {
    final lateCtrl = TextEditingController(text: '0');
    final damageCtrl = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Return: ${rental.itemName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Deposit: ₹${rental.securityDeposit.toStringAsFixed(0)}',
                style: TextStyle(color: AppTheme.coral, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: lateCtrl,
              decoration: const InputDecoration(
                labelText: 'Late Minutes',
                hintText: '0',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: damageCtrl,
              decoration: const InputDecoration(
                labelText: 'Damage Amount (₹)',
                hintText: '0',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Complete Return', style: TextStyle(color: AppTheme.emerald)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final res = await ref.read(equipmentApiProvider).completeReturn(
              rentalId: rental.id,
              lateMinutes: int.tryParse(lateCtrl.text) ?? 0,
              damageAmount: double.tryParse(damageCtrl.text) ?? 0,
            );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Return complete. Penalty: ₹${res.depositPenalty.toStringAsFixed(0)}, Refunded: ₹${res.depositRefunded.toStringAsFixed(0)}',
              ),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final toDeliver = _filterByStatus('Pending');
    final activeInField = _filterByStatus('ActiveInField');
    final awaitingReturn = _filterByStatus('AwaitingReturn');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KanbanColumn(
                title: 'To Deliver',
                color: AppTheme.coral,
                rentals: toDeliver,
                actionLabel: 'Mark Delivered',
                onAction: (r) => _advanceStatus(r, 'Delivered'),
              ),
              const SizedBox(width: 16),
              _KanbanColumn(
                title: 'Active in Field',
                color: AppTheme.emerald,
                rentals: activeInField,
                actionLabel: 'Mark Awaiting Return',
                onAction: (r) => _advanceStatus(r, 'AwaitingReturn'),
              ),
              const SizedBox(width: 16),
              _KanbanColumn(
                title: 'Awaiting Return',
                color: Colors.amber,
                rentals: awaitingReturn,
                actionLabel: 'Complete Return',
                onAction: _showReturnDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.title,
    required this.color,
    required this.rentals,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final Color color;
  final List<EquipmentRentalModel> rentals;
  final String actionLabel;
  final void Function(EquipmentRentalModel) onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${rentals.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...rentals.map((r) => _RentalCard(
                rental: r,
                actionLabel: actionLabel,
                onAction: () => onAction(r),
              )),
          if (rentals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No rentals',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  const _RentalCard({
    required this.rental,
    required this.actionLabel,
    required this.onAction,
  });

  final EquipmentRentalModel rental;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rental.itemName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${rental.unitsBooked} unit(s)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start: ${_fmtDate(rental.rentalStart)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              'End: ${_fmtDate(rental.rentalEnd)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '₹${rental.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppTheme.emerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Deposit: ₹${rental.securityDeposit.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.coral,
                  ),
                ),
              ],
            ),
            if (rental.deliveryAddress != null) ...[
              const SizedBox(height: 4),
              Text(
                rental.deliveryAddress!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
