import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Bag intake screen for LuggageCloak vendors.
///
/// The partner selects a pending luggage drop-off, photographs the bags
/// with security tags, and uploads the intake photo. This transitions
/// the status from Reserved to Dropped and creates a liability baseline.
class BagIntakeScreen extends ConsumerStatefulWidget {
  const BagIntakeScreen({super.key, this.dropOffId});

  final String? dropOffId;

  @override
  ConsumerState<BagIntakeScreen> createState() => _BagIntakeScreenState();
}

class _BagIntakeScreenState extends ConsumerState<BagIntakeScreen> {
  final _idController = TextEditingController();
  File? _photo;
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
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final photo = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
    if (photo != null) setState(() => _photo = File(photo.path));
  }

  Future<void> _submit() async {
    if (_idController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drop-off ID is required'), backgroundColor: AppTheme.danger));
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intake photo is required'), backgroundColor: AppTheme.danger));
      return;
    }
    AppHaptics.light();
    setState(() => _submitting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.receiveBags(_idController.text.trim(), _photo!);
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
        appBar: AppBar(title: const Text('Bag Intake')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.emerald, size: 64),
                const SizedBox(height: 16),
                const Text('Bags Received & Secured', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('The customer has been notified that their bags are secured.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 32),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bag Intake')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photograph the bags with security tags before accepting them into custody. This creates a liability baseline.',
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
            Text('Intake Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _photo == null ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.emerald),
                ),
                child: _photo != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_photo!, fit: BoxFit.cover))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('Tap to capture intake photo', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock),
                label: Text(_submitting ? 'Securing...' : 'Receive & Secure Bags'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
