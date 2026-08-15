import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// A modal bottom sheet that presents the liability waiver and asks the
/// user to accept it. Calls POST /api/auth/waiver/accept on acceptance.
///
/// Returns `true` if the user accepted the waiver, `null` if dismissed.
class WaiverSheet extends ConsumerStatefulWidget {
  const WaiverSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const WaiverSheet(),
    );
  }

  @override
  ConsumerState<WaiverSheet> createState() => _WaiverSheetState();
}

class _WaiverSheetState extends ConsumerState<WaiverSheet> {
  bool _accepted = false;
  bool _submitting = false;

  Future<void> _acceptWaiver() async {
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      await ref.read(authApiProvider).acceptWaiver();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept waiver. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 12,
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
          // Title
          Row(
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.emerald, size: 24),
              const SizedBox(width: 8),
              Text(
                'Liability Waiver',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Waiver text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'By using PY Connect\'s ride-hailing, scooter rental, and '
              'adventure booking services, you acknowledge that these '
              'activities carry inherent risks. You accept full '
              'responsibility for your safety and agree to release PY Connect '
              'and its partners from any liability arising from your '
              'participation. You confirm that you are 18+ years of age, '
              'physically fit, and will follow all safety instructions '
              'provided by drivers, captains, and service partners.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Checkbox
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            title: const Text(
              'I have read and accept the liability waiver',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            activeColor: AppTheme.emerald,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          // Accept button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _accepted && !_submitting ? _acceptWaiver : null,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Accept & Continue'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
