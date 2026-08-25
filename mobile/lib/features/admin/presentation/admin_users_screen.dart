import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

/// Admin user management screen — searchable, filterable, paginated list of
/// all platform users with role-change and activate/deactivate actions.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  static const _roles = ['All', 'Tourist', 'Local', 'Driver', 'Vendor', 'Admin'];
  static const _statuses = ['All', 'Active', 'Inactive'];
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  String _roleFilter = 'All';
  String _statusFilter = 'All';
  int _page = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  AdminListParams get _params => AdminListParams(
        search: _search.isEmpty ? null : _search,
        role: _roleFilter == 'All' ? null : _roleFilter,
        isActive: _statusFilter == 'All'
            ? null
            : _statusFilter == 'Active',
        page: _page,
        pageSize: _pageSize,
      );

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _search = value;
        _page = 1;
      });
    });
  }

  void _resetPage() => setState(() => _page = 1);

  Future<void> _changeRole(AdminUser user) async {
    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Role'),
        children: ['Tourist', 'Local', 'Driver', 'Vendor', 'Admin']
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Row(children: [
                    _RoleChip(role: r),
                    const SizedBox(width: 12),
                    if (user.role == r)
                      const Icon(Icons.check, color: AppTheme.emerald, size: 18),
                  ]),
                ))
            .toList(),
      ),
    );
    if (newRole == null || newRole == user.role || !mounted) return;

    try {
      await ref.read(adminApiProvider).changeUserRole(user.id, newRole);
      ref.invalidate(adminUsersProvider(_params));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} → $newRole'), backgroundColor: AdminColors.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger),
        );
      }
    }
  }

  Future<void> _toggleActive(AdminUser user) async {
    final next = !user.isActive;
    try {
      await ref
          .read(adminApiProvider)
          .setUserActiveStatus(user.id, next);
      ref.invalidate(adminUsersProvider(_params));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next ? 'Activated ${user.name}' : 'Deactivated ${user.name}'), backgroundColor: AdminColors.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger),
        );
      }
    }
  }

  void _viewDetails(AdminUser user) {
    showDialog(
      context: context,
      builder: (_) => _UserDetailDialog(user: user, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = _params;
    final async = ref.watch(adminUsersProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminUsersProvider(params)),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Search + filters ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AdminColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: Icon(Icons.search_rounded, color: AdminColors.textMuted),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final r in _roles)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(r),
                      selected: _roleFilter == r,
                      onSelected: (_) =>
                          setState(() { _roleFilter = r; _resetPage(); }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in _statuses)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(s),
                      selected: _statusFilter == s,
                      onSelected: (_) =>
                          setState(() { _statusFilter = s; _resetPage(); }),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- Table ---
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: AdminColors.textMuted),
                      const SizedBox(height: 16),
                      Text('Failed to load users:\n$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AdminColors.danger)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(adminUsersProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (result) {
                if (result.items.isEmpty) {
                  return const Center(
                    child: Text('No users found',
                        style: TextStyle(color: AdminColors.textMuted)),
                  );
                }
                return _UserTable(
                  users: result.items,
                  onChangeRole: _changeRole,
                  onToggleActive: _toggleActive,
                  onViewDetails: _viewDetails,
                );
              },
            ),
          ),

          // --- Pagination ---
          async.maybeWhen(
            data: (result) => _PaginationBar(
              page: result.page,
              pageSize: result.pageSize,
              totalCount: result.totalCount,
              onPrev: result.page > 1
                  ? () => setState(() => _page--)
                  : null,
              onNext: result.page * result.pageSize < result.totalCount
                  ? () => setState(() => _page++)
                  : null,
            ),
            orElse: () => const SizedBox(height: 56),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.users,
    required this.onChangeRole,
    required this.onToggleActive,
    required this.onViewDetails,
  });

  final List<AdminUser> users;
  final ValueChanged<AdminUser> onChangeRole;
  final ValueChanged<AdminUser> onToggleActive;
  final ValueChanged<AdminUser> onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('KYC')),
            DataColumn(label: Text('Active')),
            DataColumn(label: Text('Last Login')),
            DataColumn(label: Text('Actions')),
          ],
          rows: users.map((u) {
            return DataRow(cells: [
              DataCell(_NameCell(user: u)),
              DataCell(Text(u.phone.isEmpty ? '—' : u.phone)),
              DataCell(_RoleChip(role: u.role)),
              DataCell(_KycChip(status: u.kycStatus)),
              DataCell(_ActiveDot(isActive: u.isActive)),
              DataCell(Text(_formatLogin(u.lastLoginAt))),
              DataCell(
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Actions',
                  onSelected: (v) {
                    switch (v) {
                      case 'details':
                        onViewDetails(u);
                      case 'role':
                        onChangeRole(u);
                      case 'toggle':
                        onToggleActive(u);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: ListTile(
                        leading: Icon(Icons.visibility_rounded),
                        title: Text('View Details'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'role',
                      child: ListTile(
                        leading: Icon(Icons.swap_horiz_rounded),
                        title: Text('Change Role'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(u.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_rounded),
                        title: Text(u.isActive ? 'Deactivate' : 'Activate'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  String _formatLogin(DateTime? dt) {
    if (dt == null) return 'Never';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AdminColors.accent.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AdminColors.accent, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
              if (user.isProMember)
                const Text('PRO',
                    style: TextStyle(
                        fontSize: 10,
                        color: AdminColors.warning,
                        fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chips & dots
// ---------------------------------------------------------------------------

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _color(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  (Color, Color) _color(String r) {
    switch (r) {
      case 'Admin':
        return (AdminColors.danger, AdminColors.danger.withValues(alpha: 0.15));
      case 'Vendor':
        return (AdminColors.warning, AdminColors.warning.withValues(alpha: 0.15));
      case 'Driver':
        return (AdminColors.info, AdminColors.info.withValues(alpha: 0.15));
      case 'Local':
        return (AdminColors.success, AdminColors.success.withValues(alpha: 0.15));
      case 'Tourist':
      default:
        return (AdminColors.textMuted, AdminColors.textMuted.withValues(alpha: 0.15));
    }
  }
}

class _KycChip extends StatelessWidget {
  const _KycChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final Color color;
    final Color bg;
    if (lower.contains('verif')) {
      color = AdminColors.success;
      bg = AdminColors.success.withValues(alpha: 0.15);
    } else if (lower.contains('reject')) {
      color = AdminColors.danger;
      bg = AdminColors.danger.withValues(alpha: 0.15);
    } else {
      color = AdminColors.warning;
      bg = AdminColors.warning.withValues(alpha: 0.15);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive ? 'Active' : 'Inactive',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AdminColors.success : AdminColors.textMuted,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    // Clamp both ends to valid bounds. Prevents "26-8 of 8" when the
    // page index is stale (e.g. user was on page 2 then filtered down
    // to fewer results).
    final from = totalCount == 0
        ? 0
        : ((page - 1) * pageSize + 1).clamp(1, totalCount);
    final to = (page * pageSize).clamp(0, totalCount);
    final safeFrom = from > to ? 0 : from;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Text('$safeFrom–$to of $totalCount',
              style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13)),
          const Spacer(),
          TextButton(
            onPressed: onPrev,
            child: const Row(children: [
              Icon(Icons.chevron_left_rounded, size: 18),
              Text('Prev'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Page $page',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
          ),
          TextButton(
            onPressed: onNext,
            child: const Row(children: [
              Text('Next'),
              Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User Detail Dialog
// ---------------------------------------------------------------------------

class _UserDetailDialog extends ConsumerStatefulWidget {
  const _UserDetailDialog({required this.user, required this.ref});
  final AdminUser user;
  final WidgetRef ref;

  @override
  ConsumerState<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends ConsumerState<_UserDetailDialog> {
  AdminDriver? _driverInfo;
  AdminVendor? _vendorInfo;
  bool _loadingExtra = true;

  @override
  void initState() {
    super.initState();
    _fetchExtraInfo();
  }

  Future<void> _fetchExtraInfo() async {
    final api = widget.ref.read(adminApiProvider);
    try {
      if (widget.user.role == 'Driver') {
        final result = await api.getDrivers(
          search: widget.user.phone,
          page: 1,
          pageSize: 5,
        );
        if (result.items.isNotEmpty && mounted) {
          setState(() {
            _driverInfo = result.items.firstWhere(
              (d) => d.phone == widget.user.phone,
              orElse: () => result.items.first,
            );
          });
        }
      } else if (widget.user.role == 'Vendor') {
        final vendors = await api.getVendors();
        if (mounted) {
          setState(() {
            _vendorInfo = vendors.firstWhere(
              (v) => v.contactPhone == widget.user.phone,
              orElse: () => vendors.first,
            );
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingExtra = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final isDesktop = MediaQuery.of(context).size.width > 500;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AdminColors.accent.withValues(alpha: 0.15),
            child: Text(
              u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AdminColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
                Text(u.phone.isEmpty ? 'No phone' : u.phone,
                    style: const TextStyle(color: AdminColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isDesktop ? 480 : double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Section(title: 'Profile'),
              _DetailRow(label: 'Role', value: u.role),
              _DetailRow(label: 'KYC Status', value: u.kycStatus),
              _DetailRow(
                  label: 'Status', value: u.isActive ? 'Active' : 'Inactive'),
              _DetailRow(
                  label: 'Pro Member', value: u.isProMember ? 'Yes' : 'No'),
              _DetailRow(
                  label: 'Verified Local', value: u.isVerifiedLocal ? 'Yes' : 'No'),
              _DetailRow(
                  label: 'Registered',
                  value: '${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}'),
              _DetailRow(
                  label: 'Last Login',
                  value: u.lastLoginAt == null
                      ? 'Never'
                      : '${u.lastLoginAt!.day}/${u.lastLoginAt!.month}/${u.lastLoginAt!.year}'),

              // Driver-specific info
              if (u.role == 'Driver') ...[
                const SizedBox(height: 16),
                _Section(title: 'Driver Info'),
                if (_loadingExtra)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.accent)),
                  )
                else if (_driverInfo != null) ...[
                  _DetailRow(
                      label: 'Vehicle Type', value: _driverInfo!.vehicleType),
                  _DetailRow(
                      label: 'Approved',
                      value: _driverInfo!.isApproved ? 'Yes' : 'Pending'),
                  _DetailRow(
                      label: 'Online',
                      value: _driverInfo!.isOnline ? 'Yes' : 'Offline'),
                  _DetailRow(
                      label: 'On Ride',
                      value: _driverInfo!.isOnRide ? 'Yes' : 'No'),
                  _DetailRow(
                      label: 'KYC Uploaded',
                      value: _driverInfo!.isKycUploaded ? 'Yes' : 'No'),
                  _DetailRow(
                      label: 'Rating',
                      value: _driverInfo!.rating.toStringAsFixed(1)),
                  _DetailRow(
                      label: 'Total Rides', value: '${_driverInfo!.totalRides}'),
                  if (!_driverInfo!.isApproved)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve Driver'),
                        onPressed: () => _approveDriver(context),
                      ),
                    ),
                ] else
                  const Text('No driver profile found',
                      style: TextStyle(color: AdminColors.textMuted)),
              ],

              // Vendor-specific info
              if (u.role == 'Vendor') ...[
                const SizedBox(height: 16),
                _Section(title: 'Vendor Info'),
                if (_loadingExtra)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.accent)),
                  )
                else if (_vendorInfo != null) ...[
                  _DetailRow(label: 'Vendor Name', value: _vendorInfo!.name),
                  _DetailRow(label: 'Category', value: _vendorInfo!.category),
                  if (_vendorInfo!.cuisineType != null)
                    _DetailRow(
                        label: 'Cuisine', value: _vendorInfo!.cuisineType!),
                  _DetailRow(
                      label: 'Approved',
                      value: _vendorInfo!.isApproved ? 'Yes' : 'Pending'),
                  _DetailRow(
                      label: 'Active',
                      value: _vendorInfo!.isActive ? 'Yes' : 'Inactive'),
                  if (_vendorInfo!.rating != null)
                    _DetailRow(
                        label: 'Rating',
                        value: _vendorInfo!.rating!.toStringAsFixed(1)),
                  if (!_vendorInfo!.isApproved && _vendorInfo!.isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve Vendor'),
                        onPressed: () => _approveVendor(context),
                      ),
                    ),
                ] else
                  const Text('No vendor profile found',
                      style: TextStyle(color: AdminColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _approveDriver(BuildContext context) async {
    if (_driverInfo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.ref.read(adminApiProvider).approveDriver(_driverInfo!.id);
      widget.ref.invalidate(adminUsersProvider);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Driver approved'),
            backgroundColor: AdminColors.accent,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger));
    }
  }

  Future<void> _approveVendor(BuildContext context) async {
    if (_vendorInfo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.ref.read(adminApiProvider).approveVendor(_vendorInfo!.id);
      widget.ref.invalidate(adminUsersProvider);
      widget.ref.invalidate(adminVendorsProvider);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Vendor approved'),
            backgroundColor: AdminColors.accent,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AdminColors.accent,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: AdminColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AdminColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
