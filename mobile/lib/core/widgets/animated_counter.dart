import 'package:flutter/material.dart';

/// A rolling number animation widget that counts from an old value
/// to a new value over a specified duration, like a slot machine or
/// car odometer.
///
/// Uses [TweenAnimationBuilder] to smoothly interpolate the displayed
/// number. When the value changes, the text "rolls" from the old
/// value to the new value.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.style,
    this.thousandsSeparator = true,
  });

  /// The target value to animate to.
  final double value;

  /// Prefix string (e.g., '₹').
  final String prefix;

  /// Suffix string (e.g., ' km').
  final String suffix;

  /// Number of decimal places to display.
  final int decimals;

  /// Animation duration. Default: 600ms.
  final Duration duration;

  /// Animation curve. Default: easeOutCubic.
  final Curve curve;

  /// Text style for the displayed number.
  final TextStyle? style;

  /// Whether to use thousands separators (e.g., 1,234 vs 1234).
  final bool thousandsSeparator;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, _) {
        return Text(
          '$prefix${_formatNumber(animatedValue)}$suffix',
          style: style,
        );
      },
    );
  }

  String _formatNumber(double value) {
    if (decimals == 0) {
      final intValue = value.round();
      if (thousandsSeparator) {
        final parts = <String>[];
        var v = intValue.abs();
        while (v >= 1000) {
          parts.insert(0, (v % 1000).toString().padLeft(3, '0'));
          v ~/= 1000;
        }
        parts.insert(0, v.toString());
        var result = parts.join(',');
        if (intValue < 0) result = '-$result';
        return result;
      }
      return intValue.toString();
    } else {
      final formatted = value.toStringAsFixed(decimals);
      if (!thousandsSeparator) return formatted;
      // Split on decimal point and format integer part
      final parts = formatted.split('.');
      final intPart = int.tryParse(parts[0]) ?? 0;
      final intStr = _formatIntegerWithSeparator(intPart);
      return '$intStr.${parts[1]}';
    }
  }

  String _formatIntegerWithSeparator(int value) {
    final parts = <String>[];
    var v = value.abs();
    while (v >= 1000) {
      parts.insert(0, (v % 1000).toString().padLeft(3, '0'));
      v ~/= 1000;
    }
    parts.insert(0, v.toString());
    var result = parts.join(',');
    if (value < 0) result = '-$result';
    return result;
  }
}
