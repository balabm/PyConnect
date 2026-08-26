import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/consumer_equipment_api.dart';

final equipmentBrowseProvider =
    FutureProvider.family<List<ConsumerEquipmentItemModel>, String?>((ref, category) async {
  final api = ref.watch(consumerEquipmentApiProvider);
  return await api.browse(category: category);
});

/// Consumer-facing equipment rental browse screen.
/// Lists all available equipment across vendors with category filters.
class EquipmentBrowseScreen extends ConsumerStatefulWidget {
  const EquipmentBrowseScreen({super.key});

  @override
  ConsumerState<EquipmentBrowseScreen> createState() =>
      _EquipmentBrowseScreenState();
}

class _EquipmentBrowseScreenState extends ConsumerState<EquipmentBrowseScreen> {
  String? _categoryFilter;

  static const _categories = <String?>[null, 'Sound', 'Lighting', 'DJ', 'Power', 'Misc'];

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(equipmentBrowseProvider(_categoryFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Rentals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'My Rentals',
            onPressed: () => context.push('/equipment/my-rentals'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _categories.map((cat) {
                final isSelected = _categoryFilter == cat;
                final label = cat ?? 'All';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) {
                      AppHaptics.light();
                      setState(() => _categoryFilter = cat);
                    },
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.emerald,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Equipment list
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(equipmentBrowseProvider(_categoryFilter)),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _EquipmentCard(item: item);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speaker_outlined, size: 64, color: AppTheme.slate.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No equipment available',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.slate.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later as vendors add inventory',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.slate.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text('Could not load equipment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => ref.invalidate(equipmentBrowseProvider(_categoryFilter)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.item});

  final ConsumerEquipmentItemModel item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canBook = item.isAvailable && item.availableUnits > 0;

    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        context.push('/equipment/${item.id}', extra: item);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image or placeholder
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.emerald.withValues(alpha: 0.2), AppTheme.emerald.withValues(alpha: 0.05)],
                  ),
                ),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
                      )
                    : _buildPlaceholderIcon(),
              ),
            ),
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\u20B9${item.dailyRentalPrice.toStringAsFixed(0)}/day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: canBook
                                ? AppTheme.emerald.withValues(alpha: 0.15)
                                : AppTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            canBook ? '${item.availableUnits} avail' : 'Sold out',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: canBook ? AppTheme.emerald : AppTheme.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(Icons.speaker, size: 36, color: AppTheme.emerald.withValues(alpha: 0.4)),
    );
  }
}
