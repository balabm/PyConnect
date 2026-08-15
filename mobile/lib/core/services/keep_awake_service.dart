import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service to keep the device screen awake during active sessions.
/// Used by the Driver app while online and Partner app during service hours.
class KeepAwakeService {
  KeepAwakeService._();

  static bool _enabled = false;

  /// Enable wakelock to prevent screen from sleeping.
  static Future<void> enable() async {
    if (kIsWeb) return;
    if (_enabled) return;
    _enabled = true;
    try {
      await WakelockPlus.enable();
    } catch (_) {
      _enabled = false;
    }
  }

  /// Disable wakelock to allow screen to sleep normally.
  static Future<void> disable() async {
    if (kIsWeb) return;
    if (!_enabled) return;
    _enabled = false;
    try {
      await WakelockPlus.disable();
    } catch (_) {
      _enabled = true;
    }
  }

  /// Whether the wakelock is currently active.
  static bool get isEnabled => _enabled;
}
