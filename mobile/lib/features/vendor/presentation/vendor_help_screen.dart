import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';

/// Help & Support screen for the Partner app.
/// Provides FAQs, direct support call, and dispute information.
class VendorHelpScreen extends StatelessWidget {
  const VendorHelpScreen({super.key});

  static const _faqs = [
    {
      'q': 'How do I add a new menu item?',
      'a': 'Go to Menu > tap the + button > fill in name, price, category, and optional details like prep time, dietary tags, and image URL.',
    },
    {
      'q': 'How do I pause accepting orders?',
      'a': 'Tap the "Accepting Orders" toggle in the top bar of your dashboard. This instantly pauses all incoming orders. You can also use Quick Toggles from the KDS screen.',
    },
    {
      'q': 'When do I receive my payouts?',
      'a': 'Payouts are processed weekly. You can view your earnings and request withdrawals from the Finance screen. The minimum payout is ₹500.',
    },
    {
      'q': 'How do I create a promotion?',
      'a': 'Go to Marketing > Promotions > tap "Create Promotion" or "Create Flash Promo" to set up discounts and time-limited offers.',
    },
    {
      'q': 'What is the KDS?',
      'a': 'The Kitchen Display System (KDS) shows all active orders in real-time. Orders flow through Incoming → Preparing → Ready stages. You can mark items unavailable with automatic partial refunds.',
    },
    {
      'q': 'How do I handle a customer dispute?',
      'a': 'Go to Manage > Disputes to view and respond to all customer disputes and chargebacks. You can approve refunds or contest claims directly.',
    },
    {
      'q': 'How do I update my venue details?',
      'a': 'Go to Manage > Venue to update your venue name, address, photos, operating hours, and capacity settings.',
    },
    {
      'q': 'What is Busy Mode?',
      'a': 'Busy Mode adds a +30 minute prep buffer to all customer-facing ETAs. Enable it during rush hours to set realistic expectations and reduce complaints.',
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
              gradient: LinearGradient(
                colors: [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.support_agent, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need help? We\'re here for you',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Our partner support team is available 7 days a week',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          AppHaptics.light();
                          _launchPhone(context);
                        },
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call Support'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.emerald,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          AppHaptics.light();
                          context.push('/disputes');
                        },
                        icon: const Icon(Icons.gavel, size: 18),
                        label: const Text('View Disputes'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // FAQs
          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => _FaqTile(question: faq['q']!, answer: faq['a']!)),
          const SizedBox(height: 24),
          // Quick links
          Text(
            'Quick Links',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _QuickLink(
            icon: Icons.campaign,
            title: 'Create a Promotion',
            onTap: () {
              AppHaptics.light();
              context.push('/promotions');
            },
          ),
          _QuickLink(
            icon: Icons.people,
            title: 'Manage Staff',
            onTap: () {
              AppHaptics.light();
              context.push('/staff');
            },
          ),
          _QuickLink(
            icon: Icons.account_balance,
            title: 'View Finance & Payouts',
            onTap: () {
              AppHaptics.light();
              context.push('/finance');
            },
          ),
          _QuickLink(
            icon: Icons.reviews,
            title: 'View Customer Reviews',
            onTap: () {
              AppHaptics.light();
              context.push('/reviews');
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _launchPhone(BuildContext context) async {
    final url = Uri.parse('tel:+914132233445');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer. Please call +91-413-223-3445'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        onExpansionChanged: (v) {
          if (v) AppHaptics.light();
          setState(() => _expanded = v);
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          widget.question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: _expanded ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            widget.answer,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.emerald, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
