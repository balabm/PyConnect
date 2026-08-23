import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Walk-in luggage claim check generation screen for LuggageCloak vendors.
///
/// The partner enters the customer's name and bag count, then the backend
/// creates a LuggageDropOff record and returns a QR payload. The QR is
/// displayed on screen for the customer to scan or photograph as their
/// retrieval token.
class ClaimCheckScreen extends ConsumerStatefulWidget {
  const ClaimCheckScreen({super.key});

  @override
  ConsumerState<ClaimCheckScreen> createState() => _ClaimCheckScreenState();
}

class _ClaimCheckScreenState extends ConsumerState<ClaimCheckScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _bagCount = 1;
  bool _submitting = false;
  ClaimCheckResult? _result;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.light();
    setState(() => _submitting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final result = await api.createClaimCheck(
        customerName: _nameController.text.trim(),
        bagCount: _bagCount,
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walk-in Claim Check')),
      body: _result != null
          ? _buildQrResult(context)
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create a claim check for a walk-in customer. They will receive a QR code to present at pickup.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(height: 24),
            Text('Customer Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Raj Kumar',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null,
            ),
            const SizedBox(height: 24),
            Text('Number of Bags', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filled(
                  onPressed: _bagCount > 1 ? () => setState(() => _bagCount--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Center(
                    child: Text('$_bagCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  ),
                ),
                IconButton.filled(
                  onPressed: _bagCount < 20 ? () => setState(() => _bagCount++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.qr_code),
                label: Text(_submitting ? 'Creating...' : 'Generate Claim Check'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrResult(BuildContext context) {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: AppTheme.emerald, size: 56),
          const SizedBox(height: 16),
          Text('Claim Check Created', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
          const SizedBox(height: 8),
          Text('${r.customerName} · ${r.bagCount} bag${r.bagCount > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: r.qrPayload,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text('Ask the customer to scan this QR code or take a photo. They will need it to collect their bags.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 24),
          Text('Claim Check ID: ${r.claimCheckId}',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _result = null;
                  _nameController.clear();
                  _bagCount = 1;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('New Claim Check'),
            ),
          ),
        ],
      ),
    );
  }
}
