import '../../../core/network/api_client.dart';

/// API client for the party services marketplace (DJ, bartender, catering, etc.)
class PartyServicesApi {
  PartyServicesApi(this._api);

  final ApiClient _api;

  /// Browse available party services with optional category filter.
  Future<List<PartyServiceModel>> browse({String? category}) async {
    final body = await _api.get('/api/party-services/browse',
        queryParameters: category != null ? {'category': category} : null);
    final list = body as List? ?? [];
    return list
        .map((e) => PartyServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a booking request for a party service.
  Future<CreateBookingResult> createBooking({
    required String serviceId,
    required DateTime eventDate,
    required int quantity,
    String? eventAddress,
    String? notes,
  }) async {
    final body = await _api.post('/api/party-services/bookings', data: {
      'serviceId': serviceId,
      'eventDate': eventDate.toUtc().toIso8601String(),
      'quantity': quantity,
      'eventAddress': eventAddress,
      'notes': notes,
    });
    return CreateBookingResult.fromJson(body as Map<String, dynamic>);
  }

  /// Confirm a booking after successful Razorpay payment.
  Future<void> confirmBooking({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
  }) async {
    await _api.post('/api/party-services/bookings/$bookingId/confirm', data: {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
    });
  }

  /// Get the current user's party service bookings.
  Future<List<PartyServiceBookingModel>> getMyBookings() async {
    final body = await _api.get('/api/party-services/bookings/my');
    final list = body as List? ?? [];
    return list
        .map((e) => PartyServiceBookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Vendor endpoints ──

  /// List the current vendor's party service listings.
  Future<List<PartyServiceModel>> getMyServices() async {
    final body = await _api.get('/api/party-services/my');
    final list = body as List? ?? [];
    return list
        .map((e) => PartyServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new party service listing.
  Future<PartyServiceModel> createService(CreatePartyServiceRequest request) async {
    final body = await _api.post('/api/party-services', data: request.toJson());
    return PartyServiceModel.fromJson(body as Map<String, dynamic>);
  }

  /// Update a party service listing.
  Future<void> updateService(String id, UpdatePartyServiceRequest request) async {
    await _api.put('/api/party-services/$id', data: request.toJson());
  }

  /// Get bookings for the current vendor's services.
  Future<List<VendorBookingModel>> getVendorBookings({String? status}) async {
    final body = await _api.get('/api/party-services/bookings/vendor',
        queryParameters: status != null ? {'status': status} : null);
    final list = body as List? ?? [];
    return list
        .map((e) => VendorBookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Update a booking status (confirm, complete, cancel).
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _api.put('/api/party-services/bookings/$bookingId/status', data: {
      'status': status,
    });
  }
}

class PartyServiceModel {
  PartyServiceModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.category,
    required this.title,
    this.description,
    required this.basePrice,
    required this.pricingUnit,
    required this.minimumBooking,
    this.imageUrl,
    this.tags,
    this.serviceArea,
    required this.isApproved,
  });

  factory PartyServiceModel.fromJson(Map<String, dynamic> json) =>
      PartyServiceModel(
        id: json['id'] as String? ?? '',
        vendorId: json['vendorId'] as String? ?? '',
        vendorName: json['vendorName'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
        pricingUnit: json['pricingUnit'] as String? ?? 'per event',
        minimumBooking: (json['minimumBooking'] as num?)?.toInt() ?? 1,
        imageUrl: json['imageUrl'] as String?,
        tags: json['tags'] as String?,
        serviceArea: json['serviceArea'] as String?,
        isApproved: json['isApproved'] as bool? ?? false,
      );

  final String id;
  final String vendorId;
  final String vendorName;
  final String category;
  final String title;
  final String? description;
  final double basePrice;
  final String pricingUnit;
  final int minimumBooking;
  final String? imageUrl;
  final String? tags;
  final String? serviceArea;
  final bool isApproved;
}

class CreateBookingResult {
  CreateBookingResult({required this.bookingId, required this.totalAmount});

  factory CreateBookingResult.fromJson(Map<String, dynamic> json) =>
      CreateBookingResult(
        bookingId: json['bookingId'] as String? ?? '',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      );

  final String bookingId;
  final double totalAmount;
}

class PartyServiceBookingModel {
  PartyServiceBookingModel({
    required this.id,
    required this.serviceTitle,
    required this.category,
    required this.eventDate,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.eventAddress,
    this.notes,
  });

  factory PartyServiceBookingModel.fromJson(Map<String, dynamic> json) =>
      PartyServiceBookingModel(
        id: json['id'] as String? ?? '',
        serviceTitle: json['serviceTitle'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        eventDate: json['eventDate'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'Pending',
        paymentStatus: json['paymentStatus'] as String? ?? 'Unpaid',
        eventAddress: json['eventAddress'] as String?,
        notes: json['notes'] as String?,
      );

  final String id;
  final String serviceTitle;
  final String category;
  final String eventDate;
  final int quantity;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String? eventAddress;
  final String? notes;
}

class VendorBookingModel {
  VendorBookingModel({
    required this.id,
    required this.serviceTitle,
    required this.category,
    required this.eventDate,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
  });

  factory VendorBookingModel.fromJson(Map<String, dynamic> json) =>
      VendorBookingModel(
        id: json['id'] as String? ?? '',
        serviceTitle: json['serviceTitle'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        eventDate: json['eventDate'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'Pending',
        paymentStatus: json['paymentStatus'] as String? ?? 'Unpaid',
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );

  final String id;
  final String serviceTitle;
  final String category;
  final String eventDate;
  final int quantity;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String? notes;
  final String createdAt;
}

class CreatePartyServiceRequest {
  CreatePartyServiceRequest({
    required this.title,
    required this.category,
    required this.basePrice,
    this.pricingUnit,
    this.minimumBooking,
    this.description,
    this.imageUrl,
    this.tags,
    this.serviceArea,
  });

  final String title;
  final String category;
  final double basePrice;
  final String? pricingUnit;
  final int? minimumBooking;
  final String? description;
  final String? imageUrl;
  final String? tags;
  final String? serviceArea;

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'basePrice': basePrice,
        if (pricingUnit != null) 'pricingUnit': pricingUnit,
        if (minimumBooking != null) 'minimumBooking': minimumBooking,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (tags != null) 'tags': tags,
        if (serviceArea != null) 'serviceArea': serviceArea,
      };
}

class UpdatePartyServiceRequest {
  UpdatePartyServiceRequest({
    this.basePrice,
    this.title,
    this.description,
    this.imageUrl,
    this.tags,
    this.serviceArea,
    this.isAvailable,
    this.minimumBooking,
  });

  final double? basePrice;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? tags;
  final String? serviceArea;
  final bool? isAvailable;
  final int? minimumBooking;

  Map<String, dynamic> toJson() => {
        if (basePrice != null) 'basePrice': basePrice,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (tags != null) 'tags': tags,
        if (serviceArea != null) 'serviceArea': serviceArea,
        if (isAvailable != null) 'isAvailable': isAvailable,
        if (minimumBooking != null) 'minimumBooking': minimumBooking,
      };
}
