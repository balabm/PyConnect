import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime configuration. Override the API base with:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
///
/// Defaults to the production backend at https://pyconnect.run.place.
/// For local development, run with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
class AppConfig {
  const AppConfig._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Demo mode flag. Set with --dart-define=DEMO_MODE=true
  /// Suppresses non-essential UI elements (network banner) for pitch demos.
  static const bool isDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    // Default to production backend for both debug and release.
    // Use --dart-define=API_BASE_URL=http://10.0.2.2:5000 for local dev.
    return 'https://pyconnect.run.place';
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig._());