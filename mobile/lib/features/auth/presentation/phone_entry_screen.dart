import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/modern_animations.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/config/app_flavor.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import '../application/vendor_auth_controller.dart';

/// Toggle while Google Sign-In client IDs are being configured.
const _kShowGoogleSignIn = false;

/// Step 1: sleek onboarding login screen with brand gradient, +91 prefix,
/// and "Continue as Guest" option. Modern animations throughout.
class PhoneEntryScreen extends ConsumerWidget {
  const PhoneEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(phoneNumberProvider);
    final isPartner = resolvedAppFlavor == AppFlavor.partner;
    final isDriver = resolvedAppFlavor == AppFlavor.driver;
    final authState = isPartner
        ? ref.watch(vendorAuthControllerProvider)
        : ref.watch(authControllerProvider);
    final isSending = authState.isLoading;
    final error = authState.error;
    final socialPending = ref.watch(socialAuthPendingProvider);
    final isGoogleLinking = socialPending != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.emerald, AppTheme.emeraldDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- Top brand area with gradient ---
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      // Logo circle with bounce-in animation
                      BounceIn(
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.waves,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Brand name with fade-in
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 500),
                        offset: const Offset(0, 0.1),
                        child: const Text(
                          'PY Connect',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 350),
                        duration: const Duration(milliseconds: 500),
                        offset: const Offset(0, 0.1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Your all-in-one Pondicherry companion.\nFrom arrival to departure.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // --- Bottom card with form ---
              Expanded(
                flex: 3,
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 500),
                  offset: const Offset(0, 0.08),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            isGoogleLinking ? 'Finish with Google' : 'Welcome',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isGoogleLinking
                                ? 'Enter your mobile number to link ${socialPending.name}.'
                                : 'Enter your mobile number to get started',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Error message
                          if (error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
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
                          // Phone input with +91 prefix
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  child: Row(
                                    children: [
                                      Text(
                                        '\u{1F1EE}\u{1F1F3} +91',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(width: 1, height: 24, color: Theme.of(context).dividerColor),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.5,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '98765 43210',
                                      counterText: '',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    ),
                                    onChanged: (v) =>
                                        ref.read(phoneNumberProvider.notifier).state = v.replaceAll(RegExp(r'[^0-9]'), ''),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Get OTP button
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                            ),
                            onPressed: phone.length == 10 && !isSending
                                ? () async {
                                    AppHaptics.medium();
                                    if (isPartner) {
                                      await ref
                                          .read(vendorAuthControllerProvider.notifier)
                                          .requestOtp(phone);
                                    } else {
                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .requestOtp(phone);
                                    }
                                    if (context.mounted) context.go('/auth/otp');
                                  }
                                : null,
                            child: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Get OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 20),
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ),
                              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Google sign-in (consumer only — vendors must authenticate)
                          if (_kShowGoogleSignIn && !isPartner)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                side: BorderSide(color: Theme.of(context).dividerColor),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                              onPressed: isSending
                                  ? null
                                  : () async {
                                      AppHaptics.medium();
                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .signInWithGoogle();
                                    },
                              icon: const Icon(Icons.g_mobiledata, size: 24),
                              label: const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Continue as Guest (consumer only — vendors must authenticate)
                          if (!isPartner)
                            TextButton(
                              onPressed: () {
                                ref.read(hasSeenAuthScreenProvider.notifier).state = true;
                                context.go('/');
                              },
                              child: Text(
                                'Continue as Guest',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          // Register your business (partner only)
                          if (isPartner) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                AppHaptics.light();
                                context.go('/register');
                              },
                              icon: const Icon(Icons.store_outlined, size: 18),
                              label: const Text(
                                'Register your business',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          // Become a Captain (driver only)
                          if (isDriver) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                AppHaptics.light();
                                context.go('/register');
                              },
                              icon: const Icon(Icons.two_wheeler_outlined, size: 18),
                              label: const Text(
                                'Become a Captain',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
    // Auth-required errors — never show raw DioException/401 strings.
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
      return 'Could not send OTP. Please try again.';
    }
    final message = raw.replaceFirst('Exception: ', '');
    if (message.contains('Network') || message.contains('Socket') || message.contains('connection')) {
      return 'Could not reach the server. Please check your connection.';
    }
    return message;
  }
}
