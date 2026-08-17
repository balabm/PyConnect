import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// A saved user address returned from and persisted to the backend.
class Address {
  Address({
    this.id,
    this.doorFlat,
    this.landmark,
    required this.tag,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });

  final String? id;
  final String? doorFlat;
  final String? landmark;
  final String tag;
  final double latitude;
  final double longitude;
  final String formattedAddress;

  Map<String, dynamic> toJson() => {
        'doorFlat': doorFlat,
        'landmark': landmark,
        'tag': tag,
        'latitude': latitude,
        'longitude': longitude,
        'formattedAddress': formattedAddress,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id']?.toString(),
        doorFlat: json['doorFlat'] as String?,
        landmark: json['landmark'] as String?,
        tag: json['tag'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        formattedAddress: json['formattedAddress'] as String,
      );

  LatLng toLatLng() => LatLng(latitude, longitude);
}

/// Riverpod state-holding the currently selected/saved address and exposing
/// the `POST /api/user/addresses` call. The home screen can watch this
/// provider and refetch when the selected address changes.
class CurrentLocationNotifier extends StateNotifier<Address?> {
  CurrentLocationNotifier(this._client) : super(null);

  final ApiClient _client;

  void select(Address? address) => state = address;

  Future<Address> saveAddress(Address draft) async {
    final res = await _client.post(
      '/api/user/addresses',
      data: draft.toJson(),
    );
    final saved = Address.fromJson(res as Map<String, dynamic>);
    state = saved;
    return saved;
  }
}

final currentLocationProvider =
    StateNotifierProvider<CurrentLocationNotifier, Address?>((ref) {
  return CurrentLocationNotifier(ref.watch(apiClientProvider));
});
