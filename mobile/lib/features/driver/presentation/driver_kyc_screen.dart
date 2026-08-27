import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';
import '../domain/driver_models.dart';

/// Driver KYC document upload screen.
///
/// Displays five upload zones (Aadhaar, Driving License, Vehicle RC,
/// Commercial Insurance, Driver Selfie). Tapping a zone opens a bottom
/// sheet to choose camera or gallery — except the selfie slot which
/// opens the camera directly. Once all five are selected, the driver
/// enters their UPI ID and submits.
class DriverKycScreen extends ConsumerStatefulWidget {
  const DriverKycScreen({super.key});

  @override
  ConsumerState<DriverKycScreen> createState() => _DriverKycScreenState();
}

class _DriverKycScreenState extends ConsumerState<DriverKycScreen> {
  final _upiController = TextEditingController();

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  void _showSourceSheet(int index) {
    final slots = ref.read(kycSlotsProvider);
    final slot = slots[index];
    AppHaptics.light();

    // Camera-only slots (e.g. Driver Selfie) skip the bottom sheet and
    // directly open the camera.
    if (slot.cameraOnly) {
      _pickAndSet(index, ImageSourceChoice.camera);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => AppBottomSheet(
        title: 'Upload Document',
        subtitle: 'Choose how you want to add this document',
        child: Column(
          children: [
            _SourceOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSet(index, ImageSourceChoice.camera);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _SourceOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSet(index, ImageSourceChoice.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSet(int index, ImageSourceChoice choice) async {
    final picker = ref.read(filePickerServiceProvider);
    final file = await picker.pickImage(choice);
    if (file == null) return;
    ref.read(kycSlotsProvider.notifier).setFile(index, file);
    AppHaptics.selection();
  }

  Future<void> _submitKyc() async {
    final slots = ref.read(kycSlotsProvider);
    final upiId = _upiController.text.trim();

    if (slots.any((s) => s.file == null)) {
      AppToast.show(context, 'Please upload all required documents',
          type: ToastType.warning);
      return;
    }
    if (upiId.isEmpty || !upiId.contains('@')) {
      AppToast.show(context, 'Please enter a valid UPI ID',
          type: ToastType.warning);
      return;
    }

    ref.read(kycSubmittingProvider.notifier).state = true;
    AppHaptics.medium();

    try {
      final api = ref.read(driverApiProvider);

      // Retry the primary KYC upload up to 3 times to handle transient
      // TLS resets on the deployed backend. Multipart uploads are more
      // susceptible to connection drops than regular JSON API calls.
      KycUploadResult? result;
      Exception? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          result = await api.uploadKyc(
            aadhaar: slots[0].file!,
            drivingLicense: slots[1].file!,
            rc: slots[2].file!,
            upiId: upiId,
          );
          lastError = null;
          break;
        } on Exception catch (e) {
          lastError = e;
          if (attempt < 2) {
            if (mounted) {
              AppToast.show(
                context,
                'Upload attempt ${attempt + 1} failed. Retrying...',
                type: ToastType.warning,
              );
            }
            await Future.delayed(Duration(seconds: 3 * (attempt + 1)));
          }
        }
      }

      if (lastError != null) throw lastError;
      if (result == null) throw Exception('KYC upload failed with no response.');

      // Upload the extended documents (Commercial Insurance + Driver Selfie)
      // via the extended KYC endpoint. Retry up to 2 times.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await api.uploadExtendedKyc(
            insurance: slots[3].file,
            selfie: slots[4].file,
          );
          break;
        } on Exception catch (_) {
          if (attempt < 1) await Future.delayed(const Duration(seconds: 3));
          // Extended upload failure is non-blocking — the primary KYC
          // may still succeed. Log silently.
        }
      }

      if (result.success && mounted) {
        AppHaptics.success();
        AppToast.show(context, result.message, type: ToastType.success);
        ref.read(kycSlotsProvider.notifier).reset();
        // Refresh the driver profile so the pending/approval router guard
        // immediately reflects the uploaded KYC state.
        ref.invalidate(driverProfileProvider);
        context.go('/pending-verification');
      } else if (mounted) {
        AppHaptics.error();
        AppToast.show(context, result.message, type: ToastType.error);
      }
    } on Exception catch (e) {
      if (mounted) {
        AppHaptics.error();
        AppToast.show(
          context,
          _friendlyError(e.toString()),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) ref.read(kycSubmittingProvider.notifier).state = false;
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('AuthRequiredException') ||
        raw.contains('401') ||
        raw.toLowerCase().contains('unauthorized')) {
      return 'Authentication required. Please sign in again.';
    }
    if (raw.contains('DioException') || raw.contains('Socket')) {
      return 'Could not reach the server. Please check your connection.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(kycSlotsProvider);
    final allSelected = ref.watch(kycAllFilesSelectedProvider);
    final isSubmitting = ref.watch(kycSubmittingProvider);
    final profileAsync = ref.watch(driverProfileProvider);
    final profile = profileAsync.valueOrNull;

    // If KYC is already uploaded and approved, show the approved state
    // instead of the upload form.
    final kycApproved = profile?.isKycUploaded == true && profile?.isApproved == true;
    final kycUploadedPending = profile?.isKycUploaded == true && profile?.isApproved != true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppHaptics.light();
            context.go('/');
          },
        ),
      ),
      body: kycApproved
          ? _KycApprovedView(upiId: profile?.upiId)
          : kycUploadedPending
              ? _KycPendingView(upiId: profile?.upiId)
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.verified_user_outlined,
                                      color: Theme.of(context).colorScheme.primary, size: 24),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Complete your KYC',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Upload documents to start accepting rides',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),

                      // Upload zones
                      ...List.generate(slots.length, (i) {
                        return _KycUploadCard(
                          slot: slots[i],
                          onTap: () => _showSourceSheet(i),
                        );
                      }),

                      // UPI ID field
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UPI ID for payouts',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextField(
                              controller: _upiController,
                              decoration: const InputDecoration(
                                hintText: 'yourname@upi',
                                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.text,
                            ),
                          ],
                        ),
                      ),

                      // Submit button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.lg,
                        ),
                        child: GradientButton(
                          label: isSubmitting ? 'Uploading...' : 'Submit KYC',
                          icon: Icons.cloud_upload_outlined,
                          enabled: allSelected && !isSubmitting,
                          loading: isSubmitting,
                          onPressed: _submitKyc,
                        ),
                      ),

                      // Security note
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Your documents are encrypted and stored privately. Only verified admin staff can review them.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
    );
  }
}

