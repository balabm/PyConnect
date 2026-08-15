import 'package:flutter/material.dart';

/// Maps the backend `VendorCategory` enum to a typed Flutter enum with
/// category-specific metadata (display name, icon, feature flags).
///
/// Backend values (PondyConnect.Domain.Enums.VendorCategory):
///   LuggageCloak = 1, ScooterRental = 2, TaxiOperator = 3,
///   PubClub = 4, Restaurant = 5, Cafe = 6, Pizzeria = 7
enum VendorCategoryType {
  luggageCloak('LuggageCloak', 'Luggage Cloak', Icons.luggage),
  scooterRental('ScooterRental', 'Scooter Rental', Icons.electric_scooter),
  taxiOperator('TaxiOperator', 'Taxi Operator', Icons.local_taxi),
  pubClub('PubClub', 'Pub & Club', Icons.nightlife),
  restaurant('Restaurant', 'Restaurant', Icons.restaurant),
  cafe('Cafe', 'Cafe', Icons.coffee),
  pizzeria('Pizzeria', 'Pizzeria', Icons.local_pizza);

  const VendorCategoryType(this.backendName, this.displayName, this.icon);

  /// The exact string the backend sends in the auth session `category` field.
  final String backendName;

  /// Human-readable label for UI display.
  final String displayName;

  /// Representative icon for this category.
  final IconData icon;

  /// Parses the backend category string. Falls back to [restaurant] if unknown.
  static VendorCategoryType fromString(String? s) {
    if (s == null || s.isEmpty) return VendorCategoryType.restaurant;
    return values.firstWhere(
      (v) => v.backendName.toLowerCase() == s.toLowerCase(),
      orElse: () => VendorCategoryType.restaurant,
    );
  }

  // ── Feature flags ──

  /// Food vendors get KDS + food menu.
  bool get isFoodVendor => this == restaurant || this == cafe || this == pizzeria;

  /// Pub/Club vendors get KDS + drinks menu.
  bool get isBeverageVendor => this == pubClub;

  /// Scooter rental vendors get fleet management + active rentals.
  bool get isRentalVendor => this == scooterRental;

  /// Taxi operators get fleet management + active rides.
  bool get isTransportVendor => this == taxiOperator;

  /// Luggage cloak vendors get capacity management + bookings.
  bool get isCloakVendor => this == luggageCloak;

  /// Whether this category uses the Kitchen Display System.
  bool get hasKds => isFoodVendor || isBeverageVendor;

  /// Whether this category has a menu (food or drinks).
  bool get hasMenu => isFoodVendor || isBeverageVendor;

  /// Whether this category has fleet management.
  bool get hasFleet => isRentalVendor || isTransportVendor;

  /// Whether this category has bookings (non-food, non-beverage).
  bool get hasBookings => isCloakVendor;

  /// The label for the second tab (category-specific).
  String get secondaryTabLabel => switch (this) {
        restaurant || cafe || pizzeria => 'KDS',
        pubClub => 'KDS',
        scooterRental => 'Fleet',
        taxiOperator => 'Fleet',
        luggageCloak => 'Capacity',
      };

  /// The label for the third tab (category-specific).
  String get tertiaryTabLabel => switch (this) {
        restaurant || cafe || pizzeria => 'Menu',
        pubClub => 'Drinks',
        scooterRental => 'Rentals',
        taxiOperator => 'Rides',
        luggageCloak => 'Bookings',
      };
}
