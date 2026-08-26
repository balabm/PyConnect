import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

/// Help & Support screen for the Captain app.
/// Provides FAQs, direct support call, issue reporting, and feedback.
class DriverHelpScreen extends StatelessWidget {
  const DriverHelpScreen({super.key});

  static const _faqs = [
    {
      'q': 'How do I receive my earnings?',
      'a': 'Your earnings are credited to your driver wallet after each completed ride. You can request a withdrawal from the Earnings screen once you reach the minimum payout of ₹100.',
    },
    {
      'q': 'Why was my ride request cancelled?',
      'a': 'Ride requests may be cancelled by the rider or automatically if you do not accept within the timeout window. Cancelled rides do not affect your earnings.',
    },
    {
      'q': 'How do I update my vehicle details?',
      'a': 'Go to Profile > Garage to update your vehicle information. Changes require admin approval before they take effect.',
    },
    {
      'q': 'What is the SOS button?',
      'a': 'The SOS button is a safety feature that alerts PY Connect support and emergency services with your live location. Long-press for 3 seconds to activate.',
    },
    {
      'q': 'How do I go offline?',
      'a': 'Toggle the "Go Online" switch on your dashboard to stop receiving new ride requests. You will still complete any active ride.',
    },
    {
      'q': 'Why is my account pending approval?',
      'a': 'New drivers must complete KYC verification and be approved by our admin team. This typically takes 1-2 business days. Check the KYC screen for status updates.',
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
          // Quick actions
          Row(
            children: [
              Expanded(
                child: _HelpActionCard(
                  icon: Icons.report_problem_outlined,
                  title: 'Report Issue',
                  color: AppTheme.danger,
                  onTap: () => context.push('/tickets/new'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HelpActionCard(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  color: AppTheme.emerald,
                  onTap: () => context.push('/tickets/new?type=feedback'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // FAQs
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => _FaqCard(
                question: faq['q']!,
                answer: faq['a']!,
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

class _HelpActionCard extends StatelessWidget {
  const _HelpActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(widget.question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          color: AppTheme.emerald,
        ),
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              widget.answer,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
