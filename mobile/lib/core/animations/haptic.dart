import 'package:flutter/services.dart';

/// Centralized haptic feedback utilities for micro-interactions.
/// Award-winning apps use haptics to make every tap feel intentional.
abstract final class AppHaptics {
  /// Light tap — for button presses, chip selections, toggles.
  static void light() => HapticFeedback.lightImpact();

  /// Medium tap — for confirmations, successful actions.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy tap — for destructive actions, warnings.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection click — for picker wheels, segmented controls.
  static void selection() => HapticFeedback.selectionClick();

  /// Success vibration pattern — for completed bookings, payments.
  static void success() => HapticFeedback.mediumImpact();

  /// Warning vibration pattern — for errors, validation failures.
  static void warning() => HapticFeedback.heavyImpact();

  /// Error vibration pattern — for network failures, crashes.
  static void error() => HapticFeedback.vibrate();
}
