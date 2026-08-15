import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

class VendorMenuScreen extends ConsumerWidget {
  const VendorMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(vendorMenuProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Menu Management'),
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
        onPressed: () {
          AppHaptics.light();
          _showAddItemSheet(context, ref);
        },
        backgroundColor: AppTheme.coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: menuAsync.when(
        loading: () => const ShimmerList(withImage: false, count: 6),
        error: (e, _) => ErrorState(
          message: 'Failed to load menu: $e',
          onRetry: () => ref.read(vendorMenuProvider.notifier).load(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No menu items yet',
              subtitle: 'Tap + to add your first dish',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return _MenuItemCard(
                item: item,
                onToggle: () => ref.read(vendorMenuProvider.notifier).toggleItem(item.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddItemSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddMenuItemSheet(),
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  const _MenuItemCard({required this.item, required this.onToggle});
  final MenuItemModel item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (item.imageUrl != null)
            AppNetworkImage(
              imageUrl: item.imageUrl!,
              width: 56,
              height: 56,
              borderRadius: 8,
              fit: BoxFit.cover,
              fallbackIcon: Icons.restaurant,
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.lagoon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant, color: AppTheme.lagoon),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: item.category,
                      variant: BadgeVariant.neutral,
                    ),
                  ],
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '\u20B9${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lagoon,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.5)),
                color: const Color(0xFF1E293B),
                onSelected: (value) {
                  AppHaptics.light();
                  if (value == 'edit') {
                    _showEditSheet(context, ref);
                  } else if (value == 'delete') {
                    _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, color: AppTheme.lagoon, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Item', style: TextStyle(color: Colors.white)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: AppTheme.coral, size: 20),
                      SizedBox(width: 12),
                      Text('Remove Item', style: TextStyle(color: AppTheme.coral)),
                    ]),
                  ),
                ],
              ),
              Text(
                item.isAvailable ? 'In Stock' : 'Sold Out',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.isAvailable ? AppTheme.lagoon : AppTheme.coral,
                ),
              ),
              Switch(
                value: item.isAvailable,
                activeThumbColor: AppTheme.lagoon,
                activeTrackColor: AppTheme.lagoon.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.coral,
                inactiveTrackColor: AppTheme.coral.withValues(alpha: 0.3),
                onChanged: (_) {
                  AppHaptics.light();
                  onToggle();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditMenuItemSheet(item: item),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Remove Item?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Mark "${item.name}" as unavailable? It will be hidden from customers.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vendorMenuProvider.notifier).toggleItem(item.id);
            },
            child: const Text('Mark Unavailable'),
          ),
        ],
      ),
    );
  }
}

class _EditMenuItemSheet extends ConsumerStatefulWidget {
  const _EditMenuItemSheet({required this.item});
  final MenuItemModel item;

  @override
  ConsumerState<_EditMenuItemSheet> createState() => _EditMenuItemSheetState();
}

class _EditMenuItemSheetState extends ConsumerState<_EditMenuItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(0));
    _categoryController = TextEditingController(text: widget.item.category);
    _descriptionController = TextEditingController(text: widget.item.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and price are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(vendorMenuProvider.notifier).updateItem(
        widget.item.id,
        UpdateMenuItemPayload(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          category: _categoryController.text.trim().isEmpty
              ? 'General'
              : _categoryController.text.trim(),
          newPrice: double.tryParse(_priceController.text.trim()),
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
        left: 16, right: 16, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit Menu Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Dish Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price (\u20B9) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : () {
                AppHaptics.medium();
                _submit();
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.lagoon),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMenuItemSheet extends ConsumerStatefulWidget {
  const _AddMenuItemSheet();

  @override
  ConsumerState<_AddMenuItemSheet> createState() => _AddMenuItemSheetState();
}

class _AddMenuItemSheetState extends ConsumerState<_AddMenuItemSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLateNight = false;
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
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and price are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(vendorMenuProvider.notifier).createItem(
        CreateMenuItemPayload(
          name: _nameController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          category: _categoryController.text.trim().isEmpty
              ? 'General'
              : _categoryController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isLateNight: _isLateNight,
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
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Menu Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Dish Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price (\u20B9) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'e.g. Starters, Main Course, Beverages',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Late Night Item'),
            subtitle: const Text('Show in late-night menu (after 11 PM)'),
            value: _isLateNight,
            activeThumbColor: AppTheme.lagoon,
            onChanged: (v) {
              AppHaptics.light();
              setState(() => _isLateNight = v);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : () {
                AppHaptics.medium();
                _submit();
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.lagoon),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Item', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
