import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_flavor.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import '../application/vendor_auth_controller.dart';
import '../../../core/providers.dart';

/// Step 2: modern 6-digit OTP entry with auto-submit and resend cooldown.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int _secondsRemaining = 0;
  bool _hasSubmitted = false;
  bool _isAutofilling = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // Attempt OTP autofill for testing. The backend only returns the code
    // when Sms:UseMock is true (test mode). In production this is a no-op.
    // Only attempt autofill in debug mode to avoid unnecessary network calls in production.
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autofillOtp());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    _secondsRemaining = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) t.cancel();
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  /// Testing helper: asks the backend for the most recently issued OTP and
  /// fills the input boxes automatically. The backend only returns the code
  /// when the system is in SMS-mock/test mode. In production with a real SMS
  /// provider, the endpoint returns 404 and this is a silent no-op.
  ///
  /// Retries up to 5 times with 500ms delay — the OTP may not be cached
  /// immediately after the request returns (especially on the deployed
  /// backend with Redis/network latency).
  Future<void> _autofillOtp() async {
    if (_isAutofilling || _hasSubmitted) return;
    final phone = ref.read(otpRequestedForProvider);
    if (phone.isEmpty) return;

    final isPartner = ref.read(appFlavorProvider) == AppFlavor.partner;
    _isAutofilling = true;
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        if (!mounted || _hasSubmitted) return;

        final code = isPartner
            ? await ref.read(vendorAuthApiProvider).peekOtp(phone)
            : await ref.read(authApiProvider).peekOtp(phone);

        if (code != null && code.length == 6 && mounted) {
          for (var i = 0; i < 6; i++) {
            _controllers[i].text = code[i];
          }
          setState(() {});
          // Auto-submit after autofill.
          if (!_hasSubmitted) {
            _hasSubmitted = true;
            _focusNodes[5].unfocus();
            await _verify();
          }
          return;
        }

        // Wait before retrying — gives the backend cache time to settle.
        if (attempt < 4) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (_) {
      // Silently ignore — autofill is a testing convenience.
    } finally {
      _isAutofilling = false;
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-submit only once when all 6 digits are entered
    if (_otp.length == 6 && !_hasSubmitted) {
      _hasSubmitted = true;
      _focusNodes[5].unfocus();
      _verify();
    }
  }

  void _onDigitBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  /// Paste a 6-digit OTP from the clipboard. Extracts digits from the
  /// clipboard text and fills the boxes if exactly 6 digits are found.
  Future<void> _pasteOtp() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    final digits = data!.text!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 6 && mounted) {
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      setState(() {});
      if (!_hasSubmitted) {
        _hasSubmitted = true;
        _focusNodes[5].unfocus();
        _verify();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard does not contain a 6-digit OTP.')),
      );
    }
  }

  Future<void> _verify() async {
    final phone = ref.read(otpRequestedForProvider);
    final isPartner = ref.read(appFlavorProvider) == AppFlavor.partner;

    if (isPartner) {
      await ref.read(vendorAuthControllerProvider.notifier).verifyOtp(phone, _otp);
      if (!mounted) return;
      if (!ref.read(vendorAuthControllerProvider).hasError) {
        ref.read(hasSeenAuthScreenProvider.notifier).state = true;
        context.go('/');
      }
    } else {
      await ref.read(authControllerProvider.notifier).verifyOtp(phone, _otp);
      if (!mounted) return;
      if (!ref.read(authControllerProvider).hasError) {
        ref.read(hasSeenAuthScreenProvider.notifier).state = true;
        final session = ref.read(authControllerProvider).valueOrNull;
        final pending = ref.read(pendingAuthRedirectProvider);
        // First-time users must complete name/location onboarding before landing
        // on the home screen or their intended destination. Keep the pending
        // redirect so they can be returned after finishing onboarding.
        if (session != null && session.name.trim().isEmpty) {
          ref.read(pendingAuthRedirectProvider.notifier).state = pending;
          context.go('/onboarding');
        } else {
          ref.read(pendingAuthRedirectProvider.notifier).state = null;
          context.go(pending ?? '/');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(otpRequestedForProvider);
    final isPartner = ref.read(appFlavorProvider) == AppFlavor.partner;
    final authState = isPartner
        ? ref.watch(vendorAuthControllerProvider)
        : ref.watch(authControllerProvider);
    final isVerifying = authState.isLoading;
    final error = authState.error;

    if (phone.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth');
      });
      return const Scaffold(body: SizedBox());
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon with scale-in animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, size: 32, color: AppTheme.emerald),
                ),
              ),
              // Title with fade-in
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Text(
                  'Verify your number',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, height: 1.4),
                    children: [
                      const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                      TextSpan(
                        text: '+91 $phone',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Test mode hint — visible while OTP autofill is attempting (debug only)
              if (kDebugMode && _isAutofilling)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.info,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Auto-filling OTP (test mode)...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              // Error
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _friendlyError(error),
                          style: TextStyle(color: AppTheme.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 6-digit OTP boxes
              TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, offset, child) {
                  return FractionalTranslation(translation: offset, child: child);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        autofocus: index == 0,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(color: AppTheme.emerald, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                          _onDigitChanged(index, value);
                        },
                        onTap: () {
                          if (_controllers[index].text.isNotEmpty) {
                            _controllers[index].clear();
                            setState(() {});
                          }
                        },
                        onEditingComplete: () => _onDigitBackspace(index),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),
              // Paste OTP button
              if (_otp.length < 6)
                Center(
                  child: TextButton.icon(
                    onPressed: _pasteOtp,
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: const Text('Paste OTP'),
                  ),
                ),
              // Verify button
              FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
                onPressed: _otp.length == 6 && !isVerifying ? () => _verify() : null,
                child: isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),
              // Resend
              Center(
                child: TextButton(
                  onPressed: isVerifying || _secondsRemaining > 0
                      ? null
                      : () async {
                          if (isPartner) {
                            await ref.read(vendorAuthControllerProvider.notifier).requestOtp(phone);
                          } else {
                            await ref.read(authControllerProvider.notifier).requestOtp(phone);
                          }
                          if (mounted) {
                            _startCooldown();
                            // Re-attempt autofill after resend.
                            _hasSubmitted = false;
                            _isAutofilling = false;
                            _autofillOtp();
                          }
                        },
                  child: Text(
                    _secondsRemaining > 0
                        ? 'Resend OTP in ${_secondsRemaining}s'
                        : 'Resend OTP',
                    style: TextStyle(
                      color: _secondsRemaining > 0 ? Theme.of(context).colorScheme.onSurfaceVariant : AppTheme.emerald,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _friendlyError(Object? error) {
    if (error == null) return 'An unknown error occurred.';
    final raw = error.toString();
    // Auth-required / 401 — never leak raw strings.
    if (raw.contains('AuthRequiredException') ||
        raw.contains('Authentication required') ||
        raw.contains('401') ||
        raw.toLowerCase().contains('unauthorized')) {
      return 'Authentication required. Please request a new OTP.';
    }
    // Raw DioException leak — sanitize.
    if (raw.contains('DioException')) {
      if (raw.contains('connection') || raw.contains('socket')) {
        return 'Could not reach the server. Please check your connection.';
      }
      return 'Could not verify OTP. Please try again.';
    }
    final message = raw.replaceFirst('Exception: ', '');
    if (message.contains('Network') || message.contains('Socket') || message.contains('connection')) {
      return 'Could not reach the server. Please check your connection.';
    }
    if (message.toLowerCase().contains('invalid') || message.toLowerCase().contains('expired')) {
      return 'The OTP is invalid or has expired. Please request a new one.';
    }
    return message;
  }
}
