import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_flavor.dart';
import 'core/widgets/error_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is not bundled in release builds — safe to skip.
  }
  setupAppErrorWidget();
  runApp(ProviderScope(
    overrides: [
      appFlavorProvider.overrideWithValue(AppFlavor.consumer),
    ],
    child: const PondyConnectApp(flavor: AppFlavor.consumer),
  ));
}