import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/cross_sell_api.dart';

final crossSellApiProvider = Provider<CrossSellApi>((ref) {
  return CrossSellApi(ref.watch(apiClientProvider));
});

/// Shows a ride upsell bottom sheet after a booking confirmation.
/// Fetches the upsell suggestion from the backend and presents it
/// with a "Book Ride" CTA that navigates to the transit tab.
Future<void> showRideUpsellSheet(
  BuildContext context,
  WidgetRef ref,
  String bookingId,
) async {
  final suggestion = await ref.read(crossSellApiProvider).getRideUpsell(bookingId);
  if (!context.mounted || suggestion == null) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _RideUpsellSheet(suggestion: suggestion),
  );
}

class _RideUpsellSheet extends ConsumerWidget {
  const _RideUpsellSheet({required this.suggestion});
  final RideUpsellSuggestionModel suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupTime = _formatTime(suggestion.pickupTime);
    final eventTime = _formatTime(suggestion.eventTime);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_taxi, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Need a ride?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Get to ${suggestion.venueName} on time. We suggest booking a ride for $pickupTime — 30 minutes before your event at $eventTime.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Discount badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: AppTheme.gold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    suggestion.discountText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Maybe later'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    AppHaptics.light();
                    Navigator.pop(context);
                    context.go('/transit');
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.emerald,
                  ),
                  child: const Text('Book Ride'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
