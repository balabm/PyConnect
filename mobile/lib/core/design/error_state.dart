import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../theme/app_theme.dart';

/// Reusable error state with icon, message, and retry button.
///
/// Detects [AuthRequiredException] and shows a "Sign In" button instead of
/// a generic retry, so the user is smoothly redirected to the login flow
/// rather than seeing a raw 401 error string.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isAuthError = _isAuthError(message);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (isAuthError ? AppTheme.emerald : AppTheme.coral)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAuthError ? Icons.lock_outline : Icons.cloud_off,
                size: 32,
                color: isAuthError ? AppTheme.emerald : AppTheme.coral,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isAuthError ? 'Sign in required' : 'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isAuthError
                  ? 'Authentication required. Please log in.'
                  : 'Something went wrong while connecting to PY Connect. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isAuthError)
              FilledButton.icon(
                onPressed: () => context.go('/auth'),
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
              )
            else if (onRetry != null)
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Detects auth-related errors from a raw error string.
/// Catches [AuthRequiredException], 401 status codes, "unauthorized",
/// and raw [DioException] strings that may leak from providers.
bool _isAuthError(String message) {
  final lower = message.toLowerCase();
  return message.contains('Authentication required') ||
      message.contains('AuthRequiredException') ||
      message.contains('401') ||
      lower.contains('unauthorized') ||
      (lower.contains('dioexception') && lower.contains('bad response'));
}

/// A riverpod-aware variant that can detect [AuthRequiredException] from
/// the error object directly (not just the string), for screens that have
/// access to the raw error.
class AuthAwareErrorState extends ConsumerWidget {
  const AuthAwareErrorState({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthError = error is AuthRequiredException ||
        _isAuthError(error.toString());

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (isAuthError ? AppTheme.emerald : AppTheme.coral)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAuthError ? Icons.lock_outline : Icons.cloud_off,
                size: 32,
                color: isAuthError ? AppTheme.emerald : AppTheme.coral,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isAuthError ? 'Sign in required' : 'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isAuthError
                  ? 'Authentication required. Please log in.'
                  : 'Something went wrong while connecting to PY Connect. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isAuthError)
              FilledButton.icon(
                onPressed: () => context.go('/auth'),
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
              )
            else if (onRetry != null)
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