/// A single KYC document upload card.
class _KycUploadCard extends StatelessWidget {
  const _KycUploadCard({required this.slot, required this.onTap});

  final KycDocumentSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasFile = slot.file != null;
    final isUploading = slot.status == KycDocStatus.uploading;
    final hasError = slot.status == KycDocStatus.error;

    return AppCard(
      onTap: isUploading ? null : onTap,
      child: Row(
        children: [
          // Thumbnail / icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hasFile
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasFile
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      slot.file!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(slot.icon,
                          color: Theme.of(context).colorScheme.primary, size: 28),
                    ),
                  )
                : Icon(slot.icon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 28),
          ),
          const SizedBox(width: AppSpacing.md),

          // Label + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                if (isUploading)
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Uploading...',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    ],
                  )
                else if (hasError)
                  Text(slot.errorMessage ?? 'Upload failed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.danger, fontSize: 12))
                else if (hasFile)
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text('Ready to submit',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                    ],
                  )
                else
                  Text('Tap to upload',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 12)),
              ],
            ),
          ),

          // Status badge
          if (hasFile && !isUploading)
            const StatusBadge(
              label: 'Added',
              variant: BadgeVariant.success,
              icon: Icons.check,
            )
          else if (!hasFile && !isUploading)
            const StatusBadge(
              label: 'Required',
              variant: BadgeVariant.warning,
            ),
        ],
      ),
    );
  }
}

/// A selectable option in the source picker bottom sheet.
class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when KYC documents have been uploaded and admin has approved them.
class _KycApprovedView extends StatelessWidget {
  const _KycApprovedView({this.upiId});
  final String? upiId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified, size: 64, color: AppTheme.emerald),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'KYC Approved',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your documents have been verified. You are cleared to accept rides.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (upiId != null && upiId!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payout UPI ID',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  )),
                          Text(upiId!,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when KYC documents have been uploaded but admin hasn't approved yet.
class _KycPendingView extends StatelessWidget {
  const _KycPendingView({this.upiId});
  final String? upiId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top, size: 64, color: AppTheme.warning),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'KYC Under Review',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warning,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your documents have been submitted and are pending admin review. You will be able to accept rides once approved.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (upiId != null && upiId!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payout UPI ID',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  )),
                          Text(upiId!,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.go('/pending-verification'),
              icon: const Icon(Icons.refresh),
              label: const Text('Check Status'),
            ),
          ],
        ),
      ),
    );
  }
}
