import '../../../core/network/api_client.dart';

/// Consumer-facing equipment rental API.
/// Calls the consumer endpoints of /api/equipment:
///   GET  /api/equipment/browse?category=
///   POST /api/equipment/rentals
///   POST /api/equipment/rentals/{id}/confirm
class ConsumerEquipmentApi {
  ConsumerEquipmentApi(this._api);

  final ApiClient _api;

  /// Browse all available equipment across vendors.
  /// Optional [category] filter (e.g. 'Sound', 'Lighting', 'DJ').
  Future<List<ConsumerEquipmentItemModel>> browse({String? category}) async {
    final body = await _api.get('/api/equipment/browse',
        queryParameters: category != null && category.isNotEmpty
            ? {'category': category}
            : null);
    final list = body as List? ?? [];
    return list
        .map((e) => ConsumerEquipmentItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a rental request for equipment.
  /// Returns the rental ID, total amount, security deposit, and Razorpay order ID.
  Future<CreateRentalResultModel> createRental({
    required String equipmentItemId,
    required int unitsBooked,
    required DateTime rentalStart,
    required DateTime rentalEnd,
    String? deliveryAddress,
    String? notes,
  }) async {
    final body = await _api.post('/api/equipment/rentals', data: {
      'equipmentItemId': equipmentItemId,
      'unitsBooked': unitsBooked,
      'rentalStart': rentalStart.toUtc().toIso8601String(),
      'rentalEnd': rentalEnd.toUtc().toIso8601String(),
      'deliveryAddress': deliveryAddress,
      'notes': notes,
    });
    return CreateRentalResultModel.fromJson(body as Map<String, dynamic>);
  }

  /// Confirm a rental after successful Razorpay payment.
  Future<void> confirmRental({
    required String rentalId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String signature,
  }) async {
    await _api.post('/api/equipment/rentals/$rentalId/confirm', data: {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'signature': signature,
    });
  }
}

class ConsumerEquipmentItemModel {
  ConsumerEquipmentItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.dailyRentalPrice,
    required this.securityDepositAmount,
    required this.totalUnits,
    required this.availableUnits,
    required this.category,
    required this.imageUrl,
    required this.isAvailable,
    required this.vendorName,
  });

  factory ConsumerEquipmentItemModel.fromJson(Map<String, dynamic> json) =>
      ConsumerEquipmentItemModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        dailyRentalPrice: (json['dailyRentalPrice'] as num?)?.toDouble() ?? 0,
        securityDepositAmount:
            (json['securityDepositAmount'] as num?)?.toDouble() ?? 0,
        totalUnits: json['totalUnits'] as int? ?? 0,
        availableUnits: json['availableUnits'] as int? ?? 0,
        category: json['category'] as String? ?? 'Misc',
        imageUrl: json['imageUrl'] as String?,
        isAvailable: json['isAvailable'] as bool? ?? false,
        vendorName: json['vendorName'] as String? ?? 'Local Vendor',
      );

  final String id;
  final String name;
  final String? description;
  final double dailyRentalPrice;
  final double securityDepositAmount;
  final int totalUnits;
  final int availableUnits;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final String vendorName;
}

class CreateRentalResultModel {
  CreateRentalResultModel({
    required this.rentalId,
    required this.totalAmount,
    required this.securityDeposit,
    required this.razorpayOrderId,
  });

  factory CreateRentalResultModel.fromJson(Map<String, dynamic> json) =>
      CreateRentalResultModel(
        rentalId: json['rentalId'] as String,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        securityDeposit:
            (json['securityDeposit'] as num?)?.toDouble() ?? 0,
        razorpayOrderId: json['razorpayOrderId'] as String?,
      );

  final String rentalId;
  final double totalAmount;
  final double securityDeposit;
  final String? razorpayOrderId;
}
