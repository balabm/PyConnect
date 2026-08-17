import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/application/admin_providers.dart';
import '../../admin/data/admin_api.dart';

/// A desktop-first split-screen KYC reviewer for the web admin app.
///
/// Left pane shows the driver's submitted, read-only KYC data (name,
/// vehicle details and bank/UPI information). Right pane is a high-res
/// interactive image viewer for the Driving License and RC documents.
///
/// Approving calls `POST /api/admin/kyc/{id}/approve` and, on success,
/// fires an FCM push to the driver.
class KycReviewScreen extends ConsumerStatefulWidget {
  const KycReviewScreen({
    super.key,
    required this.driver,
  });

  final AdminDriver driver;

  @override
  ConsumerState<KycReviewScreen> createState() => _KycReviewScreenState();
}

class _KycReviewScreenState extends ConsumerState<KycReviewScreen> {
  int _activeDoc = 0;
  bool _approving = false;

  List<(String, String?)> get _docs => <(String, String?)>[
        ('Driving License', widget.driver.drivingLicenseUrl),
        ('RC Book', widget.driver.rcUrl),
      ];

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      final res = await ref.read(adminApiProvider).approveKyc(widget.driver.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty
              ? res.message
              : 'KYC approved for ${widget.driver.name}'),
          backgroundColor: AdminColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval failed: $e'),
          backgroundColor: AdminColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    final detailPane = _DetailPane(
      driver: widget.driver,
      onApprove: _approve,
      approving: _approving,
    );

    final viewerPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DocTabBar(
          docs: _docs,
          activeIndex: _activeDoc,
          onChanged: (i) => setState(() => _activeDoc = i),
        ),
        Expanded(child: _DocumentViewer(docs: _docs, activeIndex: _activeDoc)),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('KYC Review')),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: detailPane),
                Container(width: 1, color: AdminColors.border),
                Expanded(flex: 3, child: viewerPane),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                detailPane,
                const SizedBox(height: 16),
                SizedBox(height: 420, child: viewerPane),
              ],
            ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.driver,
    required this.onApprove,
    required this.approving,
  });

  final AdminDriver driver;
  final VoidCallback onApprove;
  final bool approving;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle('Applicant Details'),
          _Field(label: 'Name', value: driver.name),
          _Field(label: 'Phone', value: driver.phone),
          _Field(
            label: 'Vehicle',
            value: '${driver.vehicleType} · ${driver.vehiclePlate ?? '—'}',
          ),
          _Field(
            label: 'Total Rides',
            value: '${driver.totalRides}',
          ),
          _Field(
            label: 'Rating',
            value: '${driver.rating.toStringAsFixed(1)} ★',
          ),
          const SizedBox(height: 16),
          _SectionTitle('Bank Details'),
          _Field(
            label: 'UPI ID',
            value: driver.upiId?.isNotEmpty == true ? driver.upiId! : '—',
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: approving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(approving ? 'APPROVING…' : 'APPROVE KYC'),
              onPressed: approving ? null : onApprove,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentViewer extends StatelessWidget {
  const _DocumentViewer({
    required this.docs,
    required this.activeIndex,
  });

  final List<(String, String?)> docs;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('No documents uploaded',
              style: TextStyle(color: AdminColors.textMuted)),
        ),
      );
    }

    final validIndex = activeIndex.clamp(0, docs.length - 1);
    final (label, url) = docs[validIndex];

    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text('No preview for $label',
              style: const TextStyle(color: AdminColors.textMuted)),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Center(
          child: AppNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            fallbackIcon: Icons.broken_image_outlined,
            fallbackColor: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _DocTabBar extends StatelessWidget {
  const _DocTabBar({
    required this.docs,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<(String, String?)> docs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  selected: i == activeIndex,
                  onSelected: (_) => onChanged(i),
                ),
              ),
          ],
        ),
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
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
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
            child: Text(
              label,
              style: const TextStyle(
                  color: AdminColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
