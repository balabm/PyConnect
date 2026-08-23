import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Pre-rental condition photo capture screen for ScooterRental vendors.
///
/// Guides the partner through capturing 5 standard photos (Front, Back,
/// Left, Right, Odometer/Fuel) before handing over the scooter. Creates
/// an undeniable baseline for damage claims.
class ConditionPhotosScreen extends ConsumerStatefulWidget {
  const ConditionPhotosScreen({super.key, this.rentalId});

  final String? rentalId;

  @override
  ConsumerState<ConditionPhotosScreen> createState() => _ConditionPhotosScreenState();
}

class _ConditionPhotosScreenState extends ConsumerState<ConditionPhotosScreen> {
  final _rentalIdController = TextEditingController();
  bool _submitting = false;
  bool _success = false;

  static const _angles = [
    {'key': 'front', 'label': 'Front', 'icon': Icons.arrow_forward, 'hint': 'Photo the front of the scooter (headlight, front wheel)'},
    {'key': 'back', 'label': 'Back', 'icon': Icons.arrow_back, 'hint': 'Photo the rear of the scooter (taillight, rear wheel)'},
    {'key': 'left', 'label': 'Left Side', 'icon': Icons.arrow_left, 'hint': 'Photo the left side profile of the scooter'},
    {'key': 'right', 'label': 'Right Side', 'icon': Icons.arrow_right, 'hint': 'Photo the right side profile of the scooter'},
    {'key': 'odometer', 'label': 'Odometer & Fuel', 'icon': Icons.speed, 'hint': 'Photo the odometer reading and fuel gauge'},
  ];

  final Map<String, File> _photos = {};

  @override
  void initState() {
    super.initState();
    if (widget.rentalId != null) _rentalIdController.text = widget.rentalId!;
  }

  @override
  void dispose() {
    _rentalIdController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto(String key) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
    if (photo != null) {
      AppHaptics.light();
      setState(() => _photos[key] = File(photo.path));
    }
  }

  bool get _allPhotosCaptured => _angles.every((a) => _photos.containsKey(a['key']));

  Future<void> _submit() async {
    if (_rentalIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rental ID is required'), backgroundColor: AppTheme.danger));
      return;
    }
    if (!_allPhotosCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All 5 photos are required'), backgroundColor: AppTheme.danger));
      return;
    }
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      // Build a JSON map of angle → file path. In a production system,
      // these would be uploaded to S3 first, then the URLs sent to the
      // backend. For now, we send the local paths as the JSON payload.
      // The backend stores PhotosJson as a text field.
      final photosMap = _angles.map((a) {
        final key = a['key'] as String;
        return MapEntry(key, _photos[key]!.path);
      });
      final photosJson = jsonEncode(photosMap);
      final api = ref.read(vendorDashboardApiProvider);
      await api.recordConditionPhotos(_rentalIdController.text.trim(), photosJson);
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
        appBar: AppBar(title: const Text('Condition Photos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.emerald, size: 64),
                const SizedBox(height: 16),
                const Text('Baseline Locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Condition photos recorded. This baseline will be used for damage claims if needed.',
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
      appBar: AppBar(title: const Text('Condition Photos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capture 5 standard photos before handing over the scooter. This creates an undeniable baseline for damage claims.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: _rentalIdController,
              decoration: const InputDecoration(
                labelText: 'Rental ID',
                hintText: 'Paste or scan the rental ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_2),
              ),
            ),
            const SizedBox(height: 24),
            ..._angles.map((a) {
              final key = a['key'] as String;
              final hasPhoto = _photos.containsKey(key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PhotoCaptureTile(
                  label: a['label'] as String,
                  icon: a['icon'] as IconData,
                  hint: a['hint'] as String,
                  photo: _photos[key],
                  captured: hasPhoto,
                  onTap: () => _capturePhoto(key),
                ),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting || !_allPhotosCaptured ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock),
                label: Text(_submitting ? 'Recording...' : 'Lock Condition Baseline'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCaptureTile extends StatelessWidget {
  const _PhotoCaptureTile({
    required this.label,
    required this.icon,
    required this.hint,
    this.photo,
    required this.captured,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String hint;
  final File? photo;
  final bool captured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: captured ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            // Thumbnail or placeholder
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: photo != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(photo!, fit: BoxFit.cover))
                  : Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(width: 8),
                      if (captured)
                        Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(hint, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Icon(Icons.camera_alt, color: captured ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
