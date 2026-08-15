import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/stays_api.dart';

final staysApiProvider = Provider<StaysApi>((ref) {
  return StaysApi(ref.watch(apiClientProvider));
});

final homestayListProvider = FutureProvider<List<Homestay>>((ref) {
  return ref.watch(staysApiProvider).list();
});

final homestaySearchProvider =
    FutureProvider.family<List<Homestay>, HomestaySearchParams>((ref, params) {
  return ref.watch(staysApiProvider).search(
        checkIn: params.checkIn,
        checkOut: params.checkOut,
        guests: params.guests,
      );
});

final homestayDetailProvider =
    FutureProvider.family<Homestay, String>((ref, id) {
  return ref.watch(staysApiProvider).getById(id);
});

final addOnToggleProvider = StateProvider<bool>((ref) => false);

final selectedGuestsProvider = StateProvider<int>((ref) => 1);

class HomestaySearchParams {
  HomestaySearchParams({
    required this.checkIn,
    required this.checkOut,
    required this.guests,
  });

  final String checkIn;
  final String checkOut;
  final int guests;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomestaySearchParams &&
          checkIn == other.checkIn &&
          checkOut == other.checkOut &&
          guests == other.guests;

  @override
  int get hashCode => Object.hash(checkIn, checkOut, guests);
}
