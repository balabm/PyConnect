import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

class VendorPromotionsScreen extends ConsumerWidget {
  const VendorPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(vendorPromotionsProvider);
    final flashAsync = ref.watch(vendorFlashPromosProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          title: const Text('Promotions & Flash Sales'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Promotions', icon: Icon(Icons.local_offer)),
              Tab(text: 'Flash Sales', icon: Icon(Icons.flash_on)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PromotionsTab(promosAsync: promosAsync, ref: ref),
            _FlashSalesTab(flashAsync: flashAsync, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _PromotionsTab extends StatelessWidget {
  const _PromotionsTab({required this.promosAsync, required this.ref});
  final AsyncValue<List<VendorPromotionModel>> promosAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _CreatePromotionForm(ref: ref),
        ),
        Expanded(
          child: promosAsync.when(
            loading: () => const ShimmerList(withImage: false, count: 3),
            error: (e, _) => ErrorState(
              message: 'Failed to load promotions: $e',
              onRetry: () => ref.read(vendorPromotionsProvider.notifier).load(),
            ),
            data: (promos) {
              if (promos.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_offer_outlined,
                  title: 'No active promotions',
                  subtitle: 'Create one above to boost sales',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: promos.length,
                itemBuilder: (context, i) {
                  final promo = promos[i];
                  return _PromotionCard(promo: promo);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreatePromotionForm extends StatefulWidget {
  const _CreatePromotionForm({required this.ref});
  final WidgetRef ref;

  @override
  State<_CreatePromotionForm> createState() => _CreatePromotionFormState();
}

class _CreatePromotionFormState extends State<_CreatePromotionForm> {
  final _discountController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _expiry;
  bool _submitting = false;

  @override
  void dispose() {
    _discountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );
      if (time != null) {
        setState(() {
          _expiry = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_discountController.text.isEmpty || _expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount and expiry are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.ref.read(vendorPromotionsProvider.notifier).createPromotion(
        CreatePromotionPayload(
          discountPercentage: double.parse(_discountController.text.trim()),
          expiresAt: _expiry!.toUtc().toIso8601String(),
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
      );
      _discountController.clear();
      _titleController.clear();
      _descriptionController.clear();
      setState(() => _expiry = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promotion created!'),
            backgroundColor: AppTheme.lagoon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Promotion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    AppHaptics.light();
                    _pickExpiry();
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiry',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _expiry != null
                          ? '${_expiry!.day}/${_expiry!.month} ${_expiry!.hour}:${_expiry!.minute.toString().padLeft(2, '0')}'
                          : 'Tap to pick date & time',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              hintText: 'e.g. Happy Hours',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : () {
                AppHaptics.medium();
                _submit();
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.lagoon),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Promotion', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.promo});
  final VendorPromotionModel promo;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.coral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_offer, color: AppTheme.coral),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title ?? 'Promotion',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                if (promo.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    promo.description!,
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                FareRow(
                  label: 'Discount',
                  value: '${promo.discountPercentage.toStringAsFixed(0)}%',
                  bold: true,
                  valueColor: AppTheme.coral,
                ),
                if (promo.expiresAt.isNotEmpty)
                  FareRow(
                    label: 'Expires',
                    value: _formatDate(promo.expiresAt),
                    small: true,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: promo.isActive ? 'Active' : 'Expired',
            variant: promo.isActive ? BadgeVariant.success : BadgeVariant.neutral,
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _FlashSalesTab extends StatelessWidget {
  const _FlashSalesTab({required this.flashAsync, required this.ref});
  final AsyncValue<List<FlashPromoModel>> flashAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _CreateFlashPromoForm(ref: ref),
        ),
        Expanded(
          child: flashAsync.when(
            loading: () => const ShimmerList(withImage: false, count: 3),
            error: (e, _) => ErrorState(
              message: 'Failed to load flash sales: $e',
              onRetry: () => ref.read(vendorFlashPromosProvider.notifier).load(),
            ),
            data: (promos) {
              if (promos.isEmpty) {
                return const EmptyState(
                  icon: Icons.flash_off,
                  title: 'No flash sales yet',
                  subtitle: 'Create a time-limited flash sale above',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: promos.length,
                itemBuilder: (context, i) {
                  final promo = promos[i];
                  return _FlashPromoCard(promo: promo);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreateFlashPromoForm extends StatefulWidget {
  const _CreateFlashPromoForm({required this.ref});
  final WidgetRef ref;

  @override
  State<_CreateFlashPromoForm> createState() => _CreateFlashPromoFormState();
}

class _CreateFlashPromoFormState extends State<_CreateFlashPromoForm> {
  final _discountController = TextEditingController();
  final _durationController = TextEditingController();
  final _titleController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _discountController.dispose();
    _durationController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_discountController.text.isEmpty || _durationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount and duration are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.ref.read(vendorFlashPromosProvider.notifier).createFlashPromo(
        CreateFlashPromoPayload(
          discountPercentage: double.parse(_discountController.text.trim()),
          durationMinutes: int.parse(_durationController.text.trim()),
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        ),
      );
      _discountController.clear();
      _durationController.clear();
      _titleController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash sale launched!'),
            backgroundColor: AppTheme.lagoon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Launch Flash Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (min)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 30, 60, 120',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              hintText: 'e.g. Lunch Flash Sale',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : () {
                AppHaptics.medium();
                _submit();
              },
              icon: const Icon(Icons.flash_on),
              label: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Launch Flash Sale', style: TextStyle(fontSize: 16, color: Colors.white)),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashPromoCard extends StatelessWidget {
  const _FlashPromoCard({required this.promo});
  final FlashPromoModel promo;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.flash_on, color: AppTheme.gold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title ?? 'Flash Sale',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 6),
                FareRow(
                  label: 'Discount',
                  value: '${promo.discountPercentage.toStringAsFixed(0)}%',
                  bold: true,
                  valueColor: AppTheme.coral,
                ),
                FareRow(
                  label: 'Duration',
                  value: '${promo.durationMinutes} min',
                  small: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: promo.isActive ? 'Live' : 'Ended',
            variant: promo.isActive ? BadgeVariant.warning : BadgeVariant.neutral,
          ),
        ],
      ),
    );
  }
}
