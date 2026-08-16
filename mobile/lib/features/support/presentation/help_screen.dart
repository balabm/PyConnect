import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import 'sos_bottom_sheet.dart';

/// Simple help & support screen showing emergency contacts and a way to
/// reach support. Reuses the existing SOS support flow where possible.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency, color: AppTheme.danger, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Trigger SOS to alert your emergency contacts with your live location.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Emergency contacts management
          _HelpTile(
            icon: Icons.contact_phone_outlined,
            color: AppTheme.info,
            title: 'Emergency Contacts',
            subtitle: 'Manage contacts notified during an SOS',
            onTap: () {
              AppHaptics.light();
              context.push('/rides/emergency-contacts');
            },
          ),
          const SizedBox(height: 10),

          // SOS / Report issue
          _HelpTile(
            icon: Icons.sos,
            color: AppTheme.danger,
            title: 'Send SOS / Report Issue',
            subtitle: 'Scooter breakdown, payment, or safety concern',
            onTap: () {
              AppHaptics.light();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SosBottomSheet(),
              );
            },
          ),
          const SizedBox(height: 10),

          // Contact support
          _HelpTile(
            icon: Icons.support_agent,
            color: AppTheme.emerald,
            title: 'Contact Support',
            subtitle: 'Call or email the PY Connect support team',
            onTap: () => _showContactSupport(context),
          ),
          const SizedBox(height: 24),

          // Quick info
          Text(
            'Quick Help',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _HelpTile(
            icon: Icons.two_wheeler_outlined,
            color: AppTheme.warning,
            title: 'Scooter Rental Issues',
            subtitle: 'Breakdowns, lock problems, or return help',
            onTap: () => context.push('/rentals'),
          ),
          const SizedBox(height: 10),
          _HelpTile(
            icon: Icons.receipt_long_outlined,
            color: AppTheme.info,
            title: 'My Activity',
            subtitle: 'View your rides, orders, and bookings',
            onTap: () => context.push('/activity'),
          ),
        ],
      ),
    );
  }

  void _showContactSupport(BuildContext context) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppTheme.emerald),
              title: const Text('Call Support'),
              subtitle: const Text('+91 99999 99999'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: AppTheme.info),
              title: const Text('Email Support'),
              subtitle: const Text('support@pyconnect.run.place'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
