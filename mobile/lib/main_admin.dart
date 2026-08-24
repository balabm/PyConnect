import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_flavor.dart';
import 'core/widgets/error_boundary.dart';

/// Entry point for the Admin web app.
///
/// Built with:
///   flutter build web --target lib/main_admin.dart \
///     --dart-define=APP_FLAVOR=admin
///
/// This launches the PondyConnectApp with admin flavor, routing to
/// the admin dispatch dashboard after authentication.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupAppErrorWidget();
  runApp(ProviderScope(
    overrides: [
      appFlavorProvider.overrideWithValue(AppFlavor.admin),
    ],
    child: const PondyConnectApp(flavor: AppFlavor.admin),
  ));
}
