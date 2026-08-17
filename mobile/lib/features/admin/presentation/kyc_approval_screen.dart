import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_network_image.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

/// KYC Approval queue — a desktop-first split-screen reviewer.
///
/// Left pane: the pending driver's data fields (Name, Phone, Vehicle Info,
/// Category, Bank Details, rating/rides). Right pane: a high-res image
/// viewer for the uploaded KYC documents (Driving License, RC, Insurance,
/// Aadhaar, Selfie) with pan/zoom via [InteractiveViewer].
///
/// Approve calls `POST /api/admin/approve-driver/{id}` (activate captain).
/// Reject opens a modal requiring a typed reason, then calls
/// `POST /api/admin/drivers/{id}/reject-kyc` with `{ reason }`.
class KycApprovalScreen extends ConsumerStatefulWidget {
  const KycApprovalScreen({super.key});

  @override
  ConsumerState<KycApprovalScreen> createState() => _KycApprovalScreenState();
}

class _KycApprovalScreenState extends ConsumerState<KycApprovalScreen> {
  static const _pendingKycParams = AdminListParams(
    isApproved: false,
    kycUploadedOnly: true,
    page: 1,
    pageSize: 100,
  );

  int _selected = 0;
  bool _approving = false;
  bool _rejecting = false;

  AdminListParams get _params => _pendingKycParams;

  Future<void> _refresh() async {
    ref.invalidate(adminDriversProvider(_params));
  }

