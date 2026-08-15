import '../../../core/network/api_client.dart';

class LuggageDropOff {
  LuggageDropOff({
    required this.id,
    required this.vendorName,
    required this.scheduledFor,
    required this.droppedAt,
    required this.bagCount,
    required this.ratePerHour,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.pickedUpAt,
  });

  factory LuggageDropOff.fromJson(Map<String, dynamic> json) => LuggageDropOff(
        id: json['id'] as String,
        vendorName: json['vendorName'] as String,
        scheduledFor: DateTime.parse(json['scheduledFor'] as String),
        droppedAt: DateTime.parse(json['droppedAt'] as String),
        bagCount: json['bagCount'] as int,
        ratePerHour: (json['ratePerHour'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        status: json['status'] as String,
        paymentStatus: json['paymentStatus'] as String,
        pickedUpAt: json['pickedUpAt'] != null
            ? DateTime.parse(json['pickedUpAt'] as String)
            : null,
      );

  final String id;
  final String vendorName;
  final DateTime scheduledFor;
  final DateTime droppedAt;
  final int bagCount;
  final double ratePerHour;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final DateTime? pickedUpAt;
}

class LuggageApi {
  LuggageApi(this._api);

  final ApiClient _api;

  Future<({String id, String status, double totalAmount})> createDropOff({
    required String vendorId,
    required DateTime scheduledFor,
    required DateTime droppedAt,
    required int bagCount,
    required double ratePerHour,
    String? notes,
  }) async {
    final body = await _api.post(
      '/api/luggage/drop-offs',
      data: {
        'vendorId': vendorId,
        'scheduledFor': scheduledFor.toIso8601String(),
        'droppedAt': droppedAt.toIso8601String(),
        'bagCount': bagCount,
        'ratePerHour': ratePerHour,
        'notes': ?notes,
      },
    );
    final map = body as Map<String, dynamic>;
    return (
      id: map['dropOffId'] as String,
      status: map['status'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
    );
  }

  Future<List<LuggageDropOff>> listDropOffs({String? status}) async {
    final body = await _api.get(
      '/api/luggage/drop-offs',
      queryParameters: {
        'status': ?status,
      },
    );
    return (body as List)
        .map((e) => LuggageDropOff.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LuggageDropOff> getDropOff(String id) async {
    final body = await _api.get('/api/luggage/drop-offs/$id');
    return LuggageDropOff.fromJson(body as Map<String, dynamic>);
  }

  Future<void> cancelDropOff(String id) async {
    await _api.post('/api/luggage/drop-offs/$id/cancel');
  }
}