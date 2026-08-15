import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Screen shown after a driver submits KYC documents, while their
/// profile is pending admin verification. Blocks going online until approved.
class DriverPendingVerificationScreen extends StatelessWidget {
  const DriverPendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Verification Pending'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated verification icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + 0.2 * value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    size: 56,
                    color: AppTheme.emerald,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verification in Progress',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your KYC documents have been submitted successfully. '
                'Our admin team is reviewing your profile. '
                'You will be able to go online once approved.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Status timeline
              _StatusStep(
                icon: Icons.check_circle,
                label: 'Registration Complete',
                isDone: true,
              ),
              _StatusStep(
                icon: Icons.check_circle,
                label: 'KYC Documents Uploaded',
                isDone: true,
              ),
              _StatusStep(
                icon: Icons.check_circle,
                label: 'Safety Tutorial Completed',
                isDone: true,
              ),
              _StatusStep(
                icon: Icons.hourglass_top,
                label: 'Admin Review',
                isDone: false,
              ),
              _StatusStep(
                icon: Icons.lock_clock,
                label: 'Ready to Drive',
                isDone: false,
              ),
              const SizedBox(height: 32),
              // Refresh button
              OutlinedButton.icon(
                onPressed: () {
                  // Refresh the driver profile to check if approved
                  context.go('/');
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  side: const BorderSide(color: AppTheme.emerald),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Contact support
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('For verification issues, call +91-XXXX-XXXXXX'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                child: Text(
                  'Need help? Contact support',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.icon,
    required this.label,
    required this.isDone,
  });

  final IconData icon;
  final String label;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDone ? AppTheme.emerald : AppTheme.slate,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
              color: isDone ? AppTheme.charcoal : AppTheme.slate,
            ),
          ),
          const Spacer(),
          if (isDone)
            const Icon(Icons.check, size: 16, color: AppTheme.emerald)
          else
            Icon(Icons.pending, size: 16, color: AppTheme.slate.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}
