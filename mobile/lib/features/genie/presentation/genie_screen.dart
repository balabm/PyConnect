import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../data/genie_api.dart';

/// The Genie Engine screen — a free-text errand creator.
///
/// Users type anything they need (e.g. "Pick up my laundry from Auroville"
/// or "Buy medicines from Apollo Pharmacy on MG Road") and set an estimated
/// cost. The platform places an auth-hold on their card for the captain to
/// go purchase/collect the item.
class GenieScreen extends ConsumerStatefulWidget {
  const GenieScreen({super.key});

  @override
  ConsumerState<GenieScreen> createState() => _GenieScreenState();
}

class _GenieScreenState extends ConsumerState<GenieScreen> {
  final _formKey = GlobalKey<FormState>();
  final _errandCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  bool _submitting = false;
  List<GenieErrandModel> _myErrands = [];
  bool _loadingErrands = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadErrands());
  }

  @override
  void dispose() {
    _errandCtrl.dispose();
    _costCtrl.dispose();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadErrands() async {
    try {
      final errands = await ref.read(genieApiProvider).myErrands();
      if (mounted) {
        setState(() {
          _myErrands = errands;
          _loadingErrands = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingErrands = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    AppHaptics.light();
    setState(() => _submitting = true);

    try {
      final cost = double.tryParse(_costCtrl.text) ?? 0;
      await ref.read(genieApiProvider).createErrand(
            description: _errandCtrl.text.trim(),
            estimatedCost: cost,
            pickupAddress: _pickupCtrl.text.trim().isEmpty ? null : _pickupCtrl.text.trim(),
            dropoffAddress: _dropoffCtrl.text.trim().isEmpty ? null : _dropoffCtrl.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errand posted! A captain will accept it shortly.'),
            backgroundColor: AppTheme.emerald,
          ),
        );
        _errandCtrl.clear();
        _costCtrl.clear();
        _pickupCtrl.clear();
        _dropoffCtrl.clear();
        _loadErrands();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post errand: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Genie')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.coral, AppTheme.coralLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          'Genie Engine',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type anything you need. A captain will pick it up, buy it, or deliver it.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _errandCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'What do you need?',
                        hintText: 'e.g. Pick up my laundry from Auroville, or buy medicines from Apollo Pharmacy',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please describe your errand' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimated Cost (₹)',
                        hintText: 'e.g. 500',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments_outlined),
                        helperText: 'Auth-hold will be placed on your card',
                      ),
                      validator: (v) {
                        final cost = double.tryParse(v ?? '');
                        if (cost == null || cost < 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pickupCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Location (optional)',
                        hintText: 'Where the captain should go',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store_mall_directory_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dropoffCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dropoff Location (optional)',
                        hintText: 'Where to deliver to you',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.coral,
                      ),
                      icon: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: Text(_submitting ? 'Posting...' : 'Post Errand', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // My errands
              Row(
                children: [
                  const Text('My Errands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (!_loadingErrands)
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      onPressed: _loadErrands,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingErrands)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_myErrands.isEmpty)
                _EmptyErrands()
              else
                ..._myErrands.map((e) => _ErrandCard(errand: e, onCancel: () => _cancelErrand(e.id))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelErrand(String id) async {
    try {
      await ref.read(genieApiProvider).cancelErrand(id);
      _loadErrands();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errand cancelled'), backgroundColor: AppTheme.danger),
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

class _EmptyErrands extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.auto_awesome, size: 48, color: AppTheme.coral.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No errands yet', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 4),
            Text('Post your first errand above', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

class _ErrandCard extends StatelessWidget {
  const _ErrandCard({required this.errand, required this.onCancel});
  final GenieErrandModel errand;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(errand.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(errand.description, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(errand.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text('₹${errand.estimatedCost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(_formatDate(errand.createdAt), style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
            if (errand.pickupAddress != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.store_mall_directory_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(child: Text(errand.pickupAddress!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (errand.dropoffAddress != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.home_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(child: Text(errand.dropoffAddress!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (errand.isActive) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onCancel, child: const Text('Cancel', style: TextStyle(color: AppTheme.danger))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppTheme.emerald;
      case 'Cancelled':
        return AppTheme.danger;
      case 'InProgress':
        return AppTheme.warning;
      case 'Accepted':
        return const Color(0xFF2196F3);
      default:
        return AppTheme.coral;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
