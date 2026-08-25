import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/haptic.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/driver_providers.dart';

/// A "Safe Drive" quick chat bottom sheet for the Driver (Captain) app.
///
/// Provides one-tap canned responses so the captain can communicate with the
/// customer without typing while riding. Each canned message is a full-width
/// card with an icon and the message text — a single tap sends it via the
/// driver API and closes the sheet. A separate [Call Customer] button at the
/// bottom initiates a masked-number call through the backend.
class QuickChatSheet extends ConsumerStatefulWidget {
  const QuickChatSheet({super.key});

  /// Displays the [QuickChatSheet] as a modal bottom sheet.
  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const QuickChatSheet(),
    );
  }

  @override
  ConsumerState<QuickChatSheet> createState() => _QuickChatSheetState();
}

class _QuickChatSheetState extends ConsumerState<QuickChatSheet> {
  /// Canned response definitions: icon + message text.
  static const _cannedMessages = <_CannedMessage>[
    _CannedMessage(
      icon: Icons.location_on,
      text: 'I am at the pickup location',
    ),
    _CannedMessage(
      icon: Icons.traffic,
      text: 'Traffic is heavy, slightly delayed',
    ),
    _CannedMessage(
      icon: Icons.place,
      text: 'Please share a landmark',
    ),
    _CannedMessage(
      icon: Icons.timer,
      text: 'I am on the way, arriving soon',
    ),
    _CannedMessage(
      icon: Icons.call,
      text: 'Please call me when ready',
    ),
    _CannedMessage(
      icon: Icons.check_circle,
      text: 'Order picked up, on the way to you',
    ),
  ];

  bool _isSending = false;
  bool _isCalling = false;

  // ── Actions ────────────────────────────────────────────────────────

  Future<void> _sendQuickMessage(String message) async {
    if (_isSending) return;
    final activeTask = ref.read(activeTaskProvider);
    final rideId = activeTask?.id;
    if (rideId == null) {
      _showSnackBar('No active ride', color: AppTheme.warning);
      return;
    }

    AppHaptics.light();
    if (mounted) setState(() => _isSending = true);

    try {
      final api = ref.read(driverApiProvider);
      await api.sendQuickMessage(rideId, message);
      AppHaptics.success();
      if (mounted) {
        _showSnackBar('Sent!', color: AppTheme.emerald);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to send. Try again.', color: AppTheme.danger);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _initiateCall() async {
    if (_isCalling) return;
    final activeTask = ref.read(activeTaskProvider);
    final rideId = activeTask?.id;
    if (rideId == null) {
      _showSnackBar('No active ride', color: AppTheme.warning);
      return;
    }

    AppHaptics.medium();
    if (mounted) setState(() => _isCalling = true);

    try {
      final api = ref.read(driverApiProvider);
      final result = await api.initiateCall(rideId);
      final virtualNumber = result['virtualNumber'] as String? ?? 'Unknown';
      AppHaptics.success();
      if (mounted) {
        _showSnackBar(
          'Calling customer via $virtualNumber',
          color: AppTheme.info,
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Call failed. Try again.', color: AppTheme.danger);
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

  void _showSnackBar(String message, {required Color color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeTask = ref.watch(activeTaskProvider);
    final hasActiveRide = activeTask != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.slate.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title.
            const Text(
              'Quick Message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to send. No typing needed.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate,
              ),
            ),
            const SizedBox(height: 20),

            if (!hasActiveRide) ...[
              _NoActiveRide(),
            ] else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _cannedMessages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final msg = _cannedMessages[index];
                    return _CannedMessageCard(
                      icon: msg.icon,
                      text: msg.text,
                      onTap: _isSending ? null : () => _sendQuickMessage(msg.text),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Call Customer button.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCalling ? null : _initiateCall,
                  icon: _isCalling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.phone_in_talk),
                  label: const Text(
                    'Call Customer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.info,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.info.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single full-width canned response card with a large icon and message.
class _CannedMessageCard extends StatelessWidget {
  const _CannedMessageCard({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.offWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.emerald, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.slate,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state shown when there is no active ride.
class _NoActiveRide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline, color: AppTheme.warning, size: 36),
          SizedBox(height: 12),
          Text(
            'No active ride',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.charcoal,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Accept a task to send quick messages.',
            style: TextStyle(fontSize: 13, color: AppTheme.slate),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Internal model for a canned message definition.
class _CannedMessage {
  const _CannedMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;
}
