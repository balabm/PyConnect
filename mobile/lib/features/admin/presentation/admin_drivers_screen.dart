import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

/// Driver management screen for the PY Connect admin web app.
/// Lists drivers with search, filters, approve / reject-KYC actions,
/// and pagination.
class AdminDriversScreen extends ConsumerStatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  ConsumerState<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends ConsumerState<AdminDriversScreen> {
  int _page = 1;
  static const int _pageSize = 20;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();
  _DriverFilter _filter = _DriverFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  AdminListParams get _params => AdminListParams(
        search: _search.isEmpty ? null : _search,
        isApproved: switch (_filter) {
          _DriverFilter.approved => true,
          _DriverFilter.pending => false,
          _ => null,
        },
        isOnline: _filter == _DriverFilter.online ? true : null,
        kycUploadedOnly: _filter == _DriverFilter.kycUploaded,
        page: _page,
        pageSize: _pageSize,
      );

  void _resetPage() => _page = 1;

  Future<void> _approve(AdminDriver d) async {
    try {
      final res = await ref.read(adminApiProvider).approveDriver(d.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AdminColors.accent : AdminColors.danger,
        ),
      );
      ref.invalidate(adminDriversProvider(_params));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: $e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  Future<void> _rejectKyc(AdminDriver d) async {
    final reason = await _showRejectDialog(d);
    if (reason == null) return;
    try {
      await ref.read(adminApiProvider).rejectDriverKyc(d.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC rejected'),
          backgroundColor: AdminColors.danger,
        ),
      );
      ref.invalidate(adminDriversProvider(_params));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  Future<String?> _showRejectDialog(AdminDriver d) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject KYC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Driver: ${d.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter rejection reason',
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drivers = ref.watch(adminDriversProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminDriversProvider(_params)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AdminColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: AdminColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _search = '';
                            _resetPage();
                          });
                        },
                      ),
              ),
              onSubmitted: (v) => setState(() {
                _search = v.trim();
                _resetPage();
              }),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in _DriverFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() {
                        _filter = f;
                        _resetPage();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Driver list
          Expanded(
            child: drivers.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AdminColors.danger),
                    const SizedBox(height: 8),
                    const Text('Failed to load drivers', style: TextStyle(color: AdminColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('$e', style: const TextStyle(fontSize: 12, color: AdminColors.textMuted), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(adminDriversProvider(_params)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (result) {
                if (result.items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car_outlined, size: 48, color: AdminColors.textMuted),
                        SizedBox(height: 8),
                        Text('No drivers found', style: TextStyle(color: AdminColors.textMuted)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: AdminColors.accent,
                        onRefresh: () async => ref.invalidate(adminDriversProvider(_params)),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          itemCount: result.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _DriverCard(
                            driver: result.items[i],
                            onApprove: _approve,
                            onReject: _rejectKyc,
                          ),
                        ),
                      ),
                    ),
                    _PaginationBar(
                      page: result.page,
                      pageSize: result.pageSize,
                      total: result.totalCount,
                      onPrev: _page > 1 ? () => setState(() => _page--) : null,
                      onNext: result.page * result.pageSize < result.totalCount
                          ? () => setState(() => _page++)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Driver card
// ---------------------------------------------------------------------------

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.onApprove,
    required this.onReject,
  });

  final AdminDriver driver;
  final Future<void> Function(AdminDriver) onApprove;
  final Future<void> Function(AdminDriver) onReject;

  IconData get _vehicleIcon => switch (driver.vehicleType.toLowerCase()) {
        'car' => Icons.directions_car,
        'auto' => Icons.local_taxi,
        'bike' => Icons.two_wheeler,
        _ => Icons.directions_car,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + vehicle
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AdminColors.accent.withValues(alpha: 0.12),
                  foregroundColor: AdminColors.accent,
                  child: Icon(_vehicleIcon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 13, color: AdminColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            driver.phone.isEmpty ? '—' : driver.phone,
                            style: const TextStyle(fontSize: 13, color: AdminColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (driver.isOnRide)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.warning,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'On Ride',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Stats row
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _StatChip(
                  icon: Icons.star,
                  iconColor: AdminColors.warning,
                  label: driver.rating.toStringAsFixed(1),
                ),
                _StatChip(
                  icon: Icons.history,
                  iconColor: AdminColors.info,
                  label: '${driver.totalRides} rides',
                ),
                _StatChip(
                  icon: _vehicleIcon,
                  iconColor: AdminColors.textMuted,
                  label: driver.vehicleType,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Status row: online / kyc / location
            Row(
              children: [
                // Online status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: driver.isOnline ? AdminColors.success : AdminColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      driver.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: driver.isOnline ? AdminColors.success : AdminColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // KYC status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      driver.isKycUploaded ? Icons.verified_user : Icons.gpp_bad,
                      size: 14,
                      color: driver.isKycUploaded ? AdminColors.accent : AdminColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      driver.isKycUploaded ? 'KYC Uploaded' : 'No KYC',
                      style: TextStyle(
                        fontSize: 12,
                        color: driver.isKycUploaded ? AdminColors.accent : AdminColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Live location
            if (driver.latitude != null && driver.longitude != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 13, color: AdminColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '${driver.latitude!.toStringAsFixed(4)}, ${driver.longitude!.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            // Actions
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (driver.isApproved) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AdminColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: AdminColors.accent),
                SizedBox(width: 4),
                Text('Approved', style: TextStyle(color: AdminColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ],
      );
    }

    if (driver.isKycUploaded) {
      return Row(
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
            onPressed: () => onApprove(driver),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Reject KYC'),
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => onReject(driver),
          ),
        ],
      );
    }

    return const Text(
      'Awaiting KYC upload',
      style: TextStyle(fontSize: 12, color: AdminColors.textMuted, fontStyle: FontStyle.italic),
    );
  }
}

// ---------------------------------------------------------------------------
// Small stat chip
// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.iconColor, required this.label});
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination bar
// ---------------------------------------------------------------------------

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int pageSize;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = (page * pageSize).clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$from–$to of $total',
            style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrev,
                color: AdminColors.accent,
              ),
              Text('Page $page', style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
                color: AdminColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter enum
// ---------------------------------------------------------------------------

enum _DriverFilter {
  all('All'),
  approved('Approved'),
  pending('Pending Approval'),
  online('Online'),
  kycUploaded('KYC Uploaded');

  const _DriverFilter(this.label);
  final String label;
}
