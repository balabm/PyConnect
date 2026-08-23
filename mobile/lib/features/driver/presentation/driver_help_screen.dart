import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

/// Help & Support screen for the Captain app.
///
/// This is a placeholder screen that honestly tells the driver which
/// support channels are planned but not yet available. No mock data —
/// just a truthful "coming soon" state with a direct phone link to
/// PY Connect support.
class DriverHelpScreen extends StatelessWidget {
  const DriverHelpScreen({super.key});

  static const _plannedFeatures = [
    {
      'icon': Icons.quiz_outlined,
      'title': 'FAQs',
      'description': 'Answers to common questions about payouts, ride acceptance, and account issues.',
    },
    {
      'icon': Icons.report_problem_outlined,
      'title': 'Report an Issue',
      'description': 'Report a problem with a ride, payment, or app behavior. Tracked until resolved.',
    },
    {
      'icon': Icons.chat_outlined,
      'title': 'Live Chat',
      'description': 'Chat with PY Connect support in real time during operating hours.',
    },
    {
      'icon': Icons.feedback_outlined,
      'title': 'Send Feedback',
      'description': 'Share your suggestions to help us improve the Captain experience.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Direct support contact
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone, color: AppTheme.emerald, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Need help right now?',
                        style: TextStyle(
                          color: AppTheme.emerald,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Call PY Connect support directly. We are here to help with any issues you face on the road.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _callSupport(context),
                  icon: const Icon(Icons.call),
                  label: const Text('Call Support'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Coming Soon',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._plannedFeatures.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlannedFeatureCard(
                  icon: f['icon'] as IconData,
                  title: f['title'] as String,
                  description: f['description'] as String,
                ),
              )),
        ],
      ),
    );
  }

  void _callSupport(BuildContext context) async {
    const phoneNumber = 'tel:+919000000000';
    final uri = Uri.parse(phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }
}

class _PlannedFeatureCard extends StatelessWidget {
  const _PlannedFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
