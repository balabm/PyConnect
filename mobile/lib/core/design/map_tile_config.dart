import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Centralized map tile configuration.
/// Uses CartoDB Dark Matter for dark mode (Uber-style muted map)
/// and CartoDB Positron for light mode (clean, minimal, no noise).
///
/// Both tiles strip noisy icons (hospitals, parks, etc.) and use
/// a muted palette so route lines and markers pop.
class MapTileConfig {
  MapTileConfig._();

  /// CartoDB Positron — clean, light, minimal labels.
  /// Perfect for Swiggy-style light mode maps.
  static const _lightUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const _lightSubdomains = ['a', 'b', 'c', 'd'];

  /// CartoDB Dark Matter — pitch black, muted greys, no noise.
  /// Perfect for Uber-style dark mode maps.
  static const _darkUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const _darkSubdomains = ['a', 'b', 'c', 'd'];

  /// Returns the appropriate TileLayer based on the current theme.
  static TileLayer forTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      urlTemplate: isDark ? _darkUrlTemplate : _lightUrlTemplate,
      subdomains: isDark ? _darkSubdomains : _lightSubdomains,
      userAgentPackageName: 'com.pondyconnect.app',
    );
  }

  /// Returns the dark tile layer directly (for always-dark screens).
  static TileLayer dark() {
    return TileLayer(
      urlTemplate: _darkUrlTemplate,
      subdomains: _darkSubdomains,
      userAgentPackageName: 'com.pondyconnect.app',
    );
  }

  /// Returns the light tile layer directly (for always-light screens).
  static TileLayer light() {
    return TileLayer(
      urlTemplate: _lightUrlTemplate,
      subdomains: _lightSubdomains,
      userAgentPackageName: 'com.pondyconnect.app',
    );
  }
}
