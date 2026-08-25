import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/design/design.dart';
import '../application/vendor_providers.dart';

/// Staff Management screen for vendors to manage their staff (bouncers,
/// kitchen staff, managers) with restricted app access.
///
/// Loads the staff list on init, shows each member with name, phone, role
/// badge, and active/inactive status. A [FloatingActionButton.extended] opens
/// a bottom-sheet form to add new staff. Each card has a popup menu to
/// activate/deactivate a member.
class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load the staff list on init.
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final list = await api.getStaff();
      if (!mounted) return;
      setState(() {
        _staff = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> staff) async {
    final staffId = (staff['id'] ?? staff['staffId'] ?? '').toString();
    final isActive = staff['isActive'] == true;
    final name = (staff['name'] ?? '').toString();

    AppHaptics.light();
    // Optimistic update
    setState(() {
      final idx = _staff.indexWhere((s) =>
          (s['id'] ?? s['staffId'] ?? '').toString() == staffId);
      if (idx >= 0) {
        _staff[idx] = {..._staff[idx], 'isActive': !isActive};
      }
    });

    try {
      await ref.read(vendorDashboardApiProvider).removeStaff(staffId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive
              ? '$name deactivated'
              : '$name activated'),
          backgroundColor:
              isActive ? AppTheme.warning : AppTheme.emerald,
        ),
      );
    } catch (e) {
      // Revert on failure
      if (!mounted) return;
      setState(() {
        final idx = _staff.indexWhere((s) =>
            (s['id'] ?? s['staffId'] ?? '').toString() == staffId);
        if (idx >= 0) {
          _staff[idx] = {..._staff[idx], 'isActive': isActive};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _openAddStaffSheet() {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddStaffSheet(),
    ).then((added) {
      if (added == true) _loadStaff();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              _loadStaff();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.emerald,
        onRefresh: _loadStaff,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStaffSheet,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff Member'),
        backgroundColor: AppTheme.emerald,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadStaff,
      );
    }

    if (_staff.isEmpty) {
      return EmptyState(
        icon: Icons.badge_outlined,
        title: 'No staff members yet',
        subtitle:
            'Add bouncers, kitchen staff, or managers to grant them restricted app access.',
        actionLabel: 'Add Staff Member',
        onAction: _openAddStaffSheet,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 96,
        left: 4,
        right: 4,
      ),
      itemCount: _staff.length,
      itemBuilder: (context, index) {
        final staff = _staff[index];
        return _StaffCard(
          staff: staff,
          onToggle: () => _toggleActive(staff),
        );
      },
    );
  }
}

/// Card displaying a single staff member with name, phone, role badge,
/// active/inactive status, and a popup menu to activate/deactivate.
class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff, required this.onToggle});

  final Map<String, dynamic> staff;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final name = (staff['name'] ?? '').toString();
    final phone = (staff['phone'] ?? '').toString();
    final role = (staff['role'] ?? '').toString();
    final isActive = staff['isActive'] == true;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _roleColor(role).withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: _roleColor(role),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? 'Unknown' : name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: role),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      phone.isEmpty ? '—' : phone,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status + popup menu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusChip(isActive: isActive),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'toggle') onToggle();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.block
                              : Icons.check_circle_outline,
                          size: 20,
                          color: isActive
                              ? AppTheme.warning
                              : AppTheme.emerald,
                        ),
                        const SizedBox(width: 12),
                        Text(isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'bouncer':
        return AppTheme.danger;
      case 'kitchen staff':
      case 'kitchen':
        return AppTheme.warning;
      case 'manager':
        return AppTheme.emerald;
      default:
        return AppTheme.slate;
    }
  }
}

/// Role badge shown next to the staff member's name.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final color = _colorForRole(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _labelForRole(role),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _labelForRole(String role) {
    switch (role.toLowerCase()) {
      case 'bouncer':
        return 'BOUNCER';
      case 'kitchen staff':
      case 'kitchen':
        return 'KITCHEN';
      case 'manager':
        return 'MANAGER';
      default:
        return role.toUpperCase();
    }
  }

  Color _colorForRole(String role) {
    switch (role.toLowerCase()) {
      case 'bouncer':
        return AppTheme.danger;
      case 'kitchen staff':
      case 'kitchen':
        return AppTheme.warning;
      case 'manager':
        return AppTheme.emerald;
      default:
        return AppTheme.slate;
    }
  }
}

/// Active/inactive status chip.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.emerald : AppTheme.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet form for adding a new staff member.
class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet();

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  static const _roles = ['Bouncer', 'Kitchen Staff', 'Manager'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = _roles.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Enter a valid name';
    return null;
  }

  String? _validatePhone(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (v.isEmpty) return 'Mobile number is required';
    if (v.length < 10) return 'Enter a valid 10+ digit mobile number';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      AppHaptics.warning();
      return;
    }
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      await ref.read(vendorDashboardApiProvider).addStaff(
            phone: _phoneController.text.trim(),
            name: _nameController.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nameController.text.trim()} added as $_role'),
          backgroundColor: AppTheme.emerald,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Staff Member',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Grant restricted app access to a team member',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Name
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: _validateName,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Ravi Kumar',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Mobile Number
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: _validatePhone,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'e.g. 9876543210',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Role
            Text(
              'Role',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Bouncer',
                  icon: Icon(Icons.shield_outlined, size: 16),
                  label: Text('Bouncer'),
                ),
                ButtonSegment(
                  value: 'Kitchen Staff',
                  icon: Icon(Icons.restaurant_outlined, size: 16),
                  label: Text('Kitchen'),
                ),
                ButtonSegment(
                  value: 'Manager',
                  icon: Icon(Icons.manage_accounts, size: 16),
                  label: Text('Manager'),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (v) {
                AppHaptics.light();
                setState(() => _role = v.first);
              },
            ),
            const SizedBox(height: 20),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.person_add),
                label: Text(_submitting ? 'Adding...' : 'Add Staff Member'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
