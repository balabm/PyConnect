import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/application/driver_providers.dart';
import '../application/auth_controller.dart';

/// A severe, non-dismissible bottom sheet for the "Right to be Forgotten"
/// account deletion flow. Requires the user to type the word "DELETE" to
/// confirm, preventing accidental data destruction.
///
/// On success, clears all local state and routes to the splash/auth screen
/// with a confirmation message.
class DeleteAccountSheet {
  DeleteAccountSheet._();

  /// Shows the delete account bottom sheet.
  /// Set [isDriver] to true to show driver-specific messaging (KYC docs
  /// will be shredded from cloud storage).
  static Future<bool?> show(BuildContext context, WidgetRef ref, {bool isDriver = false}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DeleteAccountContent(ref: ref, isDriver: isDriver),
    );
  }
}

class _DeleteAccountContent extends ConsumerStatefulWidget {
  const _DeleteAccountContent({required this.ref, required this.isDriver});

  final WidgetRef ref;
  final bool isDriver;

  @override
  ConsumerState<_DeleteAccountContent> createState() => _DeleteAccountContentState();
}

class _DeleteAccountContentState extends ConsumerState<_DeleteAccountContent> {
  final _confirmController = TextEditingController();
  bool _processing = false;
  bool _canConfirm = false;

  static const _confirmWord = 'DELETE';

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() {
      final canConfirm = _confirmController.text.trim().toUpperCase() == _confirmWord;
      if (canConfirm != _canConfirm) {
        setState(() => _canConfirm = canConfirm);
      }
    });
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _executeDeletion() async {
    AppHaptics.heavy();
    setState(() => _processing = true);

    try {
      // Call the appropriate deletion endpoint based on app type.
      if (widget.isDriver) {
        // The driver auth controller doesn't have a deleteAccount method,
        // so we call the driver API directly and then clear local state.
        await widget.ref.read(driverApiProvider).deleteAccount();
      } else {
        await widget.ref.read(authControllerProvider.notifier).deleteAccount();
      }

      // Clear all local state regardless of which endpoint was called.
      await widget.ref.read(authControllerProvider.notifier).signOut();

      if (mounted) {
        AppHaptics.success();
        // Show success message and route to splash/auth screen.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your data has been successfully removed.'),
            backgroundColor: AppTheme.emerald,
            duration: Duration(seconds: 4),
          ),
        );
        // Navigate to the splash/auth screen, clearing the entire nav stack.
        context.go('/auth');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, false);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Warning icon
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever, size: 36, color: AppTheme.danger),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Center(
            child: Text(
              'Delete Account & Data',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.danger,
                  ),
            ),
          ),
          const SizedBox(height: 20),

          // Severe warning text
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action is permanent and cannot be undone.',
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isDriver
                      ? 'All your saved addresses, wallet balances, active promos, and KYC documents '
                        '(Aadhaar, Driving License, RC, Insurance, Selfie) will be permanently destroyed '
                        'and shredded from cloud storage. Your past rides and earnings will be kept for '
                        'tax auditing but anonymized.'
                      : 'All your saved addresses, wallet balances, and active promos will be destroyed. '
                        'Your past orders and rides will be kept for financial auditing but anonymized — '
                        'severed from your identity forever.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confirmation text field
          Text(
            'Type "$_confirmWord" to confirm:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enabled: !_processing,
            decoration: InputDecoration(
              hintText: _confirmWord,
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _canConfirm ? AppTheme.danger : AppTheme.danger.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              errorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.danger),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processing ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _canConfirm ? AppTheme.danger : AppTheme.danger.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_canConfirm && !_processing) ? _executeDeletion : null,
                  child: _processing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Delete Forever'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
