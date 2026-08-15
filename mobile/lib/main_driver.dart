import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_flavor.dart';
import 'core/widgets/error_boundary.dart';

/// Entry point for the PondyConnect Captain (Driver) app.
///
/// Build with:
///   flutter build apk --flavor driver --target lib/main_driver.dart \
///     --dart-define=APP_FLAVOR=driver
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is not bundled in release builds — safe to skip.
  }
  setupAppErrorWidget();
  runApp(const ProviderScope(
    child: PondyConnectApp(flavor: AppFlavor.driver),
  ));
}
