import 'package:flutter/material.dart';

import '../../../../core/animations/haptic.dart';
import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/food_api.dart';

/// Result returned by [ItemCustomizationSheet] when the user confirms.
/// Contains the selected modifier IDs and the computed unit price
/// (base price + sum of selected modifier prices).
class CustomizationResult {
  const CustomizationResult({
    required this.quantity,
    required this.unitPrice,
    required this.selectedModifierIds,
    required this.selectedModifierNames,
  });

  final int quantity;
  final double unitPrice;
  final List<String> selectedModifierIds;
  final List<String> selectedModifierNames;
}

/// A bottom sheet that lets the consumer customize a [MenuItem] by selecting
/// modifiers from its modifier groups.
///
/// Rendering rules per group:
/// * MinSelections == 1 && MaxSelections == 1 → Radio buttons (single choice)
/// * MinSelections == 0 && MaxSelections > 0  → Checkboxes (multi-choice)
/// * MinSelections > 0 → labelled "Required (choose {min})"
/// * MinSelections == 0 → labelled "Optional (up to {max})"
///
/// The "Add to Cart" button is disabled until all MinSelections constraints
/// are met. The running total (base + modifiers) is shown on the button.
class ItemCustomizationSheet extends StatefulWidget {
  const ItemCustomizationSheet({
    super.key,
    required this.item,
    this.initialQuantity = 1,
  });

  /// The menu item with its modifier groups loaded from the backend.
  final MenuItem item;

  /// Starting quantity (defaults to 1).
  final int initialQuantity;

  /// Convenience method to show the sheet as a modal bottom sheet.
  /// Returns null if the user dismisses without confirming.
  static Future<CustomizationResult?> show(
    BuildContext context, {
    required MenuItem item,
    int initialQuantity = 1,
  }) {
    return showModalBottomSheet<CustomizationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemCustomizationSheet(
        item: item,
        initialQuantity: initialQuantity,
      ),
    );
  }

  @override
  State<ItemCustomizationSheet> createState() => _ItemCustomizationSheetState();
}

class _ItemCustomizationSheetState extends State<ItemCustomizationSheet> {
  late int _quantity;

  /// For single-choice groups: maps group index → selected modifier index.
  final Map<int, int> _singleSelections = {};

