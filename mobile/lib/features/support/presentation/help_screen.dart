import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../data/support_api.dart';
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
          const SizedBox(height: 10),
          _HelpTile(
            icon: Icons.support_agent_outlined,
            color: AppTheme.emerald,
            title: 'Raise a Ticket',
            subtitle: 'Report a missing item, payment, or service issue',
            onTap: () {
              AppHaptics.light();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _TicketTriageSheet(),
              );
            },
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

class _TicketTriageSheet extends ConsumerStatefulWidget {
  const _TicketTriageSheet();

  @override
  ConsumerState<_TicketTriageSheet> createState() => _TicketTriageSheetState();
}

class _TicketTriageSheetState extends ConsumerState<_TicketTriageSheet> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _orderIdController = TextEditingController();

  String? _category;
  bool _isSubmitting = false;

  static const _categories = [
    ('Item Missing', 'ItemMissing'),
    ('Driver Professionalism', 'DriverProfessionalism'),
    ('Food Quality', 'FoodQuality'),
    ('Payment Issue', 'PaymentIssue'),
  ];

  static const _subjectHints = {
    'ItemMissing': 'An item was missing from my order',
    'DriverProfessionalism': 'Issue with driver behaviour',
    'FoodQuality': 'Food quality was not acceptable',
    'PaymentIssue': 'I have a payment or refund problem',
  };

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _photoUrlController.dispose();
    _orderIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Raise a Ticket',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'What is your issue about?',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((c) => ChoiceChip(
                  label: Text(c.$1),
                  selected: _category == c.$2,
                  onSelected: (_) => _selectCategory(c.$2),
                )).toList(),
              ),
              if (_category != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _photoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _orderIdController,
                  decoration: const InputDecoration(
                    labelText: 'Order ID (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit Ticket'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _selectCategory(String value) {
    AppHaptics.light();
    setState(() {
      _category = value;
      _subjectController.text = _subjectHints[value] ?? '';
    });
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject and description.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await ref.read(supportApiProvider).createTicket(
        CreateTicketRequest(
          category: _category!,
          subject: subject,
          description: description,
          orderId: _orderIdController.text.trim().isEmpty
              ? null
              : _orderIdController.text.trim(),
          orderType: null,
          photoUrl: _photoUrlController.text.trim().isEmpty
              ? null
              : _photoUrlController.text.trim(),
        ),
      );

      if (mounted) {
        final message = response.autoResolved
            ? 'We have credited \u{20B9}${response.creditAmount?.toStringAsFixed(0) ?? '0'} to your wallet.'
            : 'Your ticket has been raised. We will review it shortly.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: response.autoResolved ? AppTheme.emerald : AppTheme.info,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to raise ticket: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
