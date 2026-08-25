import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Static toll database for intercity routes originating from Pondicherry.
///
/// Covers the most common intercity cab routes:
/// - Pondicherry ↔ Chennai (ECR + NH32)
/// - Pondicherry ↔ Mahabalipuram (ECR)
/// - Pondicherry ↔ Auroville (no toll)
/// - Pondicherry ↔ Bangalore (NH77 + NH48)
/// - Pondicherry ↔ Coimbatore (NH79)
/// - Pondicherry ↔ Trichy (NH81)
/// - Pondicherry ↔ Velankanni (NH32)
///
/// Toll amounts are approximate one-way car rates (2024-2025) and include
/// FastTag-compatible toll plazas. State border taxes are separate.
class TollRoute {
  const TollRoute({
    required this.name,
    required this.fromCity,
    required this.toCity,
    required this.tollAmount,
    this.stateTax = 0,
    this.notes,
  });

  final String name;
  final String fromCity;
  final String toCity;
  final double tollAmount;
  final double stateTax;
  final String? notes;

  double get total => tollAmount + stateTax;

  bool matches(String from, String to) {
    final f = from.toLowerCase();
    final t = to.toLowerCase();
    return (fromCity.toLowerCase().contains(f) && toCity.toLowerCase().contains(t)) ||
           (fromCity.toLowerCase().contains(t) && toCity.toLowerCase().contains(f)) ||
           (f.contains(fromCity.toLowerCase()) && t.contains(toCity.toLowerCase())) ||
           (f.contains(toCity.toLowerCase()) && t.contains(fromCity.toLowerCase()));
  }
}

class TollCalculator {
  TollCalculator._();

  /// Static toll database for routes from/to Pondicherry.
  /// Toll amounts are one-way car rates in INR.
  static const _routes = <TollRoute>[
    // ── Chennai (2 routes: ECR and NH32) ──
    TollRoute(
      name: 'Pondicherry → Chennai (ECR)',
      fromCity: 'Pondicherry',
      toCity: 'Chennai',
      tollAmount: 0, // ECR has no toll plazas
      notes: 'East Coast Road is toll-free but slower (2.5-3 hrs)',
    ),
    TollRoute(
      name: 'Pondicherry → Chennai (NH32)',
      fromCity: 'Pondicherry',
      toCity: 'Chennai',
      tollAmount: 85,
      stateTax: 0,
      notes: 'NH32 via Tindivanam — faster route (2-2.5 hrs)',
    ),
    // ── Mahabalipuram ──
    TollRoute(
      name: 'Pondicherry → Mahabalipuram',
      fromCity: 'Pondicherry',
      toCity: 'Mahabalipuram',
      tollAmount: 0,
      notes: 'ECR route — no toll plazas',
    ),
    // ── Bangalore ──
    TollRoute(
      name: 'Pondicherry → Bangalore',
      fromCity: 'Pondicherry',
      toCity: 'Bangalore',
      tollAmount: 340,
      stateTax: 0,
      notes: 'NH77 + NH48 via Krishnagiri — 4-5 hrs',
    ),
    // ── Coimbatore ──
    TollRoute(
      name: 'Pondicherry → Coimbatore',
      fromCity: 'Pondicherry',
      toCity: 'Coimbatore',
      tollAmount: 280,
      stateTax: 0,
      notes: 'NH79 via Salem — 6-7 hrs',
    ),
    // ── Trichy ──
    TollRoute(
      name: 'Pondicherry → Trichy',
      fromCity: 'Pondicherry',
      toCity: 'Trichy',
      tollAmount: 120,
      stateTax: 0,
      notes: 'NH81 via Villupuram — 3-4 hrs',
    ),
    // ── Velankanni ──
    TollRoute(
      name: 'Pondicherry → Velankanni',
      fromCity: 'Pondicherry',
      toCity: 'Velankanni',
      tollAmount: 65,
      stateTax: 0,
      notes: 'NH32 via Nagapattinam — 3-4 hrs',
    ),
    // ── Auroville (local, no toll) ──
    TollRoute(
      name: 'Pondicherry → Auroville',
      fromCity: 'Pondicherry',
      toCity: 'Auroville',
      tollAmount: 0,
      notes: 'Local route — no toll',
    ),
    // ── Cuddalore (local, no toll) ──
    TollRoute(
      name: 'Pondicherry → Cuddalore',
      fromCity: 'Pondicherry',
      toCity: 'Cuddalore',
      tollAmount: 0,
      notes: 'Local route — no toll',
    ),
  ];

  /// Returns the toll breakdown for a route if it matches a known intercity
  /// route. Returns null for local/intra-city rides.
  static TollRoute? lookup(String pickupAddress, String dropoffAddress) {
    for (final route in _routes) {
      if (route.matches(pickupAddress, dropoffAddress)) {
        return route;
      }
    }
    return null;
  }

  /// Estimates whether a ride is intercity based on straight-line distance.
  /// Rides over 50km are considered intercity.
  static bool isIntercity(double distanceKm) => distanceKm > 50;

  /// Returns a fare breakdown for an intercity ride including tolls.
  /// Returns null if the route is not intercity or no toll data is found.
  static TollBreakdown? calculate({
    required String pickupAddress,
    required String dropoffAddress,
    required double distanceKm,
    required double baseFare,
    required double perKmRate,
  }) {
    if (!isIntercity(distanceKm)) return null;

    final route = lookup(pickupAddress, dropoffAddress);
    if (route == null) {
      // Intercity but unknown route — return breakdown with zero toll
      // so the UI can still show the structure.
      return TollBreakdown(
        routeName: 'Intercity (custom route)',
        baseFare: baseFare,
        distanceFare: (distanceKm * perKmRate).ceil().toDouble(),
        tollAmount: 0,
        stateTax: 0,
        distanceKm: distanceKm,
        notes: 'Toll amount will be added by the captain with receipt',
      );
    }

    return TollBreakdown(
      routeName: route.name,
      baseFare: baseFare,
      distanceFare: (distanceKm * perKmRate).ceil().toDouble(),
      tollAmount: route.tollAmount,
      stateTax: route.stateTax,
      distanceKm: distanceKm,
      notes: route.notes,
    );
  }
}

class TollBreakdown {
  const TollBreakdown({
    required this.routeName,
    required this.baseFare,
    required this.distanceFare,
    required this.tollAmount,
    required this.stateTax,
    required this.distanceKm,
    this.notes,
  });

  final String routeName;
  final double baseFare;
  final double distanceFare;
  final double tollAmount;
  final double stateTax;
  final double distanceKm;
  final String? notes;

  double get total => baseFare + distanceFare + tollAmount + stateTax;
  double get totalBeforeToll => baseFare + distanceFare;

  /// Whether this route has any toll or state tax to display.
  bool get hasToll => tollAmount > 0 || stateTax > 0;
}
