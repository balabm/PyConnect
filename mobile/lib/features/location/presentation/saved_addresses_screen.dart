import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/address_provider.dart';
import 'map_picker_screen.dart';

/// Fetches the user's saved addresses from the backend.
final savedAddressesProvider = FutureProvider.autoDispose<List<Address>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final result = await client.get('/api/user/addresses');
  if (result is List) {
    return result
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  // Some backends wrap lists in a top-level object — handle both.
  if (result is Map && result['addresses'] is List) {
    return (result['addresses'] as List)
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  return [];
});

/// Screen showing the user's saved addresses with tag chips, details, and
/// management (add / delete). Pull-to-refresh is supported.
class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() =>
      _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(savedAddressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Places'),
      ),
      body: RefreshIndicator(
        color: AppTheme.emerald,
        onRefresh: () async {
          AppHaptics.light();
          ref.invalidate(savedAddressesProvider);
          // Wait for the provider to settle so the indicator animates.
          await ref.read(savedAddressesProvider.future);
        },
        child: addresses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(savedAddressesProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.place_outlined,
                title: 'No saved places yet',
                subtitle:
                    'Add your home, work, or hotel to book rides and orders faster.',
                actionLabel: 'Add Address',
                onAction: _openMapPicker,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: 100,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final address = list[index];
                return _AddressCard(
                  address: address,
                  onDelete: () => _confirmDelete(address),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openMapPicker,
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
        backgroundColor: AppTheme.emerald,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Opens the [MapPickerScreen]; once a location is picked, shows the
  /// address form bottom sheet and saves the result.
  Future<void> _openMapPicker() async {
    AppHaptics.light();
    final picked = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (context) => const MapPickerScreen(),
      ),
    );

    if (picked == null || !mounted) return;

    _showAddressForm(picked);
  }

  void _showAddressForm(Address draft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => _AddressFormSheet(
        draft: draft,
        onSave: (address) async {
          try {
            await ref
                .read(currentLocationProvider.notifier)
                .saveAddress(address);
            AppHaptics.success();
            if (mounted) {
              Navigator.of(this.context).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Address saved.'),
                  backgroundColor: AppTheme.emerald,
                ),
              );
              ref.invalidate(savedAddressesProvider);
            }
          } catch (e) {
            AppHaptics.warning();
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text('Could not save address: $e')),
              );
            }
          }
        },
      ),
    );
  }

  /// Shows a confirmation dialog before deleting the given address.
  Future<void> _confirmDelete(Address address) async {
    AppHaptics.medium();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(
          'Are you sure you want to remove "${address.formattedAddress}" '
          'from your saved places?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _deleteAddress(address);
  }

  Future<void> _deleteAddress(Address address) async {
    if (address.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This address cannot be deleted (missing ID).'),
        ),
      );
      return;
    }

    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/api/user/addresses/${address.id}');
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted.'),
            backgroundColor: AppTheme.danger,
          ),
        );
        ref.invalidate(savedAddressesProvider);
      }
    } catch (e) {
      AppHaptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete address: $e')),
        );
      }
    }
  }
}

/// A single saved-address card with tag chip, formatted address, subtitle,
/// and a delete button.
class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onDelete});

  final Address address;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tagInfo = _tagInfo(address.tag);

    return AppCard(
      onTap: null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tagInfo.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(tagInfo.icon, color: tagInfo.color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tag chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tagInfo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    address.tag,
                    style: TextStyle(
                      color: tagInfo.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Formatted address (bold)
                Text(
                  address.formattedAddress,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Door/Flat + Landmark subtitle
                if (address.doorFlat != null ||
                    address.landmark != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (address.doorFlat != null) address.doorFlat,
                      if (address.landmark != null) address.landmark,
                    ].join(' • '),
                    style: TextStyle(
                      color: AppTheme.slate,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            onPressed: onDelete,
            tooltip: 'Delete address',
          ),
        ],
      ),
    );
  }
}

/// Holds the icon and color associated with a given address tag.
class _TagInfo {
  const _TagInfo({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_TagInfo _tagInfo(String tag) {
  switch (tag) {
    case 'Home':
      return const _TagInfo(icon: Icons.home, color: AppTheme.emerald);
    case 'Work':
      return const _TagInfo(icon: Icons.work, color: AppTheme.info);
    case 'Hotel':
    case 'Villa':
      return const _TagInfo(icon: Icons.hotel, color: AppTheme.gold);
    default:
      return const _TagInfo(icon: Icons.place, color: AppTheme.slate);
  }
}

/// Bottom-sheet form shown after a location is picked from the map.
/// Collects tag, door/flat, landmark, and voice instructions, then calls
/// [onSave] with the complete [Address].
class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({required this.draft, required this.onSave});

  final Address draft;
  final ValueChanged<Address> onSave;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _doorFlatController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _voiceController = TextEditingController();
  String _tag = 'Home';

  static const _tags = [
    ('Home', Icons.home),
    ('Work', Icons.work),
    ('Hotel', Icons.hotel),
    ('Other', Icons.place),
  ];

  @override
  void dispose() {
    _doorFlatController.dispose();
    _landmarkController.dispose();
    _voiceController.dispose();
    super.dispose();
  }

  void _save() {
    AppHaptics.light();
    final address = Address(
      latitude: widget.draft.latitude,
      longitude: widget.draft.longitude,
      formattedAddress: widget.draft.formattedAddress,
      tag: _tag,
      doorFlat: _doorFlatController.text.trim().isEmpty
          ? null
          : _doorFlatController.text.trim(),
      landmark: _landmarkController.text.trim().isEmpty
          ? null
          : _landmarkController.text.trim(),
    );
    widget.onSave(address);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppTheme.slate.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Save address',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.draft.formattedAddress,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.slate,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xl),

              // --- Tag selection ---
              Text(
                'Tag this place',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _tags.map((entry) {
                  final (label, icon) = entry;
                  final selected = _tag == label;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16),
                        const SizedBox(width: 6),
                        Text(label),
                      ],
                    ),
                    selected: selected,
                    selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.emeraldDark : AppTheme.slate,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    onSelected: (_) {
                      AppHaptics.light();
                      setState(() => _tag = label);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // --- Door/Flat ---
              TextField(
                controller: _doorFlatController,
                decoration: const InputDecoration(
                  labelText: 'Door / Flat No.',
                  hintText: 'e.g., Flat 302, 2nd Floor',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.door_front_door_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),

              // --- Landmark ---
              TextField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  labelText: 'Landmark',
                  hintText: 'e.g., Near Rock Beach',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),

              // --- Voice instructions for Captain ---
              TextField(
                controller: _voiceController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Voice instructions for Captain',
                  hintText: 'e.g., Ring the bell, don\'t call',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.mic_outlined),
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // --- Save button ---
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save Address'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
