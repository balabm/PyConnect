import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_theme.dart';

/// A full-screen interceptor UI shown BEFORE the system-level location
/// permission prompt. Apple App Store and Google Play Protect require
/// apps to provide explicit, human-readable justification for background
/// location access before requesting it.
///
/// The Consumer app explains that location is used to find nearby drivers,
/// track food delivery, and ensure ride safety.
///
/// The Captain app explicitly states that location data is collected in
/// the background to dispatch rides even when the app is closed.
class LocationPermissionInterceptor {
  LocationPermissionInterceptor._();

  /// Shows the interceptor and then requests the system permission.
  /// Returns `true` if the user granted permission, `false` otherwise.
  ///
  /// Set [isDriver] to true for the Captain app to show driver-specific
  /// messaging about background location collection.
  static Future<bool> showAndRequest(
    BuildContext context, {
    bool isDriver = false,
  }) async {
    // Check if permission is already granted — skip the interceptor.
    final currentPermission = await Geolocator.checkPermission();
    if (currentPermission == LocationPermission.always ||
        currentPermission == LocationPermission.whileInUse) {
      return true;
    }

    // Show the full-screen interceptor UI.
    final shouldContinue = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _InterceptorScreen(isDriver: isDriver),
        fullscreenDialog: true,
      ),
    );

    if (shouldContinue != true) return false;

    // Now request the system-level permission.
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return true;
    }

    // Permission was denied — show a dialog explaining why it's needed
    // and provide a button to open OS settings.
    if (context.mounted) {
      await _showPermissionDeniedDialog(context, isDriver);
    }
    return false;
  }

  /// Shows a dialog when the user denies location permission, explaining
  /// why the app needs it and providing a button to open OS settings.
  static Future<void> _showPermissionDeniedDialog(
    BuildContext context,
    bool isDriver,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off, color: AppTheme.warning, size: 48),
        title: const Text('Location Permission Required'),
        content: Text(
          isDriver
              ? 'PY Connect Captain needs location access to dispatch rides to you and navigate to pickup points. Without it, you cannot receive ride offers.\n\nPlease enable location permission in your device settings.'
              : 'PY Connect needs location access to find nearby drivers, track your food delivery, and ensure ride safety.\n\nPlease enable location permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
          ),
        ],
      ),
    );
  }
}

class _InterceptorScreen extends StatelessWidget {
  const _InterceptorScreen({required this.isDriver});

  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const Spacer(),
              // Location icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDriver
                        ? [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.7)]
                        : [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                isDriver ? 'Location Access for Captain' : 'Location Access',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Justification text
              if (isDriver) ...[
                _JustificationPoint(
                  icon: Icons.directions_car,
                  text: 'PY Connect Captain collects location data in the background to dispatch rides to you even when the app is closed or not in use.',
                ),
                const SizedBox(height: 16),
                _JustificationPoint(
                  icon: Icons.navigation,
                  text: 'Your live location enables turn-by-turn navigation to pickup and dropoff points.',
                ),
                const SizedBox(height: 16),
                _JustificationPoint(
                  icon: Icons.security,
                  text: 'Background location ensures rider safety — the consumer can track their ride until completion.',
                ),
              ] else ...[
                _JustificationPoint(
                  icon: Icons.directions_car,
                  text: 'PY Connect needs your location to find nearby drivers and show accurate ETAs.',
                ),
                const SizedBox(height: 16),
                _JustificationPoint(
                  icon: Icons.restaurant,
                  text: 'Track your incoming food delivery in real-time, from kitchen to your doorstep.',
                ),
                const SizedBox(height: 16),
                _JustificationPoint(
                  icon: Icons.security,
                  text: 'Location sharing ensures your safety during rides — your trusted contacts can track your journey.',
                ),
              ],
              const Spacer(),

              // Privacy note
              Text(
                'Your location data is only used while you are actively using PY Connect'
                '${isDriver ? " or while you are online and accepting rides" : ""}. '
                'You can revoke this permission at any time in your device settings.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Decline button
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _JustificationPoint extends StatelessWidget {
  const _JustificationPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.emerald, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
