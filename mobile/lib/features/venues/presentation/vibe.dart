import 'package:flutter/material.dart';

/// Live crowd-density classification for the "vibe check".
enum Vibe {
  quiet(label: 'Chill', icon: Icons.nights_stay, color: Color(0xFF2A9D8F)),
  alive(label: 'Lively', icon: Icons.local_bar, color: Color(0xFFE9C46A)),
  packed(label: 'Packed', icon: Icons.whatshot, color: Color(0xFFE76F51));

  const Vibe({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static Vibe fromOccupancy(int occupancy) {
    if (occupancy >= 75) return Vibe.packed;
    if (occupancy >= 40) return Vibe.alive;
    return Vibe.quiet;
  }
}