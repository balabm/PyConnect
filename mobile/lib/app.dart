import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_flavor.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/error_boundary.dart';
import 'core/widgets/offline_banner.dart';
import 'features/notifications/application/notification_providers.dart';
import 'router/admin_router.dart';
import 'router/app_router.dart';
import 'router/driver_router.dart';
import 'router/partner_router.dart';

class PondyConnectApp extends ConsumerStatefulWidget {
  const PondyConnectApp({super.key, this.flavor = AppFlavor.consumer});

  final AppFlavor flavor;

  @override
  ConsumerState<PondyConnectApp> createState() => _PondyConnectAppState();
}

class _PondyConnectAppState extends ConsumerState<PondyConnectApp> {
  @override
  void initState() {
    super.initState();
    if (widget.flavor.isMobile) {
      ref.read(fcmInitializationProvider);
    }
  }

  GoRouter _resolveRouter() {
    switch (widget.flavor) {
      case AppFlavor.consumer:
        return ref.watch(appRouterProvider);
      case AppFlavor.driver:
        return ref.watch(driverRouterProvider);
      case AppFlavor.partner:
        return ref.watch(partnerRouterProvider);
      case AppFlavor.admin:
        return ref.watch(adminRouterProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = _resolveRouter();

    if (widget.flavor.isMobile) {
      ref.listen(fcmInitializationProvider, (_, next) {
        next.whenData((service) {
          if (service != null && mounted) {
            service.onForegroundMessage.listen((message) {
              final notification = message.notification;
              if (notification != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${notification.title}: ${notification.body}'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            });
          }
        });
      });
    }

    final themeMode = ref.watch(themeControllerProvider.notifier).toMaterialMode();

    // Driver and partner apps use their own branded themes (no dark mode toggle).
    // Consumer app supports full light/dark mode switching, but Light Mode is default.
    // Admin app uses a unified enterprise dark SaaS theme.
    final ThemeData lightTheme;
    final ThemeData? darkTheme;
    switch (widget.flavor) {
      case AppFlavor.driver:
        lightTheme = AppTheme.driverTheme;
        darkTheme = null;
      case AppFlavor.partner:
        lightTheme = AppTheme.partnerTheme;
        darkTheme = null;
      case AppFlavor.admin:
        lightTheme = AppTheme.adminTheme;
        darkTheme = null;
      default:
        lightTheme = AppTheme.light;
        darkTheme = AppTheme.dark;
    }

    return MaterialApp.router(
      title: widget.flavor.title,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: darkTheme != null ? themeMode : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        return OfflineBanner(
          child: ErrorBoundary(child: child!),
        );
      },
    );
  }
}