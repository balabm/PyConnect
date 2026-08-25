import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Quick operational toggles bottom sheet for Restaurant/Cafe/Pizzeria
/// vendors. Opens from the KDS screen and exposes three fast controls:
///
/// 1. **Store Status** — Open/Accepting Orders ↔ Paused/Too Busy
/// 2. **Busy Mode** — adds +30 min prep buffer to all consumer ETAs
/// 3. **Dynamic Prep Time** — custom 0–60 min ETA buffer
///
/// Each control fires the corresponding [VendorDashboardApi] method via
/// [vendorDashboardApiProvider] and shows a loading indicator while the
/// API call is in flight.
class QuickTogglesSheet extends ConsumerStatefulWidget {
  const QuickTogglesSheet({super.key});

  @override
  ConsumerState<QuickTogglesSheet> createState() => _QuickTogglesSheetState();
}

class _QuickTogglesSheetState extends ConsumerState<QuickTogglesSheet> {
  // --- In-flight flags (one per action so controls stay independent) ---
  bool _statusLoading = false;
  bool _busyLoading = false;
  bool _prepLoading = false;

  // --- Local UI state for the prep-time slider ---
  double _prepBuffer = 0; // minutes (0–60)

  // --- Snackbars ---
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.danger,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- API actions ---

  /// Toggles the master "Accepting Orders" status.
  /// `true` → resume accepting, `false` → pause.
  Future<void> _toggleStatus(bool accept) async {
    if (_statusLoading) return;
    AppHaptics.light();
    setState(() => _statusLoading = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final result = await api.toggleStatus(accept);
      if (!mounted) return;
      // Keep the provider in sync so the KDS screen reflects the change.
      ref.read(vendorAcceptingOrdersProvider.notifier).state = result;
      _showSuccess(
        accept ? 'Store is now accepting orders' : 'Store paused — too busy',
      );
    } catch (e) {
      _showError('Failed to update status: $e');
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  /// Toggles kitchen busy mode (+30 min ETA buffer).
  Future<void> _toggleBusyMode(bool busy) async {
    if (_busyLoading) return;
    AppHaptics.light();
    setState(() => _busyLoading = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.toggleBusyMode(busy);
      if (!mounted) return;
      _showSuccess(
        busy ? 'Busy mode ON — +30 min added to ETAs' : 'Busy mode OFF',
      );
    } catch (e) {
      _showError('Failed to toggle busy mode: $e');
    } finally {
      if (mounted) setState(() => _busyLoading = false);
    }
  }

  /// Sets a custom prep-time buffer (0–60 min) shown to consumers.
  Future<void> _setPrepBuffer() async {
    if (_prepLoading) return;
    AppHaptics.light();
    setState(() => _prepLoading = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.setPrepBuffer(_prepBuffer.round());
      if (!mounted) return;
      _showSuccess('Prep buffer set to ${_prepBuffer.round()} min');
    } catch (e) {
      _showError('Failed to set prep buffer: $e');
    } finally {
      if (mounted) setState(() => _prepLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final isAccepting = ref.watch(vendorAcceptingOrdersProvider);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Quick Toggles',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fast operational controls for your kitchen',
              style: TextStyle(fontSize: 13, color: onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // 1. Store Status
            // ─────────────────────────────────────────────
            _SectionLabel(label: 'Store Status'),
            const SizedBox(height: 10),
            _StoreStatusCard(
              isAccepting: isAccepting,
              loading: _statusLoading,
              onTap: () => _toggleStatus(!isAccepting),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // 2. Busy Mode
            // ─────────────────────────────────────────────
            _SectionLabel(label: 'Busy Mode'),
            const SizedBox(height: 10),
            _BusyModeCard(
              loading: _busyLoading,
              onChanged: (v) => _toggleBusyMode(v),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // 3. Dynamic Prep Time
            // ─────────────────────────────────────────────
            _SectionLabel(label: 'Dynamic Prep Time'),
            const SizedBox(height: 10),
            _PrepBufferCard(
              value: _prepBuffer,
              loading: _prepLoading,
              onChanged: (v) => setState(() => _prepBuffer = v),
              onSet: _setPrepBuffer,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Section label
// ════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 1. Store Status — large Open ↔ Paused toggle
// ════════════════════════════════════════════════════════════════════
class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard({
    required this.isAccepting,
    required this.loading,
    required this.onTap,
  });

  final bool isAccepting;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isAccepting ? AppTheme.emerald : AppTheme.danger;
    final bgColor = color.withValues(alpha: 0.1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Status icon / spinner
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: color,
                        ),
                      )
                    : Icon(
                        isAccepting
                            ? Icons.storefront_outlined
                            : Icons.pause_circle_outline,
                        size: 26,
                        color: color,
                      ),
              ),
              const SizedBox(width: 14),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAccepting
                          ? 'Open / Accepting Orders'
                          : 'Paused / Too Busy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAccepting
                          ? 'Tap to pause incoming orders'
                          : 'Tap to resume accepting orders',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle pill
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: loading
                    ? const SizedBox(
                        key: ValueKey('spinner'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        key: ValueKey(isAccepting),
                        isAccepting
                            ? Icons.toggle_on_outlined
                            : Icons.toggle_off_outlined,
                        size: 36,
                        color: color,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 2. Busy Mode — switch card
// ════════════════════════════════════════════════════════════════════
class _BusyModeCard extends StatefulWidget {
  const _BusyModeCard({
    required this.loading,
    required this.onChanged,
  });

  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  State<_BusyModeCard> createState() => _BusyModeCardState();
}

class _BusyModeCardState extends State<_BusyModeCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final color = _busy ? AppTheme.warning : AppTheme.slate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _busy ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: _busy ? 0.4 : 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: widget.loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: color,
                    ),
                  )
                : Icon(
                    Icons.local_fire_department_outlined,
                    size: 22,
                    color: color,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Busy Mode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Adds +30 min prep buffer to all ETAs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _busy,
            activeTrackColor: AppTheme.warning.withValues(alpha: 0.5),
            activeThumbColor: AppTheme.warning,
            onChanged: widget.loading
                ? null
                : (v) {
                    setState(() => _busy = v);
                    widget.onChanged(v);
                  },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 3. Dynamic Prep Time — slider + Set button
// ════════════════════════════════════════════════════════════════════
class _PrepBufferCard extends StatelessWidget {
  const _PrepBufferCard({
    required this.value,
    required this.loading,
    required this.onChanged,
    required this.onSet,
  });

  final double value;
  final bool loading;
  final ValueChanged<double> onChanged;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: AppTheme.emerald),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Custom Prep Buffer: ${value.round()} min',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              // Set button
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: loading ? null : onSet,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Set',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Slider
          Slider(
            value: value,
            min: 0,
            max: 60,
            divisions: 60,
            activeColor: AppTheme.emerald,
            inactiveColor: AppTheme.emerald.withValues(alpha: 0.2),
            label: '${value.round()} min',
            onChanged: loading ? null : onChanged,
          ),
          // Tick labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0 min',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '60 min',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Public entry point — call from the KDS screen
// ════════════════════════════════════════════════════════════════════

/// Opens the [QuickTogglesSheet] as a modal bottom sheet.
///
/// Call this from the KDS screen's app bar action or a floating button:
/// ```dart
/// showQuickTogglesSheet(context, ref);
/// ```
Future<void> showQuickTogglesSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QuickTogglesSheet(),
  );
}