  Future<void> _approve(AdminDriver driver) async {
    setState(() => _approving = true);
    try {
      final res = await ref.read(adminApiProvider).approveDriver(driver.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty
              ? res.message
              : 'Approved & activated ${driver.name}'),
          backgroundColor: AdminColors.success,
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approve failed: $e'),
          backgroundColor: AdminColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _reject(AdminDriver driver) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectReasonDialog(driverName: driver.name),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _rejecting = true);
    try {
      // Backend reject-kyc endpoint accepts a `reason` parameter
      // (RejectKycRequest(string? Reason)) — pass it through.
      await ref
          .read(adminApiProvider)
          .rejectDriverKyc(driver.id, reason: reason.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejected: ${reason.trim()}'),
          backgroundColor: AdminColors.danger,
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reject failed: $e'),
          backgroundColor: AdminColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(adminDriversProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Approvals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh queue',
            onPressed: _refresh,
          ),
        ],
      ),
      body: queueAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load pending approvals:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AdminColors.danger)),
          ),
        ),
        data: (result) {
          final queue = result.items;
          if (queue.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 64, color: AdminColors.success),
                  const SizedBox(height: 16),
                  const Text('Queue is clear',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('No pending KYC approvals',
                      style: TextStyle(color: AdminColors.textMuted)),
                ],
              ),
            );
          }
          final index = _selected.clamp(0, queue.length - 1);
          final driver = queue[index];
          return _SplitLayout(
            queue: queue,
            selectedIndex: index,
            onSelect: (i) => setState(() => _selected = i),
            driver: driver,
            onApprove: () => _approve(driver),
            onReject: () => _reject(driver),
            approving: _approving,
            rejecting: _rejecting,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Split-screen layout
// ---------------------------------------------------------------------------

class _SplitLayout extends StatefulWidget {
  const _SplitLayout({
    required this.queue,
    required this.selectedIndex,
    required this.onSelect,
    required this.driver,
    required this.onApprove,
    required this.onReject,
    required this.approving,
    required this.rejecting,
  });

  final List<AdminDriver> queue;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AdminDriver driver;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool approving;
  final bool rejecting;

  @override
  State<_SplitLayout> createState() => _SplitLayoutState();
}

class _SplitLayoutState extends State<_SplitLayout> {
  int _activeDoc = 0;

  List<(String, String?)> get _docs => <(String, String?)>[
        ('Driving License', widget.driver.drivingLicenseUrl),
        ('RC Book', widget.driver.rcUrl),
        ('Insurance', widget.driver.insuranceUrl),
        ('Aadhaar', widget.driver.aadhaarUrl),
        ('Selfie', widget.driver.selfieUrl),
      ];

  @override
  void didUpdateWidget(covariant _SplitLayout old) {
    super.didUpdateWidget(old);
    // Reset the active document tab when the selected driver changes.
    if (old.driver.id != widget.driver.id) {
      _activeDoc = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final docs = _docs;
    final viewerPane = _DocContext(
      docs: docs,
      activeIndex: _activeDoc,
      onChanged: (i) => setState(() => _activeDoc = i),
      child: const _DocumentViewerPane(),
    );
    if (!isWide) {
      // Narrow fallback: stacked single column (queue list above detail).
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _QueueList(
            queue: widget.queue,
            selectedIndex: widget.selectedIndex,
            onSelect: widget.onSelect,
          ),
          const SizedBox(height: 16),
          _DetailPane(
            driver: widget.driver,
            onApprove: widget.onApprove,
            onReject: widget.onReject,
            approving: widget.approving,
            rejecting: widget.rejecting,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 420,
            child: viewerPane,
          ),
        ],
      );
    }
    return Row(
      children: [
        // Queue sidebar
        SizedBox(
          width: 280,
          child: _QueueList(
            queue: widget.queue,
            selectedIndex: widget.selectedIndex,
            onSelect: widget.onSelect,
          ),
        ),
        Container(width: 1, color: AdminColors.border),
        // Left: data fields
        Expanded(
          flex: 2,
          child: _DetailPane(
            driver: widget.driver,
            onApprove: widget.onApprove,
            onReject: widget.onReject,
            approving: widget.approving,
            rejecting: widget.rejecting,
          ),
        ),
        Container(width: 1, color: AdminColors.border),
        // Right: high-res image viewer
        Expanded(
          flex: 3,
          child: viewerPane,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Queue list (left sidebar)
// ---------------------------------------------------------------------------

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.queue,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<AdminDriver> queue;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            border: Border(bottom: BorderSide(color: AdminColors.border)),
          ),
          child: Text(
            'Pending (${queue.length})',
            style: const TextStyle(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: queue.length,
            separatorBuilder: (_, _) =>
                const Divider(color: AdminColors.border, height: 1, indent: 12),
            itemBuilder: (context, i) {
              final d = queue[i];
              final selected = i == selectedIndex;
              return Material(
                color: selected
                    ? AdminColors.accent.withValues(alpha: 0.10)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AdminColors.accent.withValues(alpha: 0.15),
                        child: Text(
                          d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AdminColors.accent,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AdminColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(d.phone.isEmpty ? 'No phone' : d.phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AdminColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.chevron_right_rounded,
                            color: AdminColors.accent, size: 18),
                    ],
                  ),
                ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail pane (left of split) — data fields + action buttons
// ---------------------------------------------------------------------------

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.driver,
    required this.onApprove,
    required this.onReject,
    required this.approving,
    required this.rejecting,
  });

  final AdminDriver driver;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool approving;
  final bool rejecting;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AdminColors.accent.withValues(alpha: 0.15),
                child: Text(
                  driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AdminColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name,
                        style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text('Driver ID: ${driver.id.substring(0, 8)}',
                        style: const TextStyle(
                            color: AdminColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Applicant Details'),
          _Field(label: 'Name', value: driver.name),
          _Field(label: 'Phone', value: driver.phone.isEmpty ? '—' : driver.phone),
          _Field(label: 'Category', value: 'Captain / ${driver.vehicleType}'),
          const SizedBox(height: 16),
          const _SectionTitle('Vehicle Info'),
          _Field(label: 'Vehicle Type', value: driver.vehicleType),
          _Field(
              label: 'Rating',
              value: '${driver.rating.toStringAsFixed(1)} \u2605'),
          _Field(
              label: 'Total Rides', value: '${driver.totalRides}'),
          const SizedBox(height: 16),
          const _SectionTitle('Bank Details'),
          _Field(label: 'Bank Account', value: '— (not provided)'),
          _Field(label: 'KYC Uploaded', value: driver.isKycUploaded ? 'Yes' : 'No'),
          const SizedBox(height: 16),
          const _SectionTitle('Submitted Documents'),
          _DocAvailabilityChip(
              label: 'Driving License', url: driver.drivingLicenseUrl),
          _DocAvailabilityChip(label: 'RC Book', url: driver.rcUrl),
          _DocAvailabilityChip(label: 'Insurance', url: driver.insuranceUrl),
          _DocAvailabilityChip(label: 'Aadhaar', url: driver.aadhaarUrl),
          _DocAvailabilityChip(label: 'Selfie', url: driver.selfieUrl),
          const SizedBox(height: 24),
          const _SectionTitle('OCR Verification'),
          _KycVerificationBadge(autoApproved: driver.kycAutoApproved),
          _Field(label: 'Parsed Name', value: driver.kycParsedName ?? '—'),
          _Field(label: 'License Number', value: driver.kycLicenseNumber ?? '—'),
          _Field(
              label: 'Expiry',
              value: driver.kycExpiryDate != null
                  ? '${driver.kycExpiryDate!.day.toString().padLeft(2, '0')}/${driver.kycExpiryDate!.month.toString().padLeft(2, '0')}/${driver.kycExpiryDate!.year}'
                  : '—'),
          _Field(
              label: 'Confidence',
              value: driver.kycConfidence != null
                  ? '${(driver.kycConfidence! * 100).toStringAsFixed(0)}%'
                  : '—'),
          if (driver.kycVerificationReason?.isNotEmpty == true)
            _Field(label: 'Reason', value: driver.kycVerificationReason!),
          const SizedBox(height: 24),
          // Giant action buttons
          _ApproveButton(onPressed: onApprove, loading: approving),
          const SizedBox(height: 12),
          _RejectButton(onPressed: onReject, loading: rejecting),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: AdminColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _DocAvailabilityChip extends StatelessWidget {
  const _DocAvailabilityChip({required this.label, required this.url});
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final present = url != null && url!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            present ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: present ? AdminColors.success : AdminColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AdminColors.textPrimary, fontSize: 13)),
          const Spacer(),
          Text(present ? 'Uploaded' : 'Missing',
              style: TextStyle(
                  color: present ? AdminColors.success : AdminColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _KycVerificationBadge extends StatelessWidget {
  const _KycVerificationBadge({required this.autoApproved});
  final bool? autoApproved;

  @override
  Widget build(BuildContext context) {
    final approved = autoApproved == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: approved
            ? AdminColors.success.withValues(alpha: 0.12)
            : AdminColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approved ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 16,
            color: approved ? AdminColors.success : AdminColors.warning,
          ),
          const SizedBox(width: 6),
          Text(
            approved ? 'Auto-Verified' : 'Needs Manual Review',
            style: TextStyle(
              color: approved ? AdminColors.success : AdminColors.warning,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Giant action buttons
// ---------------------------------------------------------------------------

class _ApproveButton extends StatelessWidget {
  const _ApproveButton({required this.onPressed, required this.loading});
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.success,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_rounded, size: 22),
        label: Text(loading ? 'APPROVING…' : 'APPROVE & ACTIVATE'),
        onPressed: loading ? null : onPressed,
      ),
    );
  }
}

class _RejectButton extends StatelessWidget {
  const _RejectButton({required this.onPressed, required this.loading});
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.danger,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.block_rounded, size: 20),
        label: Text(loading ? 'REJECTING…' : 'REJECT'),
        onPressed: loading ? null : onPressed,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reject reason modal
// ---------------------------------------------------------------------------

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.driverName});
  final String driverName;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject KYC'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Driver: ${widget.driverName}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text('A reason is required to reject this application.',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. "Blurry License Image"',
              labelText: 'Reason',
            ),
            onChanged: (v) => setState(() => _canSubmit = v.trim().isNotEmpty),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AdminColors.danger, foregroundColor: Colors.white),
          onPressed: _canSubmit
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Document viewer pane (right of split) — high-res with InteractiveViewer
// ---------------------------------------------------------------------------

class _DocumentViewerPane extends StatefulWidget {
  const _DocumentViewerPane();

  @override
  State<_DocumentViewerPane> createState() => _DocumentViewerPaneState();
}

class _DocumentViewerPaneState extends State<_DocumentViewerPane> {
  // The active document index is driven by an inherited selection. Because
  // this pane is rebuilt when the selected driver changes (via the split
  // layout), we expose the active doc through an Inherited widget below.
  @override
  Widget build(BuildContext context) {
    final data = _DocContext.of(context);
    final docs = data.docs;
    var active = data.activeIndex.clamp(0, docs.isEmpty ? 0 : docs.length - 1);
    if (docs.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.document_scanner_rounded,
                  size: 56, color: AdminColors.textMuted),
              SizedBox(height: 12),
              Text('No documents uploaded',
                  style: TextStyle(color: AdminColors.textMuted)),
            ],
          ),
        ),
      );
    }
    final (label, url) = docs[active];
    return _DocumentViewer(
      docs: docs,
      active: active,
      label: label,
      url: url,
      onChanged: data.onChanged,
    );
  }
}

