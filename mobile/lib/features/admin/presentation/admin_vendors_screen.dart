import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_network_image.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

/// Vendor management screen for PY Connect admin web app.
/// Lists vendors, supports search/filter, and onboarding new vendors.
class AdminVendorsScreen extends ConsumerStatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  ConsumerState<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

enum _VendorFilter { all, approved, pending, active, inactive }

class _AdminVendorsScreenState extends ConsumerState<AdminVendorsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _VendorFilter _filter = _VendorFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(adminVendorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Management'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Onboard Vendor'),
            onPressed: () => _openOnboardDialog(context),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminVendorsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: const TextStyle(color: AdminColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AdminColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _VendorFilter.values.map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(f)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          // Vendor list
          Expanded(
            child: vendorsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.accent),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: AdminColors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load vendors:\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AdminColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(adminVendorsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (vendors) {
                final filtered = _applyFilters(vendors);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No vendors found.',
                      style: TextStyle(color: AdminColors.textMuted),
                    ),
                  );
                }
                return _VendorTable(vendors: filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AdminVendor> _applyFilters(List<AdminVendor> vendors) {
    var result = vendors;
    if (_searchQuery.isNotEmpty) {
      result = result.where((v) {
        final name = v.name.toLowerCase();
        final phone = (v.contactPhone ?? '').toLowerCase();
        return name.contains(_searchQuery) || phone.contains(_searchQuery);
      }).toList();
    }
    switch (_filter) {
      case _VendorFilter.all:
        break;
      case _VendorFilter.approved:
        result = result.where((v) => v.isApproved).toList();
        break;
      case _VendorFilter.pending:
        result = result.where((v) => !v.isApproved).toList();
        break;
      case _VendorFilter.active:
        result = result.where((v) => v.isActive).toList();
        break;
      case _VendorFilter.inactive:
        result = result.where((v) => !v.isActive).toList();
        break;
    }
    return result;
  }

  String _filterLabel(_VendorFilter f) {
    switch (f) {
      case _VendorFilter.all:
        return 'All';
      case _VendorFilter.approved:
        return 'Approved';
      case _VendorFilter.pending:
        return 'Pending';
      case _VendorFilter.active:
        return 'Active';
      case _VendorFilter.inactive:
        return 'Inactive';
    }
  }

  void _openOnboardDialog(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => const _OnboardVendorDialog(),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const _OnboardVendorDialog(),
        ),
      );
    }
  }
}

/// Maps a vendor category string to a color.
Color categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'restaurant':
      return AdminColors.warning;
    case 'cafe':
      return AdminColors.warning;
    case 'grocery':
      return AdminColors.success;
    case 'bakery':
      return AdminColors.warning;
    case 'pharmacy':
      return AdminColors.accent;
    case 'retail':
      return AdminColors.info;
    default:
      return AdminColors.accent;
  }
}

// ---------------------------------------------------------------------------
// Sortable vendor DataTable
// ---------------------------------------------------------------------------

enum _VendorSort { name, category, rating, approved, active }

class _VendorTable extends StatefulWidget {
  const _VendorTable({required this.vendors});
  final List<AdminVendor> vendors;

  @override
  State<_VendorTable> createState() => _VendorTableState();
}

class _VendorTableState extends State<_VendorTable> {
  _VendorSort _sortField = _VendorSort.name;
  bool _sortAscending = true;

  List<AdminVendor> get _sorted {
    final list = [...widget.vendors];
    int compare(AdminVendor a, AdminVendor b) {
      int cmp;
      switch (_sortField) {
        case _VendorSort.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _VendorSort.category:
          cmp = a.category.toLowerCase().compareTo(b.category.toLowerCase());
        case _VendorSort.rating:
          cmp = (a.rating ?? 0).compareTo(b.rating ?? 0);
        case _VendorSort.approved:
          cmp = (a.isApproved ? 1 : 0).compareTo(b.isApproved ? 1 : 0);
        case _VendorSort.active:
          cmp = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
      }
      return _sortAscending ? cmp : -cmp;
    }

    list.sort(compare);
    return list;
  }

