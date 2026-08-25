import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/app_network_image.dart';
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
  Timer? _debounce;
  _DriverFilter _filter = _DriverFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim();
        _resetPage();
      });
    });
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
              onChanged: _onSearchChanged,
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
                        child: _DriverTable(
                          drivers: result.items,
                          onApprove: _approve,
                          onReject: _rejectKyc,
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
// Sortable driver DataTable
// ---------------------------------------------------------------------------

/// Sortable columns for the driver table.
enum _DriverSort { name, phone, vehicle, rating, rides, online, kyc }

class _DriverTable extends StatefulWidget {
  const _DriverTable({
    required this.drivers,
    required this.onApprove,
    required this.onReject,
  });

  final List<AdminDriver> drivers;
  final Future<void> Function(AdminDriver) onApprove;
  final Future<void> Function(AdminDriver) onReject;

  @override
  State<_DriverTable> createState() => _DriverTableState();
}

class _DriverTableState extends State<_DriverTable> {
  _DriverSort _sortField = _DriverSort.name;
  bool _sortAscending = true;

  IconData _vehicleIcon(String type) => switch (type.toLowerCase()) {
        'car' => Icons.directions_car,
        'auto' => Icons.local_taxi,
        'bike' => Icons.two_wheeler,
        _ => Icons.directions_car,
      };

  List<AdminDriver> get _sorted {
    final list = [...widget.drivers];
    int compare(AdminDriver a, AdminDriver b) {
      int cmp;
      switch (_sortField) {
        case _DriverSort.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _DriverSort.phone:
          cmp = a.phone.compareTo(b.phone);
        case _DriverSort.vehicle:
          cmp = a.vehicleType.toLowerCase().compareTo(b.vehicleType.toLowerCase());
        case _DriverSort.rating:
          cmp = a.rating.compareTo(b.rating);
        case _DriverSort.rides:
          cmp = a.totalRides.compareTo(b.totalRides);
        case _DriverSort.online:
          cmp = (a.isOnline ? 1 : 0).compareTo(b.isOnline ? 1 : 0);
        case _DriverSort.kyc:
          cmp = (a.isKycUploaded ? 1 : 0).compareTo(b.isKycUploaded ? 1 : 0);
      }
      return _sortAscending ? cmp : -cmp;
    }

    list.sort(compare);
    return list;
  }

  DataColumn _column(
    String label,
    _DriverSort field, {
    IconData? icon,
  }) {
    final active = _sortField == field;
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AdminColors.textMuted),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: active ? AdminColors.accent : AdminColors.textMuted,
                  fontWeight: FontWeight.w600)),
          if (active)
            Icon(
              _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 14,
              color: AdminColors.accent,
            ),
        ],
      ),
      onSort: (_, ascending) {
        setState(() {
          _sortField = field;
          _sortAscending = ascending;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sorted;
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _DriverSort.values.indexOf(_sortField),
          sortAscending: _sortAscending,
          columnSpacing: 20,
          columns: [
            _column('Name', _DriverSort.name),
            _column('Phone', _DriverSort.phone),
            _column('Vehicle', _DriverSort.vehicle, icon: Icons.directions_car),
            _column('Rating', _DriverSort.rating, icon: Icons.star),
            _column('Rides', _DriverSort.rides),
            _column('Online', _DriverSort.online),
            _column('KYC', _DriverSort.kyc),
            const DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((d) {
            return DataRow(cells: [
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AdminColors.accent.withValues(alpha: 0.12),
                    child: Icon(_vehicleIcon(d.vehicleType),
                        size: 16, color: AdminColors.accent),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(d.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary)),
                  ),
                ],
              )),
              DataCell(Text(d.phone.isEmpty ? '—' : d.phone)),
              DataCell(Text(d.vehicleType)),
              DataCell(Text(d.rating.toStringAsFixed(1))),
              DataCell(Text('${d.totalRides}')),
              DataCell(_OnlineDot(isOnline: d.isOnline)),
              DataCell(_KycStatusChip(uploaded: d.isKycUploaded, approved: d.isApproved)),
              DataCell(_DriverActions(
                driver: d,
                onApprove: widget.onApprove,
                onReject: widget.onReject,
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isOnline ? AdminColors.success : AdminColors.textMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(isOnline ? 'Online' : 'Offline',
            style: TextStyle(
                fontSize: 12,
                color: isOnline ? AdminColors.success : AdminColors.textMuted,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _KycStatusChip extends StatelessWidget {
  const _KycStatusChip({required this.uploaded, required this.approved});
  final bool uploaded;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    if (approved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AdminColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('Approved',
            style: TextStyle(
                color: AdminColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
    }
    if (uploaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AdminColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('Pending',
            style: TextStyle(
                color: AdminColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.textMuted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text('No KYC',
          style: TextStyle(
              color: AdminColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// Row actions: view KYC documents, approve, or reject.
class _DriverActions extends StatelessWidget {
  const _DriverActions({
    required this.driver,
    required this.onApprove,
    required this.onReject,
  });

  final AdminDriver driver;
  final Future<void> Function(AdminDriver) onApprove;
  final Future<void> Function(AdminDriver) onReject;

  @override
  Widget build(BuildContext context) {
    if (driver.isApproved) {
      return const Icon(Icons.check_circle_rounded,
          color: AdminColors.accent, size: 18);
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AdminColors.textMuted),
      tooltip: 'Actions',
      onSelected: (v) {
        switch (v) {
          case 'docs':
            _showDocsDialog(context);
          case 'approve':
            onApprove(driver);
          case 'reject':
            onReject(driver);
        }
      },
      itemBuilder: (_) => [
        if (driver.isKycUploaded)
          const PopupMenuItem(
            value: 'docs',
            child: ListTile(
              leading: Icon(Icons.document_scanner_rounded),
              title: Text('View KYC Documents'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (driver.isKycUploaded)
          const PopupMenuItem(
            value: 'approve',
            child: ListTile(
              leading: Icon(Icons.check_circle_rounded, color: AdminColors.success),
              title: Text('Approve'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (driver.isKycUploaded)
          const PopupMenuItem(
            value: 'reject',
            child: ListTile(
              leading: Icon(Icons.block_rounded, color: AdminColors.danger),
              title: Text('Reject KYC'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (!driver.isKycUploaded)
          const PopupMenuItem(
            enabled: false,
            child: Text('Awaiting KYC upload',
                style: TextStyle(color: AdminColors.textMuted, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  void _showDocsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('KYC Documents — ${driver.name}'),
        content: SizedBox(
          width: 520,
          child: _KycDocumentSection(driver: driver),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
    final int from;
    final int to;
    if (total == 0) {
      from = 0;
      to = 0;
    } else {
      final rawFrom = (page - 1) * pageSize + 1;
      final rawTo = page * pageSize;
      if (rawFrom > total) {
        from = 0;
        to = 0;
      } else {
        from = rawFrom.clamp(1, total);
        to = rawTo.clamp(1, total);
      }
    }
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

// ---------------------------------------------------------------------------
// KYC document preview (side-by-side thumbnails)
// ---------------------------------------------------------------------------

/// Displays the driver's uploaded KYC documents as side-by-side thumbnails
/// in a horizontal scroll. Each thumbnail is labelled (Aadhaar, DL, RC, etc.)
/// and tappable to open a full-screen image viewer.
class _KycDocumentSection extends StatelessWidget {
  const _KycDocumentSection({required this.driver});
  final AdminDriver driver;

  @override
  Widget build(BuildContext context) {
    final docs = <(String, String?)>[
      ('Aadhaar', driver.aadhaarUrl),
      ('Driving Licence', driver.drivingLicenseUrl),
      ('RC Book', driver.rcUrl),
      ('Insurance', driver.insuranceUrl),
      ('Selfie', driver.selfieUrl),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.document_scanner_rounded, size: 15, color: AdminColors.textMuted),
            SizedBox(width: 6),
            Text(
              'KYC Documents',
              style: TextStyle(fontSize: 12, color: AdminColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (label, url) = docs[i];
              return _DocumentThumbnail(label: label, imageUrl: url);
            },
          ),
        ),
      ],
    );
  }
}

/// A single document thumbnail card. Shows the image when [imageUrl] is
/// available, otherwise a placeholder with the document label. Tapping
/// opens a full-screen viewer (only when a URL is present).
class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({required this.label, this.imageUrl});
  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: imageUrl == null
          ? null
          : () => _openFullScreen(context, imageUrl!),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AdminColors.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: imageUrl == null
                    ? _Placeholder()
                    : AppNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        height: double.infinity,
                        width: double.infinity,
                        fallbackIcon: Icons.description_outlined,
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AdminColors.border)),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: AdminColors.textPrimary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminColors.surfaceHover,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 28, color: AdminColors.textMuted),
            SizedBox(height: 4),
            Text('No preview', style: TextStyle(fontSize: 10, color: AdminColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Full-screen image viewer for inspecting a KYC document.
void _openFullScreen(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _FullScreenImageViewer(imageUrl: imageUrl),
      fullscreenDialog: true,
    ),
  );
}

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Document'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: AppNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            fallbackIcon: Icons.broken_image_outlined,
            fallbackColor: Colors.black,
          ),
        ),
      ),
    );
  }
}
