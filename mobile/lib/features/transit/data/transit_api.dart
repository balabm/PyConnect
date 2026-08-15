import '../../../core/network/api_client.dart';

class TransitHub {
  TransitHub({
    required this.id,
    required this.name,
    required this.kind,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory TransitHub.fromJson(Map<String, dynamic> json) => TransitHub(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'] as String?,
      );

  final String id;
  final String name;
  final String kind;
  final double latitude;
  final double longitude;
  final String? address;
}

class TransitTrip {
  TransitTrip({
    required this.id,
    required this.hubName,
    required this.arrivalFrom,
    required this.arrivalMode,
    required this.arrivalAt,
    required this.partySize,
    this.dropOffLocation,
    required this.status,
    required this.price,
    required this.paymentStatus,
    this.completedAt,
  });

  factory TransitTrip.fromJson(Map<String, dynamic> json) => TransitTrip(
        id: json['id'] as String,
        hubName: json['hubName'] as String,
        arrivalFrom: json['arrivalFrom'] as String,
        arrivalMode: json['arrivalMode'] as String,
        arrivalAt: DateTime.parse(json['arrivalAt'] as String),
        partySize: json['partySize'] as int,
        dropOffLocation: json['dropOffLocation'] as String?,
        status: json['status'] as String,
        price: (json['price'] as num).toDouble(),
        paymentStatus: json['paymentStatus'] as String,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  final String id;
  final String hubName;
  final String arrivalFrom;
  final String arrivalMode;
  final DateTime arrivalAt;
  final int partySize;
  final String? dropOffLocation;
  final String status;
  final double price;
  final String paymentStatus;
  final DateTime? completedAt;
}

class TransitApi {
  TransitApi(this._api);

  final ApiClient _api;

  Future<List<TransitHub>> listHubs({String? kind, bool onlyActive = true}) async {
    final body = await _api.get(
      '/api/transit/hubs',
      queryParameters: {
        'kind': ?kind,
        'onlyActive': onlyActive,
      },
    );
    return (body as List)
        .map((e) => TransitHub.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({String id, String status, double amount})> createTrip({
    required String hubId,
    required String arrivalFrom,
    required String arrivalMode,
    required DateTime arrivalAt,
    required int partySize,
    required double price,
    String? dropOffLocation,
    String? notes,
  }) async {
    final body = await _api.post(
      '/api/transit/trips',
      data: {
        'hubId': hubId,
        'arrivalFrom': arrivalFrom,
        'arrivalMode': arrivalMode,
        'arrivalAt': arrivalAt.toIso8601String(),
        'partySize': partySize,
        'price': price,
        'dropOffLocation': ?dropOffLocation,
        'notes': ?notes,
      },
    );
    final map = body as Map<String, dynamic>;
    return (
      id: map['tripId'] as String,
      status: map['status'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }

  Future<List<TransitTrip>> listTrips({String? status}) async {
    final body = await _api.get(
      '/api/transit/trips',
      queryParameters: {
        'status': ?status,
      },
    );
    return (body as List)
        .map((e) => TransitTrip.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}