  DataColumn _column(String label, _VendorSort field) {
    final active = _sortField == field;
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DataTable(
          sortColumnIndex: _VendorSort.values.indexOf(_sortField),
          sortAscending: _sortAscending,
          columnSpacing: 20,
          columns: [
            _column('Name', _VendorSort.name),
            const DataColumn(label: Text('Phone')),
            _column('Category', _VendorSort.category),
            _column('Rating', _VendorSort.rating),
            _column('Approved', _VendorSort.approved),
            _column('Active', _VendorSort.active),
            const DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((v) {
            return DataRow(cells: [
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: categoryColor(v.category).withValues(alpha: 0.15),
                    child: Text(v.name.isNotEmpty ? v.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(v.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary)),
                  ),
                ],
              )),
              DataCell(Text(v.contactPhone == null || v.contactPhone!.isEmpty
                  ? '—'
                  : v.contactPhone!)),
              DataCell(Text(v.category)),
              DataCell(Text(v.rating == null
                  ? '—'
                  : v.rating!.toStringAsFixed(1))),
              DataCell(_VendorApprovedChip(approved: v.isApproved)),
              DataCell(_VendorActiveChip(active: v.isActive)),
              DataCell(_VendorActions(vendor: v)),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _VendorApprovedChip extends StatelessWidget {
  const _VendorApprovedChip({required this.approved});
  final bool approved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: approved
            ? AdminColors.success.withValues(alpha: 0.15)
            : AdminColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(approved ? 'Approved' : 'Pending',
          style: TextStyle(
              color: approved ? AdminColors.success : AdminColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _VendorActiveChip extends StatelessWidget {
  const _VendorActiveChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: active ? AdminColors.accent : AdminColors.textMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(active ? 'Active' : 'Inactive',
            style: TextStyle(
                fontSize: 12,
                color: active ? AdminColors.accent : AdminColors.textMuted,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Row actions for a vendor: view compliance docs, approve, or reject.
class _VendorActions extends ConsumerWidget {
  const _VendorActions({required this.vendor});
  final AdminVendor vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vendor.isApproved) {
      return const Icon(Icons.check_circle_rounded,
          color: AdminColors.success, size: 18);
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AdminColors.textMuted),
      tooltip: 'Actions',
      onSelected: (v) {
        switch (v) {
          case 'docs':
            _showDocsDialog(context);
          case 'approve':
            _approveVendor(context, ref);
          case 'reject':
            _rejectVendor(context, ref);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'docs',
          child: ListTile(
            leading: Icon(Icons.document_scanner_rounded),
            title: Text('View Compliance Docs'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'approve',
          child: ListTile(
            leading: Icon(Icons.check_circle_rounded, color: AdminColors.success),
            title: Text('Approve'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'reject',
          child: ListTile(
            leading: Icon(Icons.block_rounded, color: AdminColors.danger),
            title: Text('Reject'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showDocsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Compliance Documents — ${vendor.name}'),
        content: SizedBox(
          width: 520,
          child: _VendorKycDocumentSection(vendor: vendor),
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

  Future<void> _approveVendor(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Vendor?'),
        content: Text('Approve ${vendor.name}? This will allow them to receive orders and operate on the platform.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminApiProvider).approveVendor(vendor.id);
      ref.invalidate(adminVendorsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${vendor.name} approved'),
          backgroundColor: AdminColors.accent,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  Future<void> _rejectVendor(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _showRejectDialog(context);
    if (reason == null) return;

    try {
      await ref.read(adminApiProvider).rejectVendor(vendor.id, reason: reason);
      ref.invalidate(adminVendorsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${vendor.name} rejected'),
          backgroundColor: AdminColors.danger,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  Future<String?> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ${vendor.name}?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.of(ctx).pop(
                controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

/// Onboard new vendor form. Shown as full-screen on mobile, AlertDialog on desktop.
class _OnboardVendorDialog extends ConsumerStatefulWidget {
  const _OnboardVendorDialog();

  @override
  ConsumerState<_OnboardVendorDialog> createState() => _OnboardVendorDialogState();
}

class _OnboardVendorDialogState extends ConsumerState<_OnboardVendorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _prepTimeController = TextEditingController();

  static const _categories = [
    'Restaurant',
    'Cafe',
    'Pizzeria',
    'PubClub',
    'ScooterRental',
    'TaxiOperator',
    'LuggageCloak',
    'PartySupplier',
  ];
  String _category = _categories.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cuisineController.dispose();
    _descriptionController.dispose();
    _deliveryFeeController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = _buildForm();
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Onboard New Vendor'),
          actions: [
            TextButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Save'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: form,
        ),
      );
    }

    return AlertDialog(
      title: const Text('Onboard New Vendor'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: form)),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Onboard'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _textField(_nameController, 'Name *', 'Enter vendor name'),
          const SizedBox(height: 12),
          _textField(_phoneController, 'Contact Phone *', 'Enter phone number',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: _inputDecoration('Category *'),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _categories.first),
            validator: (v) => (v == null || v.isEmpty) ? 'Select a category' : null,
          ),
          const SizedBox(height: 12),
          _textField(_cuisineController, 'Cuisine Type (optional)', 'e.g. South Indian'),
          const SizedBox(height: 12),
          _textField(_descriptionController, 'Description (optional)', 'Short description',
              maxLines: 3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _textField(_deliveryFeeController, 'Delivery Fee (optional)', '0.0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(_prepTimeController, 'Prep Time (min, optional)', '0',
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDecoration(label, hint: hint),
      validator: (v) {
        if (label.contains('*') && (v == null || v.trim().isEmpty)) {
          return '$label is required';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final deliveryFee = double.tryParse(_deliveryFeeController.text.trim());
    final prepTime = int.tryParse(_prepTimeController.text.trim());

    final request = OnboardVendorRequest(
      name: _nameController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      category: _category,
      cuisineType: _cuisineController.text.trim().isEmpty ? null : _cuisineController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      deliveryFee: deliveryFee,
      prepTimeMinutes: prepTime,
    );

    try {
      final result = await ref.read(adminApiProvider).onboardVendor(request);
      ref.invalidate(adminVendorsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AdminColors.accent,
        ),
      );
      _resetForm();
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Onboarding failed: $e'),
          backgroundColor: AdminColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _phoneController.clear();
    _cuisineController.clear();
    _descriptionController.clear();
    _deliveryFeeController.clear();
    _prepTimeController.clear();
    setState(() => _category = _categories.first);
  }
}

// ---------------------------------------------------------------------------
// Vendor KYC document preview (side-by-side thumbnails)
// ---------------------------------------------------------------------------

/// Displays the vendor's uploaded compliance documents (FSSAI, GST, PAN) as
/// side-by-side thumbnails in a horizontal scroll. Each thumbnail is labelled
/// and tappable to open a full-screen image viewer.
class _VendorKycDocumentSection extends StatelessWidget {
  const _VendorKycDocumentSection({required this.vendor});
  final AdminVendor vendor;

  @override
  Widget build(BuildContext context) {
    final docs = <(String, String?)>[
      ('FSSAI', vendor.fssaiDocUrl),
      ('GST', vendor.gstDocUrl),
      ('PAN', vendor.panDocUrl),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.document_scanner_rounded, size: 15, color: AdminColors.textMuted),
            SizedBox(width: 6),
            Text(
              'Compliance Documents',
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
              return _VendorDocumentThumbnail(label: label, imageUrl: url);
            },
          ),
        ),
      ],
    );
  }
}

/// A single vendor document thumbnail card. Shows the image when [imageUrl]
/// is available, otherwise a placeholder with the document label. Tapping
/// opens a full-screen viewer (only when a URL is present).
class _VendorDocumentThumbnail extends StatelessWidget {
  const _VendorDocumentThumbnail({required this.label, this.imageUrl});
  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: imageUrl == null
          ? null
          : () => _openVendorFullScreen(context, imageUrl!),
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
                    ? _VendorPlaceholder()
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

class _VendorPlaceholder extends StatelessWidget {
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

/// Full-screen image viewer for inspecting a vendor compliance document.
void _openVendorFullScreen(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _VendorFullScreenImageViewer(imageUrl: imageUrl),
      fullscreenDialog: true,
    ),
  );
}

class _VendorFullScreenImageViewer extends StatelessWidget {
  const _VendorFullScreenImageViewer({required this.imageUrl});
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
