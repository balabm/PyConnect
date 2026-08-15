import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifies which compiled app binary is running.
///
/// Passed via `--dart-define=APP_FLAVOR=<name>` at build time:
///   - `consumer` → PondyConnect (tourist app)
///   - `driver`   → PondyConnect Captain
///   - `partner`  → PondyConnect Partner (service owner POS — covers all vendor categories)
///   - `admin`    → PondyConnect Admin (web only)
enum AppFlavor {
  consumer,
  driver,
  partner,
  admin;

  /// Whether this flavor targets a mobile (non-web) platform.
  bool get isMobile => this == consumer || this == driver || this == partner;

  /// Human-readable app title shown in MaterialApp.
  String get title => switch (this) {
        consumer => 'PondyConnect',
        driver => 'PondyConnect Captain',
        partner => 'PondyConnect Partner',
        admin => 'PondyConnect Admin',
      };
}

/// Resolved at startup from the `APP_FLAVOR` dart-define.
final AppFlavor resolvedAppFlavor = () {
  const name = String.fromEnvironment('APP_FLAVOR', defaultValue: 'consumer');
  return AppFlavor.values.firstWhere(
    (e) => e.name == name,
    orElse: () => AppFlavor.consumer,
  );
}();

/// Riverpod provider exposing the current [AppFlavor].
final appFlavorProvider = Provider<AppFlavor>((ref) => resolvedAppFlavor);
