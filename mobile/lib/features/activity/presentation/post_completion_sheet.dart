import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// A non-dismissible bottom sheet shown after a ride or food order completes.
/// Lets the user rate the driver/vendor (1–5 stars), leave optional feedback,
/// and add a quick tip (₹20 / ₹50 / ₹100 / custom).
///
/// Call [PostCompletionSheet.show] with the relevant context and identifiers.
class PostCompletionSheet extends ConsumerStatefulWidget {
  const PostCompletionSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.driverId,
    this.vendorId,
    this.rideId,
    this.orderId,
  });

  /// The entity name to show in the sheet header (e.g. "Your driver" or "Your order").
  final String title;
  final String? subtitle;

  /// Target identifiers — at least one of driverId / vendorId should be set,
  /// along with the corresponding rideId / orderId.
  final String? driverId;
  final String? vendorId;
  final String? rideId;
  final String? orderId;

  /// Convenience launcher — shows the sheet as a non-dismissible modal bottom
  /// sheet. Returns when the user submits or skips.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? driverId,
    String? vendorId,
    String? rideId,
    String? orderId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostCompletionSheet(
        title: title,
        subtitle: subtitle,
        driverId: driverId,
        vendorId: vendorId,
        rideId: rideId,
        orderId: orderId,
      ),
    );
  }

  @override
  ConsumerState<PostCompletionSheet> createState() => _PostCompletionSheetState();
}

class _PostCompletionSheetState extends ConsumerState<PostCompletionSheet> {
  int _rating = 0;
  final _feedbackController = TextEditingController();
  double? _selectedTip;
  bool _showCustomTip = false;
  final _customTipController = TextEditingController();
  bool _submitting = false;

  static const _quickTips = [20.0, 50.0, 100.0];

  @override
  void dispose() {
    _feedbackController.dispose();
    _customTipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }

    AppHaptics.light();
    setState(() => _submitting = true);

    final tipAmount = _selectedTip;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/reviews', data: {
        'rating': _rating,
        'feedback': _feedbackController.text.trim().isEmpty
            ? null
            : _feedbackController.text.trim(),
        'tipAmount': tipAmount,
        'driverId': widget.driverId,
        'vendorId': widget.vendorId,
        'rideId': widget.rideId,
        'orderId': widget.orderId,
      });

      if (mounted) {
        AppHaptics.success();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your rating!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _skip() {
    AppHaptics.light();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle (visual only — sheet is not draggable)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Rate ${widget.title}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            // Interactive 5-star rating bar
            _StarRatingBar(
              rating: _rating,
              onChanged: (value) {
                AppHaptics.selection();
                setState(() => _rating = value);
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // Optional feedback text field
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              maxLength: 500,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Feedback (optional)',
                hintText: 'Tell us about your experience...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Tip section
            Text(
              'Add a tip',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '100% of your tip goes to your driver/partner',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final amount in _quickTips)
                  _TipChip(
                    label: '\u20B9${amount.toStringAsFixed(0)}',
                    selected: _selectedTip == amount && !_showCustomTip,
                    onTap: () {
                      AppHaptics.light();
                      setState(() {
                        _selectedTip = amount;
                        _showCustomTip = false;
                      });
                    },
                  ),
                _TipChip(
                  label: 'Custom',
                  selected: _showCustomTip,
                  onTap: () {
                    AppHaptics.light();
                    setState(() {
                      _showCustomTip = true;
                      _selectedTip = null;
                    });
                  },
                ),
              ],
            ),
            if (_showCustomTip) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _customTipController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Custom tip amount',
                  prefixText: '\u20B9 ',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  setState(() => _selectedTip = parsed);
                },
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),

            // Submit + Skip buttons
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.star),
              label: const Text('Submit Rating'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _submitting ? null : _skip,
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable 5-star interactive rating bar.
class _StarRatingBar extends StatelessWidget {
  const _StarRatingBar({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              starValue <= rating ? Icons.star : Icons.star_border,
              size: 48,
              color: AppTheme.gold,
            ),
          ),
        );
      }),
    );
  }
}

/// A selectable tip amount chip.
class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.emerald.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppTheme.emerald : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.emerald : AppTheme.charcoal,
          ),
        ),
      ),
    );
  }
}
