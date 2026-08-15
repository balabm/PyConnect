import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Floating SOS button for ride safety. Requires long-press to trigger
/// (prevents accidental activation). Shows confirmation dialog before
/// sending the alert.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onTrigger,
    this.active = false,
  });

  final VoidCallback onTrigger;
  final bool active;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: AppTheme.danger.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'SOS Active — Help is on the way',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => setState(() => _pressing = true),
      onLongPressEnd: (_) {
        if (_pressing) {
          setState(() => _pressing = false);
          _showConfirmDialog();
        }
      },
      onLongPressCancel: () => setState(() => _pressing = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _pressing ? AppTheme.danger.withValues(alpha: 0.85) : AppTheme.danger,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: AppTheme.danger.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              _pressing ? 'Keep holding...' : 'SOS',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trigger SOS?'),
        content: const Text(
          'This will alert your emergency contacts with your live location and notify support. '
          'Only use in a genuine emergency.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onTrigger();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Trigger SOS'),
          ),
        ],
      ),
    );
  }
}
