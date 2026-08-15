import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime configuration. Override the API base with:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
///
/// In release mode, defaults to the production backend at
/// https://pyconnect.run.place. In debug mode, falls back to the
/// local dev server (10.0.2.2:5000 on Android emulator, localhost:5000
/// elsewhere) so local development works without --dart-define.
class AppConfig {
  const AppConfig._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    // Release builds default to production backend.
    if (kReleaseMode) return 'https://pyconnect.run.place';
    // Debug builds default to local dev server.
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig._());