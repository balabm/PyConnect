import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

final emergencyContactsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(ridesApiProvider);
  return await api.listEmergencyContacts();
});

class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends ConsumerState<EmergencyContactsScreen> {
  void _addContact() {
    AppHaptics.light();
    showDialog(context: context, builder: (ctx) => _AddContactDialog(onSave: (name, phone, relationship) async {
      final api = ref.read(ridesApiProvider);
      try {
        await api.addEmergencyContact(name, phone, relationship: relationship);
        ref.invalidate(emergencyContactsProvider);
        if (ctx.mounted) {
          AppHaptics.success();
          Navigator.pop(ctx);
        }
      } catch (e) {
        if (ctx.mounted) {
          AppHaptics.error();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: AppTheme.coral,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: contactsAsync.when(
        loading: () => const ShimmerList(withImage: false, count: 4),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(emergencyContactsProvider),
        ),
        data: (contacts) => Column(
          children: [
            // Info banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppTheme.coral.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.coral, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These contacts will be notified with your live location when you trigger SOS during a ride.',
                      style: TextStyle(color: AppTheme.coral, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (contacts.isEmpty)
              const Expanded(
                child: EmptyState(
                  icon: Icons.contact_phone,
                  title: 'No emergency contacts',
                  subtitle: 'Add trusted contacts who will be notified during emergencies',
                  actionLabel: 'Add Contact',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final contact = contacts[index] as Map<String, dynamic>;
                    final name = contact['name'] as String? ?? '';
                    final phone = contact['phone'] as String? ?? '';
                    final relationship = contact['relationship'] as String?;
                    return FadeSlideIn(
                      delay: Duration(milliseconds: index * 50),
                      child: _ContactCard(
                        name: name,
                        phone: phone,
                        relationship: relationship,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.name,
    required this.phone,
    this.relationship,
  });

  final String name;
  final String phone;
  final String? relationship;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardShadow
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            AppHaptics.light();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: AppTheme.danger, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        relationship != null ? '$phone · $relationship' : phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.phone, color: AppTheme.lagoon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog({required this.onSave});
  final Future<void> Function(String name, String phone, String? relationship) onSave;

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _relationship;
  bool _saving = false;

  static const _relationships = ['Parent', 'Spouse', 'Sibling', 'Friend', 'Relative'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Emergency Contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number', prefixText: '+91 ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _relationship,
            decoration: const InputDecoration(labelText: 'Relationship (optional)', border: OutlineInputBorder()),
            items: _relationships.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) {
              AppHaptics.selection();
              setState(() => _relationship = val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : () async {
            if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;
            AppHaptics.medium();
            setState(() => _saving = true);
            await widget.onSave(_nameController.text, _phoneController.text, _relationship);
          },
          child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
