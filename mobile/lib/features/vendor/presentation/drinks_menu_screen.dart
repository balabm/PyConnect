import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Drinks menu management for Pub/Club vendors.
/// Reuses the existing menu API but displays with beverage-themed UI.
class DrinksMenuScreen extends ConsumerWidget {
  const DrinksMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(vendorMenuProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Drinks Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              ref.read(vendorMenuProvider.notifier).load();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.coral,
        onPressed: () {
          AppHaptics.light();
          _showAddDrinkSheet(context, ref);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: menuAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.coral),
        ),
        error: (e, _) => _buildError(context, ref, e.toString()),
        data: (items) {
          if (items.isEmpty) {
            return _buildEmpty();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _DrinkCard(
              name: items[i].name,
              category: items[i].category,
              price: items[i].price,
              isAvailable: items[i].isAvailable,
              description: items[i].description,
              onToggle: () {
                AppHaptics.light();
                ref.read(vendorMenuProvider.notifier).toggleItem(items[i].id);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Could not load menu',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () => ref.read(vendorMenuProvider.notifier).load(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_bar, size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No drinks on the menu yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 18)),
          const SizedBox(height: 8),
          Text('Tap + to add your first drink',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
        ],
      ),
    );
  }

  void _showAddDrinkSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const _AddDrinkSheet(),
    );
  }
}

class _DrinkCard extends StatelessWidget {
  const _DrinkCard({
    required this.name,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.description,
    required this.onToggle,
  });

  final String name;
  final String category;
  final double price;
  final bool isAvailable;
  final String? description;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.coral.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_bar, color: AppTheme.coral, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '\u20B9${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.lagoon,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                isAvailable ? 'In Stock' : 'Sold Out',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAvailable ? AppTheme.lagoon : AppTheme.coral,
                ),
              ),
              Switch(
                value: isAvailable,
                activeThumbColor: AppTheme.lagoon,
                activeTrackColor: AppTheme.lagoon.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.coral,
                inactiveTrackColor: AppTheme.coral.withValues(alpha: 0.3),
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddDrinkSheet extends ConsumerStatefulWidget {
  const _AddDrinkSheet();

  @override
  ConsumerState<_AddDrinkSheet> createState() => _AddDrinkSheetState();
}

class _AddDrinkSheetState extends ConsumerState<_AddDrinkSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Cocktail');
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;
    AppHaptics.light();
    setState(() => _submitting = true);
    try {
      await ref.read(vendorMenuProvider.notifier).createItem(
            CreateMenuItemPayload(
              name: _nameController.text,
              price: double.parse(_priceController.text),
              category: _categoryController.text,
              description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Drink',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildField(_nameController, 'Drink name', Icons.local_bar),
          const SizedBox(height: 12),
          _buildField(_priceController, 'Price (\u20B9)', Icons.payments, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildField(_categoryController, 'Category (Cocktail, Beer, Wine, Spirit)',
              Icons.category),
          const SizedBox(height: 12),
          _buildField(_descriptionController, 'Description (optional)', Icons.description, maxLines: 2),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Drink'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.4)),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.coral),
        ),
      ),
    );
  }
}
