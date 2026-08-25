import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/design/design.dart';
import '../application/vendor_providers.dart';
import '../data/equipment_api.dart';

/// Equipment detail screen for a single [EquipmentItemModel].
///
/// Shows item details (name, category, pricing, deposit, availability) and
/// lets the vendor manage maintenance blocks: add new blocks via a date range
/// picker + reason dialog, and remove existing blocks with confirmation.
class EquipmentDetailScreen extends ConsumerStatefulWidget {
  const EquipmentDetailScreen({
    super.key,
    required this.item,
  });

  final EquipmentItemModel item;

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  late EquipmentItemModel _item;
  List<MaintenanceBlockModel> _blocks = [];
  bool _loadingBlocks = true;
  String? _blocksError;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    setState(() {
      _loadingBlocks = true;
      _blocksError = null;
    });
    try {
      final blocks =
          await ref.read(equipmentApiProvider).getBlocks(_item.id);
      if (mounted) {
        setState(() {
          _blocks = blocks;
          _loadingBlocks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBlocks = false;
          _blocksError = e.toString();
        });
      }
    }
  }

  // ── Add block flow ──

  Future<void> _addBlock() async {
    AppHaptics.light();
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select block date range',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.emerald,
              ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    if (!mounted) return;

    final reason = await _showReasonDialog();
    if (reason == null) return;
    if (!mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final created =
          await ref.read(equipmentApiProvider).blockDates(
                itemId: _item.id,
                startDate: picked.start,
                endDate: picked.end,
                reason: reason,
              );
      if (mounted) {
        setState(() {
          _blocks = [..._blocks, created];
          _actionInProgress = false;
        });
        AppHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dates blocked successfully'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block dates: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  /// Shows a dialog with a segmented control to pick a block reason.
  /// Returns the selected reason string, or null if cancelled.
  Future<String?> _showReasonDialog() {
    const reasons = ['Maintenance', 'Repair', 'Hold'];
    int selected = 0;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Block Reason'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why are these dates being blocked?',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('Maintenance'),
                    icon: Icon(Icons.build_outlined),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Repair'),
                    icon: Icon(Icons.handyman_outlined),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('Hold'),
                    icon: Icon(Icons.pause_circle_outline),
                  ),
                ],
                selected: {selected},
                onSelectionChanged: (set) {
                  AppHaptics.light();
                  setState(() => selected = set.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.coral.withValues(alpha: 0.15);
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.coral;
                    }
                    return Theme.of(ctx).colorScheme.onSurface;
                  }),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, reasons[selected]),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
              ),
              child: const Text('Block'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete block flow ──

  Future<void> _confirmDeleteBlock(MaintenanceBlockModel block) async {
    AppHaptics.light();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove block?'),
        content: Text(
          'This will unblock ${_formatDate(block.startDate)} – '
          '${_formatDate(block.endDate)} and make the unit available again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _deleteBlock(block);
  }

  Future<void> _deleteBlock(MaintenanceBlockModel block) async {
    setState(() => _actionInProgress = true);
    try {
      await ref.read(equipmentApiProvider).removeBlock(
            itemId: _item.id,
            blockId: block.id,
          );
      if (mounted) {
        setState(() {
          _blocks = _blocks.where((b) => b.id != block.id).toList();
          _actionInProgress = false;
        });
        AppHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Block removed'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove block: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  // ── Helpers ──

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  String _formatDateRange(DateTime start, DateTime end) {
    if (_isSameDay(start, end)) return _formatDate(start);
    return '${_formatDate(start)} – ${_formatDate(end)}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'Repair':
        return AppTheme.danger;
      case 'Hold':
        return AppTheme.coral;
      case 'Maintenance':
      default:
        return AppTheme.emerald;
    }
  }

  IconData _reasonIcon(String reason) {
    switch (reason) {
      case 'Repair':
        return Icons.handyman_outlined;
      case 'Hold':
        return Icons.pause_circle_outline;
      case 'Maintenance':
      default:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(_item.name),
            actions: [
              IconButton(
                tooltip: 'Refresh blocks',
                onPressed: _actionInProgress ? null : _loadBlocks,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadBlocks,
            color: AppTheme.emerald,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              children: [
                _buildDetailsCard(),
                const SizedBox(height: AppSpacing.sm),
                _buildBlocksSection(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
        if (_actionInProgress) const LoadingOverlay(message: 'Working...'),
      ],
    );
  }

  // ── Details card ──

  Widget _buildDetailsCard() {
    final soldOut = _item.availableUnits == 0;
    return AppCard(
      imageUrl: _item.imageUrl,
      imageHeight: 180,
      gradient: AppTheme.emeraldGradient,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (_item.isAvailable ? AppTheme.emerald : AppTheme.danger)
              .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          _item.isAvailable ? 'Available' : 'Unavailable',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _item.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.category_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                _item.category,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          if (_item.description != null && _item.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _item.description!,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _PriceChip(
                label: '₹${_item.dailyRentalPrice.toStringAsFixed(0)}/day',
                color: AppTheme.emerald,
                icon: Icons.payments_outlined,
              ),
              const SizedBox(width: AppSpacing.sm),
              _PriceChip(
                label:
                    'Deposit ₹${_item.securityDepositAmount.toStringAsFixed(0)}',
                color: AppTheme.coral,
                icon: Icons.security_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _AvailabilityBar(
            available: _item.availableUnits,
            total: _item.totalUnits,
            soldOut: soldOut,
          ),
        ],
      ),
    );
  }

  // ── Blocks section ──

  Widget _buildBlocksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.event_busy,
                      size: 20, color: AppTheme.coral),
                  const SizedBox(width: AppSpacing.xs),
                  const Text(
                    'Block Dates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _actionInProgress ? null : _addBlock,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Block'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Block dates for maintenance, repairs, or holds to prevent bookings.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBlocksBody(),
        ],
      ),
    );
  }

  Widget _buildBlocksBody() {
    if (_loadingBlocks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.emerald),
        ),
      );
    }

    if (_blocksError != null) {
      return ErrorState(
        message: _blocksError!,
        onRetry: _loadBlocks,
      );
    }

    if (_blocks.isEmpty) {
      return EmptyState(
        icon: Icons.event_available,
        title: 'No active blocks',
        subtitle:
            'This equipment is bookable on all dates. Add a block to take it offline for maintenance.',
        actionLabel: 'Add Block',
        onAction: _addBlock,
      );
    }

    return Column(
      children: _blocks.map(_buildBlockTile).toList(),
    );
  }

  Widget _buildBlockTile(MaintenanceBlockModel block) {
    final color = _reasonColor(block.reason);
    final isPast = block.endDate.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            AppHaptics.light();
            if (block.notes != null && block.notes!.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(block.notes!)),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 4),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(_reasonIcon(block.reason), color: color, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            block.reason,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          if (isPast) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: const Text(
                                'PAST',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateRange(block.startDate, block.endDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (block.notes != null &&
                          block.notes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          block.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove block',
                  onPressed: _actionInProgress
                      ? null
                      : () => _confirmDeleteBlock(block),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppTheme.danger,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ──

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBar extends StatelessWidget {
  const _AvailabilityBar({
    required this.available,
    required this.total,
    required this.soldOut,
  });

  final int available;
  final int total;
  final bool soldOut;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : available / total;
    final color = soldOut
        ? AppTheme.danger
        : ratio < 0.5
            ? AppTheme.coral
            : AppTheme.emerald;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Availability',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '$available / $total units',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
