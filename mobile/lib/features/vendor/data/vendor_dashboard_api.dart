import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class DashboardData {
  DashboardData({
    required this.totalBookingsToday,
    required this.pendingBookings,
    required this.confirmedBookings,
    required this.completedBookings,
    required this.revenueToday,
    required this.recentBookings,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        totalBookingsToday: json['totalBookingsToday'] as int? ?? 0,
        pendingBookings: json['pendingBookings'] as int? ?? 0,
        confirmedBookings: json['confirmedBookings'] as int? ?? 0,
        completedBookings: json['completedBookings'] as int? ?? 0,
        revenueToday: (json['revenueToday'] as num?)?.toDouble() ?? 0.0,
        recentBookings: (json['recentBookings'] as List?)
                ?.map((e) => BookingSummary.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  final int totalBookingsToday;
  final int pendingBookings;
  final int confirmedBookings;
  final int completedBookings;
  final double revenueToday;
  final List<BookingSummary> recentBookings;
}

class BookingSummary {
  BookingSummary({
    required this.bookingId,
    required this.serviceType,
    required this.customerName,
    required this.scheduledFor,
    required this.status,
    required this.amount,
    required this.paymentStatus,
    this.guestCount,
    this.durationHours,
    this.driverName,
    this.vehiclePlate,
  });

  factory BookingSummary.fromJson(Map<String, dynamic> json) => BookingSummary(
        bookingId: json['bookingId'] as String,
        serviceType: json['serviceType'] as String? ?? '',
        customerName: json['customerName'] as String? ?? '',
        scheduledFor: json['scheduledFor'] as String? ?? '',
        status: json['status'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: json['paymentStatus'] as String? ?? '',
        guestCount: (json['guestCount'] as num?)?.toInt() ??
            (json['numberOfGuests'] as num?)?.toInt(),
        durationHours: (json['durationHours'] as num?)?.toDouble(),
        driverName: json['driverName'] as String?,
        vehiclePlate: json['vehiclePlate'] as String?,
      );

  final String bookingId;
  final String serviceType;
  final String customerName;
  final String scheduledFor;
  final String status;
  final double amount;
  final String paymentStatus;
  final int? guestCount;
  final double? durationHours;
  final String? driverName;
  final String? vehiclePlate;
}

/// Vendor profile data including the master "Accepting Orders" toggle state.
class VendorProfile {
  VendorProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.isApproved,
    required this.isActive,
    required this.isAcceptingOrders,
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json) => VendorProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        isApproved: json['isApproved'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? false,
        isAcceptingOrders: json['isAcceptingOrders'] as bool? ?? true,
      );

  final String id;
  final String name;
  final String category;
  final bool isApproved;
  final bool isActive;
  final bool isAcceptingOrders;
}

class ActivatePriorityResult {
  ActivatePriorityResult({
    required this.success,
    required this.remainingBalance,
    required this.expiry,
    required this.message,
  });

  factory ActivatePriorityResult.fromJson(Map<String, dynamic> json) =>
      ActivatePriorityResult(
        success: json['success'] as bool? ?? false,
        remainingBalance: (json['remainingBalance'] as num?)?.toDouble() ?? 0.0,
        expiry: json['expiry'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );

  final bool success;
  final double remainingBalance;
  final String expiry;
  final String message;
}

class VendorDashboardApi {
  VendorDashboardApi(this._api);

  final ApiClient _api;

  Future<DashboardData> getDashboard() async {
    final body = await _api.get('/api/vendor/dashboard');
    return DashboardData.fromJson(body as Map<String, dynamic>);
  }

  /// Fetches the vendor profile including the master "Accepting Orders"
  /// toggle state so the partner app can show the correct status on startup.
  Future<VendorProfile> getProfile() async {
    final body = await _api.get('/api/vendor/profile');
    return VendorProfile.fromJson(body as Map<String, dynamic>);
  }

  Future<List<BookingSummary>> getBookings() async {
    final body = await _api.get('/api/vendor/bookings');
    final json = body as Map<String, dynamic>;
    final bookings = json['bookings'] as List? ?? [];
    return bookings
        .map((e) => BookingSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Assigns a driver and optional vehicle plate to a transit trip.
  /// Used by taxi operator vendors for fleet dispatch management.
  Future<void> assignTransitDriver(
    String tripId, {
    String? driverName,
    String? vehiclePlate,
  }) async {
    await _api.put('/api/vendor/transit/$tripId/assign-driver', data: {
      'driverName': driverName,
      'vehiclePlate': vehiclePlate,
    });
  }

  /// Removes an item from a food order and triggers a partial refund for
  /// the item's price. Used when a vendor discovers an item is out of stock
  /// after accepting the order. The rest of the order stays active.
  Future<Map<String, dynamic>> partialRefund(String orderId, String itemId) async {
    final body = await _api.post('/api/vendor/orders/$orderId/partial-refund', data: {
      'itemId': itemId,
    });
    return body as Map<String, dynamic>;
  }

  Future<ActivatePriorityResult> activatePriority(String venueId) async {
    final body = await _api.post(
      '/api/vendor/activate-priority',
      data: {'venueId': venueId},
    );
    return ActivatePriorityResult.fromJson(body as Map<String, dynamic>);
  }

  Future<bool> toggleVenueAvailability(String venueId) async {
    final body = await _api.put('/api/vendor/venues/$venueId/availability');
    final json = body as Map<String, dynamic>;
    return json['isActive'] as bool? ?? false;
  }

  /// Master "Accepting Orders" emergency toggle. When set to false, the
  /// consumer app instantly greys out the vendor card and disables
  /// "Add to Cart" via a SignalR VendorStatusChanged broadcast.
  Future<bool> toggleStatus(bool isAcceptingOrders) async {
    final body = await _api.put('/api/vendor/status', data: {
      'isAcceptingOrders': isAcceptingOrders,
    });
    final json = body as Map<String, dynamic>;
    return json['isAcceptingOrders'] as bool? ?? isAcceptingOrders;
  }

  /// Fetches the vendor's venue list to resolve the real venue ID.
  Future<List<VendorVenueSummary>> getVenues() async {
    final body = await _api.get('/api/vendor/venues');
    final list = body as List? ?? [];
    return list
        .map((e) => VendorVenueSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Menu Management ──

  Future<List<MenuItemModel>> getMenu() async {
    final body = await _api.get('/api/vendor/menu');
    final list = body as List? ?? [];
    return list.map((e) => MenuItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MenuItemModel> createMenuItem(CreateMenuItemPayload payload) async {
    final body = await _api.post('/api/vendor/menu', data: payload.toJson());
    return MenuItemModel.fromJson(body as Map<String, dynamic>);
  }

  Future<void> updateMenuItem(String id, UpdateMenuItemPayload payload) async {
    await _api.put('/api/vendor/menu/$id', data: payload.toJson());
  }

  Future<void> toggleMenuItem(String id) async {
    await _api.post('/api/vendor/menu/$id/toggle');
  }

  // ── Promotions & Flash Sales ──

  Future<List<VendorPromotionModel>> getPromotions() async {
    final body = await _api.get('/api/vendor/promotions');
    final list = body as List? ?? [];
    return list.map((e) => VendorPromotionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VendorPromotionModel> createPromotion(CreatePromotionPayload payload) async {
    final body = await _api.post('/api/vendor/promotions', data: payload.toJson());
    return VendorPromotionModel.fromJson(body as Map<String, dynamic>);
  }

  Future<List<FlashPromoModel>> getFlashPromos() async {
    final body = await _api.get('/api/vendor/flash-promos');
    final list = body as List? ?? [];
    return list.map((e) => FlashPromoModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FlashPromoModel> createFlashPromo(CreateFlashPromoPayload payload) async {
    final body = await _api.post('/api/vendor/flash-promos', data: payload.toJson());
    return FlashPromoModel.fromJson(body as Map<String, dynamic>);
  }

  // ── Food Order Management ──

  Future<List<VendorOrderModel>> getOrders({int page = 1, int pageSize = 50}) async {
    final body = await _api.get('/api/vendor/orders', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    final list = body as List? ?? [];
    return list.map((e) => VendorOrderModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _api.put('/api/vendor/orders/$orderId/status', data: {'newStatus': newStatus});
  }

  // ── Booking Status Management ──

  Future<void> updateBookingStatus(String bookingId, String serviceType, String newStatus) async {
    await _api.put('/api/vendor/bookings/$bookingId/status', data: {
      'serviceType': serviceType,
      'newStatus': newStatus,
    });
  }

  // ── Venue CRUD ──

  Future<VendorVenueDetail> createVenue(CreateVenuePayload payload) async {
    final body = await _api.post('/api/vendor/venues', data: payload.toJson());
    return VendorVenueDetail.fromJson(body as Map<String, dynamic>);
  }

  Future<void> updateVenue(String venueId, UpdateVenuePayload payload) async {
    await _api.put('/api/vendor/venues/$venueId', data: payload.toJson());
  }

  Future<void> deactivateVenue(String venueId) async {
    await _api.delete('/api/vendor/venues/$venueId');
  }

  // ── Wallet / Credits ──

  Future<VendorWalletModel> getWallet() async {
    final body = await _api.get('/api/vendor/wallet');
    return VendorWalletModel.fromJson(body as Map<String, dynamic>);
  }

  Future<List<WalletTransactionModel>> getWalletTransactions() async {
    final body = await _api.get('/api/vendor/wallet/transactions');
    final list = body as List? ?? [];
    return list.map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Luggage Cloak Operations ──

  /// Lists luggage drop-offs for the authenticated vendor, optionally
  /// filtered by status. Used by the Cloak Capacity screen.
  Future<List<LuggageDropOffModel>> getLuggageDropOffs({String? status}) async {
    final body = await _api.get(
      '/api/vendor/luggage',
      queryParameters: {if (status != null) 'status': status},
    );
    final list = body as List? ?? [];
    return list.map((e) => LuggageDropOffModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates a walk-in claim check for a luggage drop-off. Returns the
  /// claim check ID and QR payload for the customer to scan at pickup.
  Future<ClaimCheckResult> createClaimCheck({
    required String customerName,
    required int bagCount,
  }) async {
    final body = await _api.post('/api/vendor/claim-check', data: {
      'customerName': customerName,
      'bagCount': bagCount,
    });
    return ClaimCheckResult.fromJson(body as Map<String, dynamic>);
  }

  /// Receives bags at the partner location with an intake photo.
  /// Transitions the status from Reserved to Dropped.
  Future<ReceiveBagsResult> receiveBags(String dropOffId, File intakePhoto) async {
    final formData = FormData.fromMap({
      'intakePhoto': await MultipartFile.fromFile(intakePhoto.path,
          filename: 'intake_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    });
    final body = await _api.post(
      '/api/vendor/luggage/$dropOffId/receive',
      data: formData,
    );
    return ReceiveBagsResult.fromJson(body as Map<String, dynamic>);
  }

  /// Collects bags using the retrieval PIN. Closes the liability loop.
  Future<CollectBagsResult> collectBags(String dropOffId, String pin) async {
    final body = await _api.post('/api/vendor/luggage/$dropOffId/collect', data: {
      'pin': pin,
    });
    return CollectBagsResult.fromJson(body as Map<String, dynamic>);
  }

  // ── Scooter Rental Operations ──

  /// Records pre-rental 4-angle condition photos as a JSON string.
  Future<ConditionPhotosResult> recordConditionPhotos(
    String rentalId,
    String photosJson,
  ) async {
    final body = await _api.post('/api/vendor/rentals/$rentalId/condition-photos', data: {
      'photosJson': photosJson,
    });
    return ConditionPhotosResult.fromJson(body as Map<String, dynamic>);
  }

  /// Completes a rental return with late fees, damage penalties, and
  /// return condition photos.
  Future<RentalReturnResult> completeRentalReturn(
    String rentalId, {
    int lateMinutes = 0,
    double damageAmount = 0,
    String? returnConditionPhotosJson,
  }) async {
    final body = await _api.post('/api/vendor/rentals/$rentalId/complete-return', data: {
      'lateMinutes': lateMinutes,
      'damageAmount': damageAmount,
      if (returnConditionPhotosJson != null) 'returnConditionPhotosJson': returnConditionPhotosJson,
    });
    return RentalReturnResult.fromJson(body as Map<String, dynamic>);
  }

  // ── Venue Occupancy ──

  /// Updates the live occupancy percentage for a venue.
  Future<void> updateOccupancy(String venueId, int occupancyPercentage) async {
    await _api.post('/api/vendor/occupancy', data: {
      'venueId': venueId,
      'occupancyPercentage': occupancyPercentage,
    });
  }
}

class MenuItemModel {
  MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isAvailable,
    this.description,
    this.imageUrl,
    this.isLateNight = false,
    this.isVeg = false,
    this.prepTimeMinutes,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String? ?? '',
        isAvailable: json['isAvailable'] as bool? ?? true,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        isLateNight: json['isLateNight'] as bool? ?? false,
        isVeg: json['isVeg'] as bool? ?? false,
        prepTimeMinutes: json['prepTimeMinutes'] as int?,
      );

  final String id;
  final String name;
  final double price;
  final String category;
  final bool isAvailable;
  final String? description;
  final String? imageUrl;
  final bool isLateNight;
  final bool isVeg;
  final int? prepTimeMinutes;
}

class CreateMenuItemPayload {
  CreateMenuItemPayload({
    required this.name,
    required this.price,
    required this.category,
    this.description,
    this.imageUrl,
    this.isLateNight = false,
    this.isVeg = false,
    this.prepTimeMinutes,
  });

  final String name;
  final double price;
  final String category;
  final String? description;
  final String? imageUrl;
  final bool isLateNight;
  final bool isVeg;
  final int? prepTimeMinutes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'category': category,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'isLateNight': isLateNight,
        'isVeg': isVeg,
        if (prepTimeMinutes != null) 'prepTimeMinutes': prepTimeMinutes,
      };
}

class UpdateMenuItemPayload {
  UpdateMenuItemPayload({
    this.name,
    this.description,
    this.category,
    this.newPrice,
    this.isVeg,
    this.prepTimeMinutes,
    this.imageUrl,
  });

  final String? name;
  final String? description;
  final String? category;
  final double? newPrice;
  final bool? isVeg;
  final int? prepTimeMinutes;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (newPrice != null) 'newPrice': newPrice,
        if (isVeg != null) 'isVeg': isVeg,
        if (prepTimeMinutes != null) 'prepTimeMinutes': prepTimeMinutes,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

class VendorPromotionModel {
  VendorPromotionModel({
    required this.id,
    required this.discountPercentage,
    required this.isActive,
    required this.expiresAt,
    this.title,
    this.description,
  });

  factory VendorPromotionModel.fromJson(Map<String, dynamic> json) =>
      VendorPromotionModel(
        id: json['promotionId'] as String? ?? json['id'] as String? ?? '',
        discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        expiresAt: json['expiresAt'] as String? ?? '',
        title: json['title'] as String?,
        description: json['description'] as String?,
      );

  final String id;
  final double discountPercentage;
  final bool isActive;
  final String expiresAt;
  final String? title;
  final String? description;
}

class CreatePromotionPayload {
  CreatePromotionPayload({
    required this.discountPercentage,
    required this.expiresAt,
    this.title,
    this.description,
  });

  final double discountPercentage;
  final String expiresAt;
  final String? title;
  final String? description;

  Map<String, dynamic> toJson() => {
        'discountPercentage': discountPercentage,
        'expiresAt': expiresAt,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      };
}

class FlashPromoModel {
  FlashPromoModel({
    required this.id,
    required this.discountPercentage,
    required this.durationMinutes,
    required this.isActive,
    this.title,
    this.description,
  });

  factory FlashPromoModel.fromJson(Map<String, dynamic> json) => FlashPromoModel(
        id: json['flashPromoId'] as String? ?? json['id'] as String? ?? '',
        discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        title: json['title'] as String?,
        description: json['description'] as String?,
      );

  final String id;
  final double discountPercentage;
  final int durationMinutes;
  final bool isActive;
  final String? title;
  final String? description;
}

class CreateFlashPromoPayload {
  CreateFlashPromoPayload({
    required this.discountPercentage,
    required this.durationMinutes,
    this.title,
    this.description,
  });

  final double discountPercentage;
  final int durationMinutes;
  final String? title;
  final String? description;

  Map<String, dynamic> toJson() => {
        'discountPercentage': discountPercentage,
        'durationMinutes': durationMinutes,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      };
}

/// Lightweight venue summary returned by GET /api/vendor/venues.
class VendorVenueSummary {
  VendorVenueSummary({
    required this.venueId,
    required this.name,
    required this.category,
    required this.isActive,
    this.maxCapacity = 0,
    this.currentCapacity = 0,
    this.checkedInCount = 0,
  });

  factory VendorVenueSummary.fromJson(Map<String, dynamic> json) =>
      VendorVenueSummary(
        venueId: json['venueId'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
        maxCapacity: (json['maxCapacity'] as num?)?.toInt() ?? 0,
        currentCapacity: (json['currentCapacity'] as num?)?.toInt() ?? 0,
        checkedInCount: (json['checkedInCount'] as num?)?.toInt() ?? 0,
      );

  final String venueId;
  final String name;
  final String category;
  final bool isActive;
  final int maxCapacity;
  final int currentCapacity;
  final int checkedInCount;
}

// ── Food Order Models ──

class VendorOrderModel {
  VendorOrderModel({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.placedAt,
    this.vendorName,
  });

  factory VendorOrderModel.fromJson(Map<String, dynamic> json) => VendorOrderModel(
        id: json['id'] as String? ?? '',
        vendorName: json['vendorName'] as String?,
        status: json['status'] as String? ?? 'Pending',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        placedAt: json['placedAt'] as String? ?? '',
      );

  final String id;
  final String? vendorName;
  final String status;
  final double totalAmount;
  final String placedAt;
}

// ── Venue Detail Models ──

class VendorVenueDetail {
  VendorVenueDetail({
    required this.venueId,
    required this.name,
    required this.category,
    required this.isActive,
    this.description,
    this.address,
    this.phone,
    this.openingTime,
    this.closingTime,
    this.imageUrl,
  });

  factory VendorVenueDetail.fromJson(Map<String, dynamic> json) =>
      VendorVenueDetail(
        venueId: json['venueId'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
        description: json['description'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        openingTime: json['openingTime'] as String?,
        closingTime: json['closingTime'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );

  final String venueId;
  final String name;
  final String category;
  final bool isActive;
  final String? description;
  final String? address;
  final String? phone;
  final String? openingTime;
  final String? closingTime;
  final String? imageUrl;
}

// ── Luggage & Rental Response Models ──

class LuggageDropOffModel {
  LuggageDropOffModel({
    required this.id,
    required this.bagCount,
    required this.status,
    required this.scheduledFor,
    this.droppedAt,
    this.collectedAt,
    this.intakeImageUrl,
    this.notes,
  });

  factory LuggageDropOffModel.fromJson(Map<String, dynamic> json) => LuggageDropOffModel(
        id: json['id'] as String,
        bagCount: json['bagCount'] as int? ?? 0,
        status: json['status'] as String? ?? '',
        scheduledFor: json['scheduledFor'] as String? ?? '',
        droppedAt: json['droppedAt'] as String?,
        collectedAt: json['collectedAt'] as String?,
        intakeImageUrl: json['intakeImageUrl'] as String?,
        notes: json['notes'] as String?,
      );

  final String id;
  final int bagCount;
  final String status;
  final String scheduledFor;
  final String? droppedAt;
  final String? collectedAt;
  final String? intakeImageUrl;
  final String? notes;
}

class ClaimCheckResult {
  ClaimCheckResult({
    required this.claimCheckId,
    required this.customerName,
    required this.bagCount,
    required this.qrPayload,
  });

  factory ClaimCheckResult.fromJson(Map<String, dynamic> json) => ClaimCheckResult(
        claimCheckId: json['claimCheckId'] as String,
        customerName: json['customerName'] as String? ?? '',
        bagCount: json['bagCount'] as int? ?? 0,
        qrPayload: json['qrPayload'] as String? ?? '',
      );

  final String claimCheckId;
  final String customerName;
  final int bagCount;
  final String qrPayload;
}

class ReceiveBagsResult {
  ReceiveBagsResult({required this.dropOffId, required this.message, this.intakeImageUrl});

  factory ReceiveBagsResult.fromJson(Map<String, dynamic> json) => ReceiveBagsResult(
        dropOffId: json['dropOffId'] as String,
        message: json['message'] as String? ?? '',
        intakeImageUrl: json['intakeImageUrl'] as String?,
      );

  final String dropOffId;
  final String message;
  final String? intakeImageUrl;
}

class CollectBagsResult {
  CollectBagsResult({required this.dropOffId, required this.message});

  factory CollectBagsResult.fromJson(Map<String, dynamic> json) => CollectBagsResult(
        dropOffId: json['dropOffId'] as String,
        message: json['message'] as String? ?? '',
      );

  final String dropOffId;
  final String message;
}

class ConditionPhotosResult {
  ConditionPhotosResult({required this.rentalId, required this.message});

  factory ConditionPhotosResult.fromJson(Map<String, dynamic> json) => ConditionPhotosResult(
        rentalId: json['rentalId'] as String,
        message: json['message'] as String? ?? '',
      );

  final String rentalId;
  final String message;
}

class RentalReturnResult {
  RentalReturnResult({
    required this.rentalId,
    required this.securityDeposit,
    required this.penaltyDeducted,
    required this.depositRefunded,
    required this.totalAmount,
  });

  factory RentalReturnResult.fromJson(Map<String, dynamic> json) => RentalReturnResult(
        rentalId: json['rentalId'] as String,
        securityDeposit: (json['securityDeposit'] as num?)?.toDouble() ?? 0,
        penaltyDeducted: (json['penaltyDeducted'] as num?)?.toDouble() ?? 0,
        depositRefunded: (json['depositRefunded'] as num?)?.toDouble() ?? 0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      );

  final String rentalId;
  final double securityDeposit;
  final double penaltyDeducted;
  final double depositRefunded;
  final double totalAmount;
}

class CreateVenuePayload {
  CreateVenuePayload({
    required this.name,
    required this.category,
    this.description,
    this.address,
    this.phone,
    this.openingTime,
    this.closingTime,
  });

  final String name;
  final String category;
  final String? description;
  final String? address;
  final String? phone;
  final String? openingTime;
  final String? closingTime;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        if (description != null) 'description': description,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (openingTime != null) 'openingTime': openingTime,
        if (closingTime != null) 'closingTime': closingTime,
      };
}

class UpdateVenuePayload {
  UpdateVenuePayload({
    this.name,
    this.description,
    this.address,
    this.phone,
    this.openingTime,
    this.closingTime,
    this.imageUrl,
  });

  final String? name;
  final String? description;
  final String? address;
  final String? phone;
  final String? openingTime;
  final String? closingTime;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (openingTime != null) 'openingTime': openingTime,
        if (closingTime != null) 'closingTime': closingTime,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

// ── Wallet Models ──

class VendorWalletModel {
  VendorWalletModel({
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
  });

  factory VendorWalletModel.fromJson(Map<String, dynamic> json) =>
      VendorWalletModel(
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0.0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      );

  final double balance;
  final double totalEarned;
  final double totalSpent;
}

class WalletTransactionModel {
  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) =>
      WalletTransactionModel(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? '',
      );

  final String id;
  final String type;
  final double amount;
  final String description;
  final String timestamp;
}