  /// For multi-choice groups: maps group index → set of selected modifier indices.
  final Map<int, Set<int>> _multiSelections = {};

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
  }

  /// Returns the label for a modifier group based on its min/max constraints.
  String _groupLabel(ModifierGroup group) {
    if (group.minSelections > 0) {
      return 'Required (choose ${group.minSelections})';
    }
    if (group.maxSelections > 0) {
      return 'Optional (up to ${group.maxSelections})';
    }
    return 'Optional';
  }

  /// Whether all required modifier groups have enough selections.
  bool get _allRequirementsMet {
    for (int i = 0; i < widget.item.modifierGroups.length; i++) {
      final group = widget.item.modifierGroups[i];
      final selectedCount = _selectedCountForGroup(i);
      if (selectedCount < group.minSelections) return false;
    }
    return true;
  }

  int _selectedCountForGroup(int groupIndex) {
    if (_singleSelections.containsKey(groupIndex)) return 1;
    return _multiSelections[groupIndex]?.length ?? 0;
  }

  /// Collects all selected modifier IDs across all groups.
  List<Modifier> get _selectedModifiers {
    final result = <Modifier>[];
    for (int i = 0; i < widget.item.modifierGroups.length; i++) {
      final group = widget.item.modifierGroups[i];
      if (group.isSingleChoice) {
        final idx = _singleSelections[i];
        if (idx != null && idx < group.modifiers.length) {
          result.add(group.modifiers[idx]);
        }
      } else {
        final indices = _multiSelections[i];
        if (indices != null) {
          for (final idx in indices) {
            if (idx < group.modifiers.length) {
              result.add(group.modifiers[idx]);
            }
          }
        }
      }
    }
    return result;
  }

  double get _modifiersTotal =>
      _selectedModifiers.fold(0.0, (sum, m) => sum + m.price);

  double get _unitPrice => widget.item.price + _modifiersTotal;

  double get _totalPrice => _unitPrice * _quantity;

  void _onConfirm() {
    if (!_allRequirementsMet) return;
    AppHaptics.light();
    final mods = _selectedModifiers;
    Navigator.pop(
      context,
      CustomizationResult(
        quantity: _quantity,
        unitPrice: _unitPrice,
        selectedModifierIds: mods.map((m) => m.id).toList(),
        selectedModifierNames: mods.map((m) => m.name).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final groups = item.modifierGroups;
    final canAdd = _allRequirementsMet;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20, 12, 20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Item header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: AppNetworkImage(
                            imageUrl: item.imageUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.restaurant_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          if (item.description != null) ...[
                            const SizedBox(height: 4),
                            Text(item.description!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ],
                          const SizedBox(height: 6),
                          Text('\u20B9${item.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emerald)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                // Modifier groups
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final group = groups[i];
                      return _buildGroup(context, i, group);
                    },
                  ),
                ),
                const Divider(height: 24),
                // Quantity stepper + Add to Cart
                Row(
                  children: [
                    // Quantity stepper
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            color: AppTheme.emerald,
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          Text('$_quantity',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            color: AppTheme.emerald,
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Add to Cart button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: canAdd
                            ? AppTheme.emerald
                            : AppTheme.emerald.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      onPressed: canAdd ? _onConfirm : null,
                      child: Text(
                        'Add to Cart \u00B7 \u20B9${_totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single modifier group with its label and options.
  Widget _buildGroup(BuildContext context, int groupIndex, ModifierGroup group) {
    final label = _groupLabel(group);
    final isSingle = group.isSingleChoice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group title + requirement label
          Row(
            children: [
              Text(group.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: group.isRequired
                      ? AppTheme.danger.withValues(alpha: 0.08)
                      : AppTheme.emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: group.isRequired ? AppTheme.danger : AppTheme.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Modifier options
          if (isSingle)
            ..._buildSingleChoiceOptions(groupIndex, group)
          else
            ..._buildMultiChoiceOptions(context, groupIndex, group),
        ],
      ),
    );
  }

  /// Radio buttons for single-choice groups (MinSelections == 1, MaxSelections == 1).
  List<Widget> _buildSingleChoiceOptions(int groupIndex, ModifierGroup group) {
    return [
      for (int i = 0; i < group.modifiers.length; i++)
        RadioListTile<int>(
          value: i,
          groupValue: _singleSelections[groupIndex],
          activeColor: AppTheme.emerald,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(group.modifiers[i].name),
          subtitle: group.modifiers[i].price > 0
              ? Text(
                  '+\u20B9${group.modifiers[i].price.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.emerald))
              : null,
          onChanged: group.modifiers[i].isAvailable
              ? (v) {
                  AppHaptics.selection();
                  setState(() => _singleSelections[groupIndex] = v ?? i);
                }
              : null,
        ),
    ];
  }

  /// Checkboxes for multi-choice groups (MinSelections == 0, MaxSelections > 0).
  List<Widget> _buildMultiChoiceOptions(
      BuildContext context, int groupIndex, ModifierGroup group) {
    final selected = _multiSelections.putIfAbsent(groupIndex, () => {});
    final maxSel = group.maxSelections;

    return [
      for (int i = 0; i < group.modifiers.length; i++)
        CheckboxListTile(
          value: selected.contains(i),
          activeColor: AppTheme.emerald,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(group.modifiers[i].name),
          subtitle: group.modifiers[i].price > 0
              ? Text(
                  '+\u20B9${group.modifiers[i].price.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.emerald))
              : null,
          // Disable unchecked items when max selections reached.
          onChanged: group.modifiers[i].isAvailable
              ? (checked) {
                  AppHaptics.selection();
                  setState(() {
                    if (checked == true) {
                      if (maxSel == 0 || selected.length < maxSel) {
                        selected.add(i);
                      } else if (maxSel == 1) {
                        // Replace the existing selection for max == 1
                        selected.clear();
                        selected.add(i);
                      }
                    } else {
                      selected.remove(i);
                    }
                  });
                }
              : null,
        ),
    ];
  }
}
