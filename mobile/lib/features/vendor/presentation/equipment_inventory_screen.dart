import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/equipment_api.dart';

/// Equipment inventory management screen for PartySupplier vendors.
/// Shows finite inventory cards with pricing, deposit, and stock controls.
class EquipmentInventoryScreen extends ConsumerStatefulWidget {
  const EquipmentInventoryScreen({super.key});

  @override
  ConsumerState<EquipmentInventoryScreen> createState() =>
      _EquipmentInventoryScreenState();
}

class _EquipmentInventoryScreenState
    extends ConsumerState<EquipmentInventoryScreen> {
  List<EquipmentItemModel> _items = [];
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
      final items = await ref.read(equipmentApiProvider).getMyItems();
      if (mounted) {
        setState(() {
          _items = items;
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

  Future<void> _adjustStock(EquipmentItemModel item, int delta) async {
    AppHaptics.light();
    try {
      final updated = await ref.read(equipmentApiProvider).updateItem(
            id: item.id,
            stockAdjustment: delta,
          );
      if (mounted) {
        setState(() {
          final idx = _items.indexWhere((e) => e.id == updated.id);
          if (idx >= 0) _items[idx] = updated;
        });
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

  Future<void> _showAddItemDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '1500');
    final depositCtrl = TextEditingController(text: '5000');
    final unitsCtrl = TextEditingController(text: '2');
    final categoryCtrl = TextEditingController(text: 'Misc');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Equipment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: priceCtrl,
                decoration:
                    const InputDecoration(labelText: 'Daily Rental Price (₹)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: depositCtrl,
                decoration:
                    const InputDecoration(labelText: 'Security Deposit (₹)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: unitsCtrl,
                decoration: const InputDecoration(labelText: 'Total Units'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                    labelText: 'Category (e.g. Speakers, Lighting)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Add', style: TextStyle(color: AppTheme.emerald)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final newItem =
            await ref.read(equipmentApiProvider).createItem(
                  name: nameCtrl.text,
                  dailyRentalPrice:
                      double.tryParse(priceCtrl.text) ?? 0,
                  securityDepositAmount:
                      double.tryParse(depositCtrl.text) ?? 0,
                  totalUnits: int.tryParse(unitsCtrl.text) ?? 1,
                  category: categoryCtrl.text,
                );
        if (mounted) {
          setState(() => _items = [..._items, newItem]);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added: ${newItem.name}'),
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(error: _error!, onRetry: _loadData)
                : _items.isEmpty
                    ? _EmptyState(onAdd: _showAddItemDialog)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          return _EquipmentCard(
                            item: item,
                            onMinus: () => _adjustStock(item, -1),
                            onPlus: () => _adjustStock(item, 1),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: AppTheme.emerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Equipment'),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.item,
    required this.onMinus,
    required this.onPlus,
  });

  final EquipmentItemModel item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final soldOut = item.availableUnits == 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.coral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.speaker, color: AppTheme.coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (soldOut)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SOLD OUT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (item.description != null) ...[
              const SizedBox(height: 8),
              Text(
                item.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _PriceChip(
                  label: '₹${item.dailyRentalPrice.toStringAsFixed(0)}/day',
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 8),
                _PriceChip(
                  label:
                      'Deposit ₹${item.securityDepositAmount.toStringAsFixed(0)}',
                  color: AppTheme.coral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Available Units: ',
                    style: TextStyle(fontSize: 14)),
                IconButton(
                  onPressed: onMinus,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.danger,
                ),
                Text(
                  '${item.availableUnits}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: onPlus,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.emerald,
                ),
                const Spacer(),
                Text(
                  'of ${item.totalUnits}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.speaker, size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text(
          'No equipment yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Add speakers, lights, and other event equipment\nto start receiving rental bookings.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Equipment'),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
        const SizedBox(height: 16),
        const Text(
          'Failed to load inventory',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
