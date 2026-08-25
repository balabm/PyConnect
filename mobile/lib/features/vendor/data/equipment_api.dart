import '../../../core/network/api_client.dart';

class EquipmentItemModel {
  EquipmentItemModel({
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
  });

  factory EquipmentItemModel.fromJson(Map<String, dynamic> json) =>
      EquipmentItemModel(
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
}

class EquipmentRentalModel {
  EquipmentRentalModel({
    required this.id,
    required this.itemName,
    required this.unitsBooked,
    required this.rentalStart,
    required this.rentalEnd,
    required this.totalAmount,
    required this.securityDeposit,
    required this.status,
    required this.paymentStatus,
    required this.deliveryAddress,
    required this.notes,
  });

  factory EquipmentRentalModel.fromJson(Map<String, dynamic> json) =>
      EquipmentRentalModel(
        id: json['id'] as String,
        itemName: json['itemName'] as String? ?? 'Unknown',
        unitsBooked: json['unitsBooked'] as int? ?? 0,
        rentalStart: DateTime.tryParse(json['rentalStart'] as String? ?? '') ??
            DateTime.now(),
        rentalEnd: DateTime.tryParse(json['rentalEnd'] as String? ?? '') ??
            DateTime.now(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        securityDeposit:
            (json['securityDeposit'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'Pending',
        paymentStatus: json['paymentStatus'] as String? ?? 'Pending',
        deliveryAddress: json['deliveryAddress'] as String?,
        notes: json['notes'] as String?,
      );

  final String id;
  final String itemName;
  final int unitsBooked;
  final DateTime rentalStart;
  final DateTime rentalEnd;
  final double totalAmount;
  final double securityDeposit;
  final String status;
  final String paymentStatus;
  final String? deliveryAddress;
  final String? notes;
}

class CreateEquipmentRentalResult {
  CreateEquipmentRentalResult({
    required this.rentalId,
    required this.totalAmount,
    required this.securityDeposit,
    required this.razorpayOrderId,
  });

  factory CreateEquipmentRentalResult.fromJson(Map<String, dynamic> json) =>
      CreateEquipmentRentalResult(
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

class CompleteReturnResult {
  CompleteReturnResult({
    required this.depositPenalty,
    required this.depositRefunded,
  });

  factory CompleteReturnResult.fromJson(Map<String, dynamic> json) =>
      CompleteReturnResult(
        depositPenalty: (json['depositPenalty'] as num?)?.toDouble() ?? 0,
        depositRefunded: (json['depositRefunded'] as num?)?.toDouble() ?? 0,
      );

  final double depositPenalty;
  final double depositRefunded;
}

class EquipmentApi {
  EquipmentApi(this._api);

  final ApiClient _api;

  Future<List<EquipmentItemModel>> getMyItems() async {
    final body = await _api.get('/api/equipment/items');
    final list = body as List? ?? [];
    return list
        .map((e) => EquipmentItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EquipmentItemModel> createItem({
    required String name,
    required double dailyRentalPrice,
    required double securityDepositAmount,
    required int totalUnits,
    String category = 'Misc',
    String? description,
    String? imageUrl,
  }) async {
    final body = await _api.post('/api/equipment/items', data: {
      'name': name,
      'dailyRentalPrice': dailyRentalPrice,
      'securityDepositAmount': securityDepositAmount,
      'totalUnits': totalUnits,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
    });
    return EquipmentItemModel.fromJson(body as Map<String, dynamic>);
  }

  Future<EquipmentItemModel> updateItem({
    required String id,
    double? dailyRentalPrice,
    double? securityDepositAmount,
    int? stockAdjustment,
  }) async {
    final body = await _api.put('/api/equipment/items/$id', data: {
      'dailyRentalPrice': dailyRentalPrice,
      'securityDepositAmount': securityDepositAmount,
      'stockAdjustment': stockAdjustment,
    });
    return EquipmentItemModel.fromJson(body as Map<String, dynamic>);
  }

  Future<List<EquipmentRentalModel>> getRentals({String? status}) async {
    final body = await _api.get('/api/equipment/rentals',
        queryParameters: status != null ? {'status': status} : null);
    final list = body as List? ?? [];
    return list
        .map((e) => EquipmentRentalModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateRentalStatus({
    required String rentalId,
    required String newStatus,
  }) async {
    await _api.put('/api/equipment/rentals/$rentalId/status', data: {
      'newStatus': newStatus,
    });
  }

  Future<CompleteReturnResult> completeReturn({
    required String rentalId,
    int lateMinutes = 0,
    double damageAmount = 0,
    String? returnConditionPhotosJson,
  }) async {
    final body = await _api.post('/api/equipment/rentals/$rentalId/return',
        data: {
          'lateMinutes': lateMinutes,
          'damageAmount': damageAmount,
          'returnConditionPhotosJson': returnConditionPhotosJson,
        });
    return CompleteReturnResult.fromJson(body as Map<String, dynamic>);
  }
}
