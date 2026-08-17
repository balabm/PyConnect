import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_flavor.dart';
import '../../../core/providers/force_update_provider.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/application/vendor_auth_controller.dart';

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
    // Show branding for 1.5 seconds before any checks.
    await Future.delayed(const Duration(milliseconds: 1500));

    await ref
        .read(forceUpdateProvider.notifier)
        .checkAppVersion(widget.flavor.name);

    if (!mounted) return;

    if (ref.read(forceUpdateProvider).forceUpdate) {
      context.go('/force-update');
      return;
    }

    final bool authenticated;
    if (widget.flavor == AppFlavor.partner) {
      final session = await ref.read(vendorAuthControllerProvider.future);
      authenticated = session?.isAuthenticated ?? false;
    } else {
      final session = await ref.read(authControllerProvider.future);
      authenticated = session?.isAuthenticated ?? false;
    }

    if (!mounted) return;

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
