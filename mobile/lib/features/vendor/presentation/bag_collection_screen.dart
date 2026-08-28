import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Bag collection screen for LuggageCloak vendors.
///
/// The partner enters the 6-digit retrieval PIN from the customer (or
/// scans their QR code). The backend verifies the PIN and transitions
/// the drop-off from Dropped to Collected, closing the liability loop.
class BagCollectionScreen extends ConsumerStatefulWidget {
  const BagCollectionScreen({super.key, this.dropOffId});

  final String? dropOffId;

  @override
  ConsumerState<BagCollectionScreen> createState() => _BagCollectionScreenState();
}

class _BagCollectionScreenState extends ConsumerState<BagCollectionScreen> {
  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  bool _submitting = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (widget.dropOffId != null) _idController.text = widget.dropOffId!;
  }

  @override
  void dispose() {
    _idController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_pinController.text.length >= 6) return;
    AppHaptics.light();
    setState(() => _pinController.text += digit);
  }

  void _removeDigit() {
    if (_pinController.text.isEmpty) return;
    AppHaptics.light();
    setState(() => _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1));
  }

  Future<void> _submit() async {
    if (_idController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drop-off ID is required'), backgroundColor: AppTheme.danger));
      return;
    }
    if (_pinController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 6 digits'), backgroundColor: AppTheme.danger));
      return;
    }
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.collectBags(_idController.text.trim(), _pinController.text);
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collect Bags')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.emerald, size: 64),
                const SizedBox(height: 16),
                const Text('Bags Returned', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('The customer has been notified that their bags have been collected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 32),
                FilledButton(onPressed: () {
                  ref.invalidate(vendorBookingsProvider);
                  Navigator.of(context).pop();
                }, child: const Text('Done')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Collect Bags')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the 6-digit PIN from the customer to verify bag collection and close the liability loop.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(height: 24),
            Text('Drop-off ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                hintText: 'Paste or scan the drop-off ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_2),
              ),
            ),
            const SizedBox(height: 24),
            Text('Retrieval PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            // PIN display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < _pinController.text.length;
                return Container(
                  width: 44,
                  height: 56,
                  margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: filled ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15), width: 2),
                  ),
                  child: Center(
                    child: filled
                        ? Text('*', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.emerald))
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Numeric keypad
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                  _KeypadButton(label: d, onTap: () => _addDigit(d)),
                _KeypadButton(label: '⌫', onTap: _removeDigit, isBackspace: true),
                _KeypadButton(label: '0', onTap: () => _addDigit('0')),
                SizedBox(height: 56, child: FilledButton(
                  onPressed: _submitting || _pinController.text.length != 6 ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 24),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onTap, this.isBackspace = false});
  final String label;
  final VoidCallback onTap;
  final bool isBackspace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
