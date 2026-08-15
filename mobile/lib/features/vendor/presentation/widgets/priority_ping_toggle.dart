import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/vendor_dashboard_api.dart';

class PriorityPingToggle extends StatefulWidget {
  const PriorityPingToggle({
    super.key,
    required this.venueId,
    required this.api,
    required this.isActive,
    required this.onActivated,
  });

  final String venueId;
  final VendorDashboardApi api;
  final bool isActive;
  final void Function(ActivatePriorityResult result) onActivated;

  @override
  State<PriorityPingToggle> createState() => _PriorityPingToggleState();
}

class _PriorityPingToggleState extends State<PriorityPingToggle> {
  bool _loading = false;

  Future<void> _onToggle(bool value) async {
    if (!value || widget.isActive) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Boost Visibility', style: TextStyle(color: Colors.white)),
        content: Text(
          'Activate Priority Ping for 7 days?\n\n'
          'Cost: \u20B9499 (deducted from your credit balance).\n'
          'Your venue will appear at the top of nearby search results.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final result = await widget.api.activatePriority(widget.venueId);
      widget.onActivated(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppTheme.emerald : AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.emerald),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: widget.isActive
            ? LinearGradient(
                colors: [
                  AppTheme.emerald.withValues(alpha: 0.15),
                  AppTheme.emeraldLight.withValues(alpha: 0.05),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: widget.isActive ? null : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isActive
              ? AppTheme.emerald.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.rocket_launch, color: AppTheme.emerald, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Boost Visibility',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.isActive
                      ? 'Priority Ping active — top of search results'
                      : 'Appear at the top of nearby search results',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald),
            )
          else
            Switch(
              value: widget.isActive,
              activeThumbColor: AppTheme.emerald,
              activeTrackColor: AppTheme.emerald.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.white.withValues(alpha: 0.5),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              onChanged: _onToggle,
            ),
        ],
      ),
    );
  }
}
