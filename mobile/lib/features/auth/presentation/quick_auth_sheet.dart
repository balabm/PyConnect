import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';

/// A reusable modal bottom sheet that lets guest users authenticate via
/// phone + OTP without leaving their current screen.
///
/// Usage:
/// ```dart
/// final authenticated = await QuickAuthSheet.show(context, ref);
/// if (authenticated == true) {
///   // proceed with checkout
/// }
/// ```
///
/// The sheet handles the full flow:
/// 1. Phone number entry
/// 2. OTP request
/// 3. OTP entry + auto-fill (dev)
/// 4. OTP verification
/// 5. Returns `true` on success, `null` if dismissed
class QuickAuthSheet extends ConsumerStatefulWidget {
  const QuickAuthSheet({super.key, this.title = 'Sign in to continue'});

  final String title;

  /// Shows the quick auth sheet as a modal bottom sheet.
  /// Returns `true` if the user successfully authenticated, `null` if dismissed.
  static Future<bool?> show(BuildContext context, WidgetRef ref, {String? title}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickAuthSheet(title: title ?? 'Sign in to continue'),
    );
  }

  @override
  ConsumerState<QuickAuthSheet> createState() => _QuickAuthSheetState();
}

class _QuickAuthSheetState extends ConsumerState<QuickAuthSheet> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isOtpStage = false;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _error;
  bool _hasSubmitted = false;

  String get _phone => _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
  String get _otp => _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_phone.length != 10) return;
    AppHaptics.medium();
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).requestOtp(_phone);
      ref.read(otpRequestedForProvider.notifier).state = _phone;
      if (mounted) {
        setState(() {
          _isOtpStage = true;
          _isSending = false;
        });
        // Try auto-fill from dev peek endpoint
        _autofillOtp();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _error = 'Could not send OTP. Please try again.';
        });
      }
    }
  }

  Future<void> _autofillOtp() async {
    // Retry peek a few times with a short delay — the OTP may not be
    // cached yet immediately after the request returns.
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!mounted || _hasSubmitted) return;
      try {
        final code = await ref.read(authApiProvider).peekOtp(_phone);
        if (code != null && code.length == 6 && mounted) {
          for (var i = 0; i < 6; i++) {
            _otpControllers[i].text = code[i];
          }
          setState(() {});
          if (!_hasSubmitted) {
            _hasSubmitted = true;
            _focusNodes[5].unfocus();
            await _verifyOtp();
          }
          return;
        }
      } catch (_) {
        // Silent — autofill is a testing convenience
      }
      // Wait before retrying
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;
    AppHaptics.light();
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(_phone, _otp);
      if (!mounted) return;
      if (!ref.read(authControllerProvider).hasError) {
        AppHaptics.medium();
        Navigator.of(context).pop(true);
      } else {
        final err = ref.read(authControllerProvider).error;
        setState(() {
          _isVerifying = false;
          _error = err is Exception ? err.toString() : 'Invalid or expired OTP.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _error = 'Invalid or expired OTP. Please try again.';
        });
      }
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6 && !_hasSubmitted) {
      _hasSubmitted = true;
      _focusNodes[5].unfocus();
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _isOtpStage
                    ? 'Enter the 6-digit code sent to +91 $_phone'
                    : 'Enter your mobile number to get started',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              if (!_isOtpStage) _buildPhoneStage() else _buildOtpStage(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone input
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            prefixText: '+91 ',
            labelText: 'Mobile Number',
            hintText: '90000 00000',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onChanged: (v) {
            final clean = v.replaceAll(RegExp(r'[^0-9]'), '');
            if (clean != v) {
              _phoneController.text = clean;
              _phoneController.selection = TextSelection.fromPosition(
                TextPosition(offset: clean.length),
              );
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        // Get OTP button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _phone.length == 10 && !_isSending ? _requestOtp : null,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Get OTP'),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OTP input boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 48,
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onChanged: (v) => _onOtpChanged(i, v),
                onTap: () {
                  _otpControllers[i].clear();
                  _hasSubmitted = false;
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Verify button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _otp.length == 6 && !_isVerifying ? _verifyOtp : null,
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify & Continue'),
          ),
        ),
        const SizedBox(height: 8),
        // Resend / change number
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isVerifying
                  ? null
                  : () {
                      setState(() {
                        _isOtpStage = false;
                        _error = null;
                        _hasSubmitted = false;
                        for (final c in _otpControllers) {
                          c.clear();
                        }
                      });
                    },
              child: const Text('Change number'),
            ),
            TextButton(
              onPressed: _isVerifying ? null : _requestOtp,
              child: const Text('Resend OTP'),
            ),
          ],
        ),
      ],
    );
  }
}
