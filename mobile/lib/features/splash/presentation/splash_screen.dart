import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_flavor.dart';
import '../../../core/providers/force_update_provider.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/application/vendor_auth_controller.dart';
import '../../../features/driver/application/driver_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    debugPrint('SPLASH: bootstrap started');
    // Show branding for 1.5 seconds before any checks.
    await Future.delayed(const Duration(milliseconds: 1500));
    debugPrint('SPLASH: after 1.5s delay');

    debugPrint('SPLASH: checking force update...');
    await ref
        .read(forceUpdateProvider.notifier)
        .checkAppVersion(widget.flavor.name);
    debugPrint('SPLASH: force update check done');

    if (!mounted) return;

    if (ref.read(forceUpdateProvider).forceUpdate) {
      debugPrint('SPLASH: force update required, redirecting');
      context.go('/force-update');
      return;
    }
    debugPrint('SPLASH: no force update needed');

    final bool authenticated;
    if (widget.flavor == AppFlavor.partner) {
      final session = await ref.read(vendorAuthControllerProvider.future);
      authenticated = session?.isAuthenticated ?? false;
    } else {
      debugPrint('SPLASH: reading auth controller...');
      final session = await ref.read(authControllerProvider.future);
      authenticated = session?.isAuthenticated ?? false;
    }
    debugPrint('SPLASH: auth check done, authenticated=$authenticated');

    if (!mounted) return;

    // Eagerly fetch the driver profile so the router has the latest
    // compliance status before navigating. Without this, the router
    // sees a null profile (FutureProvider hasn't started yet) and
    // redirects an approved driver to /register.
    if (authenticated && widget.flavor == AppFlavor.driver) {
      try {
        await ref.read(driverProfileProvider.future);
      } catch (_) {
        // If the profile fetch fails, the router will handle routing
        // based on the error state. Don't block the navigation.
      }
      if (!mounted) return;
    }

    context.go(authenticated ? '/' : '/auth');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 96),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
