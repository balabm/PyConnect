import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

Widget _buildMenuField(
  BuildContext context,
  TextEditingController controller,
  String label, {
  String? hintText,
  IconData? prefixIcon,
  TextInputType? keyboardType,
  int maxLines = 1,
  required ValueChanged<String> onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.emerald, width: 2),
      ),
    ),
  );
}

class VendorMenuScreen extends ConsumerWidget {
  const VendorMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(vendorMenuProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Menu Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
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
        child: Icon(Icons.add),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                color: AppTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.restaurant, color: AppTheme.emerald),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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
                    color: AppTheme.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                color: Theme.of(context).colorScheme.surface,
                onSelected: (value) {
                  AppHaptics.light();
                  if (value == 'edit') {
                    _showEditSheet(context, ref);
                  } else if (value == 'delete') {
                    _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, color: AppTheme.emerald, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Item', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: AppTheme.danger, size: 20),
                      SizedBox(width: 12),
                      Text('Remove Item', style: TextStyle(color: AppTheme.danger)),
                    ]),
                  ),
                ],
              ),
              Text(
                item.isAvailable ? 'In Stock' : 'Sold Out',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.isAvailable ? AppTheme.emerald : AppTheme.danger,
                ),
              ),
              Switch(
                value: item.isAvailable,
                activeThumbColor: AppTheme.emerald,
                activeTrackColor: AppTheme.emerald.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.emerald,
                inactiveTrackColor: AppTheme.emerald.withValues(alpha: 0.3),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditMenuItemSheet(item: item),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text('Remove Item?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Mark "${item.name}" as unavailable? It will be hidden from customers.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vendorMenuProvider.notifier).toggleItem(item.id);
            },
            child: Text('Mark Unavailable'),
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
  late final TextEditingController _prepTimeController;
  late bool _isVeg;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(0));
    _categoryController = TextEditingController(text: widget.item.category);
    _descriptionController = TextEditingController(text: widget.item.description ?? '');
    _prepTimeController = TextEditingController(
      text: widget.item.prepTimeMinutes?.toString() ?? '',
    );
    _isVeg = widget.item.isVeg;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
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
          isVeg: _isVeg,
          prepTimeMinutes: _prepTimeController.text.trim().isEmpty
              ? null
              : int.tryParse(_prepTimeController.text.trim()),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
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
          Text('Edit Menu Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          _buildMenuField(
            context,
            _nameController,
            'Dish Name *',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _priceController,
            'Price (\u20B9) *',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _categoryController,
            'Category',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _descriptionController,
            'Description (optional)',
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _prepTimeController,
            'Prep Time (minutes)',
            hintText: 'e.g. 15',
            prefixIcon: Icons.timer_outlined,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.circle, size: 12),
                label: Text('Veg'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.change_circle, size: 12),
                label: Text('Non-Veg'),
              ),
            ],
            selected: {_isVeg},
            onSelectionChanged: (v) {
              AppHaptics.light();
              setState(() => _isVeg = v.first);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ||
                      _nameController.text.isEmpty ||
                      _priceController.text.isEmpty
                  ? null
                  : () {
                      AppHaptics.medium();
                      _submit();
                    },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                  : Text('Save Changes', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary)),
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
  final _imageUrlController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _packagingFeeController = TextEditingController();
  bool _isLateNight = false;
  bool _isVeg = true;
  bool _isVegan = false;
  bool _containsNuts = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _prepTimeController.dispose();
    _packagingFeeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and price are required')),
      );
      return;
    }

    // Validate price is a valid number.
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price must be a valid positive number')),
      );
      return;
    }

    // Validate image URL format if provided.
    final imageUrl = _imageUrlController.text.trim();
    if (imageUrl.isNotEmpty) {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasAbsolutePath || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image URL must be a valid http/https URL')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await ref.read(vendorMenuProvider.notifier).createItem(
        CreateMenuItemPayload(
          name: _nameController.text.trim(),
          price: price,
          category: _categoryController.text.trim().isEmpty
              ? 'General'
              : _categoryController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          isLateNight: _isLateNight,
          isVeg: _isVeg,
          isVegan: _isVegan,
          containsNuts: _containsNuts,
          prepTimeMinutes: _prepTimeController.text.trim().isEmpty
              ? null
              : int.tryParse(_prepTimeController.text.trim()),
          packagingFee: double.tryParse(_packagingFeeController.text.trim()) ?? 0,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
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
          Text('Add Menu Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          _buildMenuField(
            context,
            _nameController,
            'Dish Name *',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _priceController,
            'Price (\u20B9) *',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _categoryController,
            'Category',
            hintText: 'e.g. Starters, Main Course, Beverages',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _descriptionController,
            'Description (optional)',
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _imageUrlController,
            'Image URL (optional)',
            hintText: 'https://...',
            prefixIcon: Icons.image_outlined,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _prepTimeController,
            'Prep Time (minutes)',
            hintText: 'e.g. 15',
            prefixIcon: Icons.timer_outlined,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Veg / Non-Veg toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.circle, size: 12),
                label: Text('Veg'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.change_circle, size: 12),
                label: Text('Non-Veg'),
              ),
            ],
            selected: {_isVeg},
            onSelectionChanged: (v) {
              AppHaptics.light();
              setState(() => _isVeg = v.first);
            },
          ),
          const SizedBox(height: 12),
          // Dietary tags
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Vegan'),
                selected: _isVegan,
                onSelected: (v) { AppHaptics.light(); setState(() => _isVegan = v); },
                selectedColor: AppTheme.emerald.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.emerald,
              ),
              FilterChip(
                label: const Text('Contains Nuts'),
                selected: _containsNuts,
                onSelected: (v) { AppHaptics.light(); setState(() => _containsNuts = v); },
                selectedColor: AppTheme.warning.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMenuField(
            context,
            _packagingFeeController,
            'Packaging Fee (₹)',
            hintText: 'e.g. 10',
            prefixIcon: Icons.inventory_2_outlined,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text('Late Night Item', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            subtitle: Text('Show in late-night menu (after 11 PM)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            value: _isLateNight,
            activeThumbColor: AppTheme.emerald,
            onChanged: (v) {
              AppHaptics.light();
              setState(() => _isLateNight = v);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ||
                      _nameController.text.isEmpty ||
                      _priceController.text.isEmpty ||
                      double.tryParse(_priceController.text.trim()) == null
                  ? null
                  : () {
                      AppHaptics.medium();
                      _submit();
                    },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : Text('Add Item', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
