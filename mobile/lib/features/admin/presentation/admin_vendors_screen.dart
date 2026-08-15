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
                  child: Text(
                    'Failed to load vendors:\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AdminColors.textMuted),
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
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.6,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _VendorCard(vendor: filtered[i]),
                    );
                  },
                );
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

class _VendorCard extends ConsumerWidget {
  final AdminVendor vendor;
  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vendor.name,
                    style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  vendor.isApproved ? Icons.check_circle : Icons.pending,
                  color: vendor.isApproved ? AdminColors.success : AdminColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(vendor.category, style: const TextStyle(color: AdminColors.textPrimary)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AdminColors.surfaceHover,
                  side: const BorderSide(color: AdminColors.border),
                ),
                if (vendor.cuisineType != null && vendor.cuisineType!.isNotEmpty)
                  Chip(
                    label: Text(vendor.cuisineType!, style: const TextStyle(color: AdminColors.textPrimary)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AdminColors.surfaceHover,
                    side: const BorderSide(color: AdminColors.border),
                  ),
              ],
            ),
            const Spacer(),
            if (vendor.contactPhone != null && vendor.contactPhone!.isNotEmpty)
              _iconLine(Icons.phone, vendor.contactPhone!),
            const SizedBox(height: 4),
            Row(
              children: [
                if (vendor.rating != null) ...[
                  const Icon(Icons.star, color: AdminColors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    vendor.rating!.toStringAsFixed(1),
                    style: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(
                  vendor.isActive ? Icons.toggle_on : Icons.toggle_off,
                  color: vendor.isActive ? AdminColors.accent : AdminColors.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  vendor.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: vendor.isActive ? AdminColors.accent : AdminColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            // KYC document preview (side-by-side thumbnails) for pending vendors
            if (!vendor.isApproved && vendor.isActive) ...[
              const SizedBox(height: 8),
              _VendorKycDocumentSection(vendor: vendor),
            ],
            // Approval action buttons for pending vendors
            if (!vendor.isApproved && vendor.isActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve', style: TextStyle(fontSize: 12)),
                      onPressed: () => _approveVendor(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.danger,
                      ),
                      onPressed: () => _rejectVendor(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveVendor(BuildContext context, WidgetRef ref) async {
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
    final reason = await _showRejectDialog(context);
    if (reason == null) return; // User cancelled

    final messenger = ScaffoldMessenger.of(context);
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
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AdminColors.textMuted, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

  static const _categories = ['Restaurant', 'Cafe', 'Grocery', 'Bakery', 'Pharmacy', 'Retail'];
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
///
/// The current [AdminVendor] data model does not expose document URLs, so
/// placeholder cards are shown with a TODO to wire real URLs when the
/// backend exposes them.
class _VendorKycDocumentSection extends StatelessWidget {
  const _VendorKycDocumentSection({required this.vendor});
  final AdminVendor vendor;

  // TODO: Replace with real document URLs once the backend exposes them on
  // the vendor DTO (e.g. vendor.documents / vendor.documentUrls).
  static const _vendorDocTypes = ['FSSAI', 'GST', 'PAN'];

  @override
  Widget build(BuildContext context) {
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
            itemCount: _vendorDocTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final label = _vendorDocTypes[i];
              // TODO: Resolve real URL per document type from vendor data.
              const url = null;
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
