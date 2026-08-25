import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

final genieApiProvider = Provider<GenieApi>((ref) {
  return GenieApi(ref.read(apiClientProvider));
});

class GenieErrandModel {
  GenieErrandModel({
    required this.id,
    required this.description,
    required this.status,
    required this.estimatedCost,
    required this.authHoldAmount,
    required this.createdAt,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.captainId,
    this.actualCost,
  });

  factory GenieErrandModel.fromJson(Map<String, dynamic> json) =>
      GenieErrandModel(
        id: json['id'] as String,
        description: json['description'] as String,
        status: json['status'] as String? ?? 'Posted',
        estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0,
        authHoldAmount: (json['authHoldAmount'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        pickupAddress: json['pickupAddress'] as String?,
        pickupLat: (json['pickupLat'] as num?)?.toDouble(),
        pickupLng: (json['pickupLng'] as num?)?.toDouble(),
        dropoffAddress: json['dropoffAddress'] as String?,
        dropoffLat: (json['dropoffLat'] as num?)?.toDouble(),
        dropoffLng: (json['dropoffLng'] as num?)?.toDouble(),
        captainId: json['captainId'] as String?,
        actualCost: (json['actualCost'] as num?)?.toDouble(),
      );

  final String id;
  final String description;
  final String status;
  final double estimatedCost;
  final double authHoldAmount;
  final DateTime createdAt;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? captainId;
  final double? actualCost;

  bool get isActive => status == 'Posted' || status == 'Accepted' || status == 'InProgress';
  bool get isCompleted => status == 'Completed';
  bool get isCancelled => status == 'Cancelled';
}

class GenieApi {
  GenieApi(this._api);

  final ApiClient _api;

  Future<GenieErrandModel> createErrand({
    required String description,
    required double estimatedCost,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? dropoffAddress,
    double? dropoffLat,
    double? dropoffLng,
  }) async {
    final body = await _api.post('/api/genie', data: {
      'description': description,
      'estimatedCost': estimatedCost,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffAddress': dropoffAddress,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
    });
    return GenieErrandModel.fromJson(body as Map<String, dynamic>);
  }

  Future<List<GenieErrandModel>> myErrands() async {
    final body = await _api.get('/api/genie/my-errands');
    final list = body as List? ?? [];
    return list
        .map((e) => GenieErrandModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GenieErrandModel> getErrand(String id) async {
    final body = await _api.get('/api/genie/$id');
    return GenieErrandModel.fromJson(body as Map<String, dynamic>);
  }

  Future<void> cancelErrand(String id) async {
    await _api.post('/api/genie/$id/cancel');
  }
}
