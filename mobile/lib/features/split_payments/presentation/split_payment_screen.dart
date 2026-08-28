import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../data/split_payment_api.dart';

/// Split Payment creator screen.
///
/// Users create a pool for a high-ticket item (villa rental, yacht charter),
/// set the total amount and number of shares, then share a deep-link URL to
/// WhatsApp so friends can claim and pay their individual shares.
class SplitPaymentScreen extends ConsumerStatefulWidget {
  const SplitPaymentScreen({super.key, this.prefillAmount, this.prefillDescription});

  /// Optional prefill from a booking/rental context.
  final double? prefillAmount;
  final String? prefillDescription;

  @override
  ConsumerState<SplitPaymentScreen> createState() => _SplitPaymentScreenState();
}

class _SplitPaymentScreenState extends ConsumerState<SplitPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sharesCtrl = TextEditingController(text: '4');
  bool _creating = false;
  List<SplitPaymentPoolModel> _myPools = [];
  bool _loadingPools = true;

  @override
  void initState() {
    super.initState();
    if (widget.prefillAmount != null) {
      _amountCtrl.text = widget.prefillAmount!.toStringAsFixed(0);
    }
    if (widget.prefillDescription != null) {
      _descCtrl.text = widget.prefillDescription!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPools());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _sharesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPools() async {
    try {
      final pools = await ref.read(splitPaymentApiProvider).myPools();
      if (mounted) setState(() { _myPools = pools; _loadingPools = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPools = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load pools: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.light();
    setState(() => _creating = true);

    try {
      final amount = double.tryParse(_amountCtrl.text) ?? 0;
      final shares = int.tryParse(_sharesCtrl.text) ?? 1;
      final pool = await ref.read(splitPaymentApiProvider).createPool(
            totalAmount: amount,
            description: _descCtrl.text.trim(),
            maxShares: shares,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Split payment pool created! Share the link with friends.'), backgroundColor: AppTheme.emerald),
        );
        _amountCtrl.clear();
        _descCtrl.clear();
        _loadPools();

        // Auto-open share sheet
        _sharePool(pool);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create pool: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _sharePool(SplitPaymentPoolModel pool) {
    final shareText = '${pool.description}\n\n'
        'Total: ₹${pool.totalAmount.toStringAsFixed(0)}\n'
        'Your share: ₹${pool.perShareAmount.toStringAsFixed(0)} (${pool.maxShares} people)\n\n'
        'Pay your share here: ${pool.deepLinkUrl}\n\n'
        'Sent via PY Connect';

    Share.share(shareText, subject: 'Split Payment: ${pool.description}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split Payment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.group, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      const Text('Split the Cost', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Share a payment link with friends on WhatsApp. Everyone pays their share.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Create form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'What are you splitting?',
                        hintText: 'e.g. Villa rental in Auroville',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a description' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount (₹)',
                        hintText: 'e.g. 12000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        final amt = double.tryParse(v ?? '');
                        if (amt == null || amt <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sharesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of People',
                        hintText: 'e.g. 4',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group_outlined),
                        helperText: 'Each person pays an equal share',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 2) return 'At least 2 people';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: _creating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: Text(_creating ? 'Creating...' : 'Create & Share', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      onPressed: _creating ? null : _create,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // My pools
              Row(
                children: [
                  const Text('My Split Pools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (!_loadingPools)
                    TextButton.icon(icon: const Icon(Icons.refresh, size: 18), label: const Text('Refresh'), onPressed: _loadPools),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingPools)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_myPools.isEmpty)
                _EmptyPools()
              else
                ..._myPools.map((p) => _PoolCard(pool: p, onShare: () => _sharePool(p), onCancel: () => _cancelPool(p.id))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelPool(String id) async {
    try {
      await ref.read(splitPaymentApiProvider).cancelPool(id);
      _loadPools();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pool cancelled'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}

class _EmptyPools extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.group_off, size: 48, color: AppTheme.emerald.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No split pools yet', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 4),
            Text('Create one above to get started', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.pool, required this.onShare, required this.onCancel});
  final SplitPaymentPoolModel pool;
  final VoidCallback onShare;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final statusColor = pool.isFullyPaid ? AppTheme.emerald : pool.isActive ? AppTheme.warning : AppTheme.danger;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(pool.description, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(pool.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pool.progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(AppTheme.emerald),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${pool.collectedAmount.toStringAsFixed(0)} / ₹${pool.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${pool.claimedShares}/${pool.maxShares} claimed',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
            if (pool.contributors.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...pool.contributors.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(c.isPaid ? Icons.check_circle : Icons.pending, size: 16, color: c.isPaid ? AppTheme.emerald : AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13))),
                    Text('₹${c.shareAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (pool.isActive)
                  TextButton(onPressed: onCancel, child: const Text('Cancel', style: TextStyle(color: AppTheme.danger))),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  onPressed: onShare,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
