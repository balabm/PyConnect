import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/config/service_area_config.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

final savedLocationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(ridesApiProvider);
  return await api.listSavedLocations();
});

class SavedLocationsScreen extends ConsumerStatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  ConsumerState<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends ConsumerState<SavedLocationsScreen> {
  void _addLocation() {
    AppHaptics.light();
    showDialog(context: context, builder: (ctx) => _AddLocationDialog(onSave: (label, address) async {
      final api = ref.read(ridesApiProvider);
      try {
        // Default to Pondicherry center for now
        await api.addSavedLocation(label, address, ServiceAreaConfig.defaultCenter.latitude, ServiceAreaConfig.defaultCenter.longitude);
        ref.invalidate(savedLocationsProvider);
        if (ctx.mounted) {
          AppHaptics.success();
          Navigator.pop(ctx);
        }
      } catch (e) {
        if (ctx.mounted) {
          AppHaptics.error();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }));
  }

  Future<void> _deleteLocation(String id) async {
    AppHaptics.heavy();
    try {
      final api = ref.read(ridesApiProvider);
      await api.deleteSavedLocation(id);
      ref.invalidate(savedLocationsProvider);
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(savedLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Places')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: locationsAsync.when(
        loading: () => const ShimmerList(withImage: false, count: 4),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(savedLocationsProvider),
        ),
        data: (locations) => locations.isEmpty
            ? const EmptyState(
                icon: Icons.bookmark_border,
                title: 'No saved places',
                subtitle: 'Save Home, Work, and other frequent destinations for quick booking',
                actionLabel: 'Add Place',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: locations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final loc = locations[index] as Map<String, dynamic>;
                  final label = loc['label'] as String? ?? '';
                  final address = loc['address'] as String? ?? '';
                  final id = loc['id'] as String? ?? '';
                  return FadeSlideIn(
                    delay: Duration(milliseconds: index * 50),
                    child: _SavedLocationCard(
                      label: label,
                      address: address,
                      icon: _labelIcon(label),
                      onDelete: () => _deleteLocation(id),
                    ),
                  );
                },
              ),
      ),
    );
  }

  IconData _labelIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('home')) return Icons.home;
    if (l.contains('work')) return Icons.work;
    if (l.contains('gym')) return Icons.fitness_center;
    return Icons.place;
  }
}

class _SavedLocationCard extends StatelessWidget {
  const _SavedLocationCard({
    required this.label,
    required this.address,
    required this.icon,
    required this.onDelete,
  });

  final String label;
  final String address;
  final IconData icon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardShadow
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            AppHaptics.light();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.emerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddLocationDialog extends StatefulWidget {
  const _AddLocationDialog({required this.onSave});
  final Future<void> Function(String label, String address) onSave;

  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Saved Place'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label (e.g. Home, Work)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Home', 'Work', 'Gym', 'Other'].map((label) {
              return ActionChip(
                label: Text(label),
                onPressed: () {
                  AppHaptics.selection();
                  _labelController.text = label;
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : () async {
            if (_labelController.text.isEmpty || _addressController.text.isEmpty) return;
            AppHaptics.medium();
            setState(() => _saving = true);
            await widget.onSave(_labelController.text, _addressController.text);
          },
          child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
