import '../../../core/network/api_client.dart';

class ScooterRental {
  ScooterRental({
    required this.id,
    required this.vendorName,
    required this.vehicleName,
    this.vehiclePlate,
    required this.rentalStart,
    required this.rentalEnd,
    required this.ratePerHour,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
  });

  factory ScooterRental.fromJson(Map<String, dynamic> json) => ScooterRental(
        id: json['id'] as String,
        vendorName: json['vendorName'] as String,
        vehicleName: json['vehicleName'] as String,
        vehiclePlate: json['vehiclePlate'] as String?,
        rentalStart: DateTime.parse(json['rentalStart'] as String),
        rentalEnd: DateTime.parse(json['rentalEnd'] as String),
        ratePerHour: (json['ratePerHour'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        status: json['status'] as String,
        paymentStatus: json['paymentStatus'] as String,
      );

  final String id;
  final String vendorName;
  final String vehicleName;
  final String? vehiclePlate;
  final DateTime rentalStart;
  final DateTime rentalEnd;
  final double ratePerHour;
  final double totalAmount;
  final String status;
  final String paymentStatus;
}

class RentalApi {
  RentalApi(this._api);

  final ApiClient _api;

  Future<({String id, String status, double totalAmount})> createRental({
    required String vendorId,
    required String vehicleName,
    required DateTime rentalStart,
    required DateTime rentalEnd,
    required double ratePerHour,
    String? vehiclePlate,
    String? notes,
  }) async {
    final body = await _api.post(
      '/api/rental/scooters',
      data: {
        'vendorId': vendorId,
        'vehicleName': vehicleName,
        'rentalStart': rentalStart.toIso8601String(),
        'rentalEnd': rentalEnd.toIso8601String(),
        'ratePerHour': ratePerHour,
        'vehiclePlate': ?vehiclePlate,
        'notes': ?notes,
      },
    );
    final map = body as Map<String, dynamic>;
    return (
      id: map['rentalId'] as String,
      status: map['status'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
    );
  }

  Future<List<ScooterRental>> listRentals({String? status}) async {
    final body = await _api.get(
      '/api/rental/scooters',
      queryParameters: {
        'status': ?status,
      },
    );
    return (body as List)
        .map((e) => ScooterRental.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}