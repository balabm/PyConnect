import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../vendor/data/vendor_api.dart';
import '../data/luggage_api.dart';
import '../data/rental_api.dart';
import '../data/transit_api.dart';

final transitHubsProvider = FutureProvider<List<TransitHub>>((ref) {
  ref.watch(authTokenProvider);
  return ref.watch(transitApiProvider).listHubs();
});

final userTripsProvider = FutureProvider<List<TransitTrip>>((ref) {
  ref.watch(authTokenProvider);
  return ref.watch(transitApiProvider).listTrips();
});

final userLuggageProvider = FutureProvider<List<LuggageDropOff>>((ref) {
  ref.watch(authTokenProvider);
  return ref.watch(luggageApiProvider).listDropOffs();
});

final userRentalsProvider = FutureProvider<List<ScooterRental>>((ref) {
  ref.watch(authTokenProvider);
  return ref.watch(rentalApiProvider).listRentals();
});

final luggageCloakVendorsProvider = FutureProvider<List<Vendor>>((ref) {
  ref.watch(authTokenProvider);
  return ref.watch(vendorApiProvider).list(category: 'LuggageCloak');
});

final scooterRentalVendorsProvider = FutureProvider<List<Vendor>>((ref) {
  ref.watch(authTokenProvider);
  return ref.watch(vendorApiProvider).list(category: 'ScooterRental');
});