class _DocumentViewer extends StatelessWidget {
  const _DocumentViewer({
    required this.docs,
    required this.active,
    required this.label,
    required this.url,
    required this.onChanged,
  });

  final List<(String, String?)> docs;
  final int active;
  final String label;
  final String? url;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Document tab bar
          Container(
            color: AdminColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < docs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(docs[i].$1),
                        selected: i == active,
                        onSelected: (_) => onChanged(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // High-res zoomable image
          Expanded(
            child: url == null || url!.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_not_supported_rounded,
                            size: 48, color: AdminColors.textMuted),
                        const SizedBox(height: 8),
                        Text('No preview for $label',
                            style: const TextStyle(color: AdminColors.textMuted)),
                      ],
                    ),
                  )
                : InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: Center(
                      child: AppNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.contain,
                        fallbackIcon: Icons.broken_image_outlined,
                        fallbackColor: Colors.black,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Inherited widget that carries the selected driver's documents and the
/// currently active document tab to the [_DocumentViewerPane].
class _DocContext extends InheritedWidget {
  const _DocContext({
    required this.docs,
    required this.activeIndex,
    required this.onChanged,
    required super.child,
  });

  final List<(String, String?)> docs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  static _DocContext of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_DocContext>()!;
  }

  @override
  bool updateShouldNotify(_DocContext old) =>
      activeIndex != old.activeIndex || docs != old.docs;
}
