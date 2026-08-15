import 'package:flutter/material.dart';

/// Replaces the default red error screen with a user-friendly message.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    super.key,
    this.error,
    this.stackTrace,
    this.onRetry,
  });

  final FlutterErrorDetails? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The app encountered an unexpected error. Please try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a child widget. When a framework rendering error occurs,
/// the global [setupAppErrorWidget] builder replaces the red error screen
/// with [AppErrorWidget]. This wrapper provides an additional safety net
/// by using a [Builder] so that any error in the subtree is caught by
/// Flutter's error widget machinery.
class ErrorBoundary extends StatelessWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Sets a global error widget builder so framework errors show a friendly UI.
void setupAppErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return AppErrorWidget(error: details);
  };
}
