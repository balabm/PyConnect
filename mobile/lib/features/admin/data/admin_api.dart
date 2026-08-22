import '../../../core/network/api_client.dart';

/// Client for the /api/admin endpoints. Powers the admin super-app
/// "God Mode" dashboard with real data from every backend module.
class AdminApi {
  AdminApi(this._api);

  final ApiClient _api;

  // === Dashboard Stats ===

  Future<AdminDashboardStats> getDashboardStats() async {
    final result = await _api.get('/api/admin/dashboard-stats');
    return AdminDashboardStats.fromJson(result as Map<String, dynamic>);
  }

  // === Finance ===

  Future<AdminFinanceSummary> getFinanceSummary() async {
    final result = await _api.get('/api/admin/finance/summary');
    return AdminFinanceSummary.fromJson(result as Map<String, dynamic>);
  }

  Future<List<AdminSettlementLog>> getSettlements() async {
    final result = await _api.get('/api/admin/finance/settlements');
    final list = result as List<dynamic>;
    return list
        .map((e) => AdminSettlementLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // === Vendor Management ===

  Future<List<AdminVendor>> getVendors() async {
    final result = await _api.get('/api/admin/vendors');
    final list = result as List<dynamic>;
    return list
        .map((e) => AdminVendor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OnboardVendorResult> onboardVendor(OnboardVendorRequest req) async {
    final result = await _api.post('/api/admin/vendors', data: req.toJson());
    return OnboardVendorResult.fromJson(result as Map<String, dynamic>);
  }

  Future<void> approveVendor(String vendorId) async {
    await _api.post('/api/admin/vendors/$vendorId/approve');
  }

  Future<void> rejectVendor(String vendorId, {String? reason}) async {
    await _api.post('/api/admin/vendors/$vendorId/reject',
        data: {'reason': reason});
  }

  // === User Management ===

  Future<AdminPagedResult<AdminUser>> getUsers({
    String? search,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async {
    final qp = <String, dynamic>{'page': page.toString(), 'pageSize': pageSize.toString()};
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (role != null && role.isNotEmpty) qp['role'] = role;
    if (isActive != null) qp['isActive'] = isActive.toString();
    final result = await _api.get('/api/admin/users', queryParameters: qp);
    return AdminPagedResult.fromJson(
      result as Map<String, dynamic>,
      (e) => AdminUser.fromJson(e),
    );
  }

  Future<void> changeUserRole(String userId, String newRole) async {
    await _api.post('/api/admin/users/$userId/role', data: {'newRole': newRole});
  }

  Future<void> setUserActiveStatus(String userId, bool isActive) async {
    await _api.post('/api/admin/users/$userId/active-status',
        queryParameters: {'isActive': isActive.toString()});
  }

  // === Driver Management ===

  Future<AdminPagedResult<AdminDriver>> getDrivers({
    String? search,
    bool? isApproved,
    bool? isOnline,
    bool kycUploadedOnly = false,
    int page = 1,
    int pageSize = 50,
  }) async {
    final qp = <String, dynamic>{'page': page.toString(), 'pageSize': pageSize.toString()};
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (isApproved != null) qp['isApproved'] = isApproved.toString();
    if (isOnline != null) qp['isOnline'] = isOnline.toString();
    if (kycUploadedOnly) qp['kycUploadedOnly'] = 'true';
    final result = await _api.get('/api/admin/drivers', queryParameters: qp);
    return AdminPagedResult.fromJson(
      result as Map<String, dynamic>,
      (e) => AdminDriver.fromJson(e),
    );
  }

  Future<ApproveDriverResult> approveDriver(String driverId) async {
    final result = await _api.post('/api/admin/approve-driver/$driverId');
    return ApproveDriverResult.fromJson(result as Map<String, dynamic>);
  }

  Future<ApproveDriverResult> approveKyc(String driverId) async {
    final result = await _api.post('/api/admin/kyc/$driverId/approve');
    return ApproveDriverResult.fromJson(result as Map<String, dynamic>);
  }

  Future<RefundTicketResult> refundTicket(
    String ticketId, {
    required bool fullRefund,
    double? amount,
  }) async {
    final result = await _api.post(
      '/api/admin/tickets/$ticketId/refund',
      data: {
        'fullRefund': fullRefund,
        if (amount != null) 'amount': amount,
      },
    );
    return RefundTicketResult.fromJson(result as Map<String, dynamic>);
  }

  Future<void> rejectDriverKyc(String driverId, {String? reason}) async {
    await _api.post('/api/admin/drivers/$driverId/reject-kyc',
        data: {'reason': reason});
  }

  // === Live Operations: SOS ===

  Future<List<AdminSosAlert>> getActiveSosAlerts() async {
    final result = await _api.get('/api/admin/sos-alerts');
    final list = result as List<dynamic>;
    return list
        .map((e) => AdminSosAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveSosAlert(String sosAlertId, {String? notes}) async {
    await _api.post('/api/admin/sos-alerts/$sosAlertId/resolve',
        data: {'notes': notes});
  }

  /// Legacy SOS events endpoint (kept for backward compatibility).
  Future<List<AdminSosEvent>> getSosEvents() async {
    final result = await _api.get('/api/admin/sos-events');
    final list = result as List<dynamic>;
    return list
        .map((e) => AdminSosEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // === Live Operations: Active Rides ===

  Future<List<AdminActiveRide>> getActiveRides() async {
    final result = await _api.get('/api/admin/active-rides');
    final list = result as List<dynamic>;
    return list
        .map((e) => AdminActiveRide.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches in-flight food deliveries with driver location for the admin map.
  Future<List<Map<String, dynamic>>> getActiveDeliveries() async {
    final result = await _api.get('/api/admin/active-deliveries');
    final list = result as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // === Support Tickets ===

  Future<AdminPagedResult<AdminSupportTicket>> getSupportTickets({
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final qp = <String, dynamic>{'page': page.toString(), 'pageSize': pageSize.toString()};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    final result = await _api.get('/api/admin/support-tickets', queryParameters: qp);
    return AdminPagedResult.fromJson(
      result as Map<String, dynamic>,
      (e) => AdminSupportTicket.fromJson(e),
    );
  }

  Future<void> resolveSupportTicket(String ticketId) async {
    await _api.post('/api/admin/support-tickets/$ticketId/resolve');
  }

  // === Audit Logs ===

  Future<AdminPagedResult<AdminActionLog>> getActionLogs({
    String? actionType,
    String? adminUserId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final qp = <String, dynamic>{'page': page.toString(), 'pageSize': pageSize.toString()};
    if (actionType != null && actionType.isNotEmpty) qp['actionType'] = actionType;
    if (adminUserId != null && adminUserId.isNotEmpty) qp['adminUserId'] = adminUserId;
    final result = await _api.get('/api/admin/action-logs', queryParameters: qp);
    return AdminPagedResult.fromJson(
      result as Map<String, dynamic>,
      (e) => AdminActionLog.fromJson(e),
    );
  }

  // === Venue Controls ===

  Future<void> forceSoldOut(String venueId, bool soldOut) async {
    await _api.post('/api/admin/venues/$venueId/force-soldout',
        queryParameters: {'soldOut': soldOut.toString()});
  }

  Future<Map<String, dynamic>> setSurgeMode(String mode) async {
    return await _api.post('/api/admin/surge', data: {'mode': mode})
        as Map<String, dynamic>;
  }
}

// === Models ===

class AdminPagedResult<T> {
  AdminPagedResult({required this.items, required this.totalCount, required this.page, required this.pageSize});

  factory AdminPagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return AdminPagedResult<T>(
      items: (json['items'] as List<dynamic>)
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 50,
    );
  }

  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
}

class AdminDashboardStats {
  AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalDrivers,
    required this.approvedDrivers,
    required this.onlineDrivers,
    required this.activeRides,
    required this.activeSosAlerts,
    required this.openSupportTickets,
    required this.totalVendors,
    required this.approvedVendors,
    required this.totalVenues,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) =>
      AdminDashboardStats(
        totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
        activeUsers: (json['activeUsers'] as num?)?.toInt() ?? 0,
        totalDrivers: (json['totalDrivers'] as num?)?.toInt() ?? 0,
        approvedDrivers: (json['approvedDrivers'] as num?)?.toInt() ?? 0,
        onlineDrivers: (json['onlineDrivers'] as num?)?.toInt() ?? 0,
        activeRides: (json['activeRides'] as num?)?.toInt() ?? 0,
        activeSosAlerts: (json['activeSosAlerts'] as num?)?.toInt() ?? 0,
        openSupportTickets: (json['openSupportTickets'] as num?)?.toInt() ?? 0,
        totalVendors: (json['totalVendors'] as num?)?.toInt() ?? 0,
        approvedVendors: (json['approvedVendors'] as num?)?.toInt() ?? 0,
        totalVenues: (json['totalVenues'] as num?)?.toInt() ?? 0,
      );

  final int totalUsers;
  final int activeUsers;
  final int totalDrivers;
  final int approvedDrivers;
  final int onlineDrivers;
  final int activeRides;
  final int activeSosAlerts;
  final int openSupportTickets;
  final int totalVendors;
  final int approvedVendors;
  final int totalVenues;
}

class AdminVendor {
  AdminVendor({
    required this.id,
    required this.name,
    required this.contactPhone,
    required this.category,
    required this.isApproved,
    required this.isActive,
    this.cuisineType,
    this.rating,
    this.fssaiNumber,
    this.gstNumber,
    this.panNumber,
    this.fssaiDocUrl,
    this.gstDocUrl,
    this.panDocUrl,
  });

  factory AdminVendor.fromJson(Map<String, dynamic> json) => AdminVendor(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        contactPhone: json['contactPhone'] as String?,
        category: json['category'] as String? ?? 'Unknown',
        isApproved: json['isApproved'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        cuisineType: json['cuisineType'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        fssaiNumber: json['fssaiNumber'] as String?,
        gstNumber: json['gstNumber'] as String?,
        panNumber: json['panNumber'] as String?,
        fssaiDocUrl: json['fssaiDocUrl'] as String?,
        gstDocUrl: json['gstDocUrl'] as String?,
        panDocUrl: json['panDocUrl'] as String?,
      );

  final String id;
  final String name;
  final String? contactPhone;
  final String category;
  final bool isApproved;
  final bool isActive;
  final String? cuisineType;
  final double? rating;
  final String? fssaiNumber;
  final String? gstNumber;
  final String? panNumber;
  final String? fssaiDocUrl;
  final String? gstDocUrl;
  final String? panDocUrl;
}

class OnboardVendorRequest {
  OnboardVendorRequest({
    required this.name,
    required this.contactPhone,
    required this.category,
    this.cuisineType,
    this.description,
    this.deliveryFee,
    this.prepTimeMinutes,
  });

  final String name;
  final String contactPhone;
  final String category;
  final String? cuisineType;
  final String? description;
  final double? deliveryFee;
  final int? prepTimeMinutes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'contactPhone': contactPhone,
        'category': category,
        if (cuisineType != null) 'cuisineType': cuisineType,
        if (description != null) 'description': description,
        if (deliveryFee != null) 'deliveryFee': deliveryFee,
        if (prepTimeMinutes != null) 'prepTimeMinutes': prepTimeMinutes,
      };
}

class OnboardVendorResult {
  OnboardVendorResult({
    required this.vendorId,
    required this.userId,
    required this.name,
    required this.contactPhone,
    required this.category,
    required this.isApproved,
    required this.message,
  });

  factory OnboardVendorResult.fromJson(Map<String, dynamic> json) =>
      OnboardVendorResult(
        vendorId: json['vendorId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        contactPhone: json['contactPhone'] as String? ?? '',
        category: json['category'] as String? ?? '',
        isApproved: json['isApproved'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );

  final String vendorId;
  final String userId;
  final String name;
  final String contactPhone;
  final String category;
  final bool isApproved;
  final String message;
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.isProMember,
    required this.isVerifiedLocal,
    required this.kycStatus,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'Tourist',
        isActive: json['isActive'] as bool? ?? true,
        isProMember: json['isProMember'] as bool? ?? false,
        isVerifiedLocal: json['isVerifiedLocal'] as bool? ?? false,
        kycStatus: json['kycStatus'] as String? ?? 'Pending',
        lastLoginAt: json['lastLoginAt'] == null
            ? null
            : DateTime.tryParse(json['lastLoginAt'] as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isActive;
  final bool isProMember;
  final bool isVerifiedLocal;
  final String kycStatus;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
}

class AdminDriver {
  AdminDriver({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.isApproved,
    required this.isOnline,
    required this.isOnRide,
    required this.isKycUploaded,
    required this.rating,
    required this.totalRides,
    this.latitude,
    this.longitude,
    this.lastLocationAt,
    required this.createdAt,
    this.aadhaarUrl,
    this.drivingLicenseUrl,
    this.rcUrl,
    this.insuranceUrl,
    this.selfieUrl,
    this.kycAutoApproved,
    this.kycConfidence,
    this.kycVerificationReason,
    this.kycParsedName,
    this.kycLicenseNumber,
    this.kycExpiryDate,
    this.upiId,
    this.vehiclePlate,
  });

  factory AdminDriver.fromJson(Map<String, dynamic> json) => AdminDriver(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        phone: json['phone'] as String? ?? '',
        vehicleType: json['vehicleType'] as String? ?? 'Bike',
        isApproved: json['isApproved'] as bool? ?? false,
        isOnline: json['isOnline'] as bool? ?? false,
        isOnRide: json['isOnRide'] as bool? ?? false,
        isKycUploaded: json['isKycUploaded'] as bool? ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        totalRides: (json['totalRides'] as num?)?.toInt() ?? 0,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        lastLocationAt: json['lastLocationAt'] == null
            ? null
            : DateTime.tryParse(json['lastLocationAt'] as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        aadhaarUrl: json['aadhaarUrl'] as String?,
        drivingLicenseUrl: json['drivingLicenseUrl'] as String?,
        rcUrl: json['rcUrl'] as String?,
        insuranceUrl: json['insuranceUrl'] as String?,
        selfieUrl: json['selfieUrl'] as String?,
        kycAutoApproved: json['kycAutoApproved'] as bool?,
        kycConfidence: (json['kycConfidence'] as num?)?.toDouble(),
        kycVerificationReason: json['kycVerificationReason'] as String?,
        kycParsedName: json['kycParsedName'] as String?,
        kycLicenseNumber: json['kycLicenseNumber'] as String?,
        kycExpiryDate: json['kycExpiryDate'] == null
            ? null
            : DateTime.tryParse(json['kycExpiryDate'] as String),
        upiId: json['upiId'] as String?,
        vehiclePlate: json['vehiclePlate'] as String?,
      );

  final String id;
  final String userId;
  final String name;
  final String phone;
  final String vehicleType;
  final bool isApproved;
  final bool isOnline;
  final bool isOnRide;
  final bool isKycUploaded;
  final double rating;
  final int totalRides;
  final double? latitude;
  final double? longitude;
  final DateTime? lastLocationAt;
  final DateTime createdAt;
  final String? aadhaarUrl;
  final String? drivingLicenseUrl;
  final String? rcUrl;
  final String? insuranceUrl;
  final String? selfieUrl;
  final bool? kycAutoApproved;
  final double? kycConfidence;
  final String? kycVerificationReason;
  final String? kycParsedName;
  final String? kycLicenseNumber;
  final DateTime? kycExpiryDate;
  final String? upiId;
  final String? vehiclePlate;
}

class ApproveDriverResult {
  ApproveDriverResult({
    required this.success,
    required this.driverName,
    required this.message,
  });

  factory ApproveDriverResult.fromJson(Map<String, dynamic> json) =>
      ApproveDriverResult(
        success: json['success'] as bool? ?? false,
        driverName: json['driverName'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );

  final bool success;
  final String driverName;
  final String message;
}

class AdminSosAlert {
  AdminSosAlert({
    required this.id,
    required this.rideId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.triggeredAt,
    this.resolvedAt,
    this.notes,
    this.vehicleType,
    this.vehiclePlate,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory AdminSosAlert.fromJson(Map<String, dynamic> json) => AdminSosAlert(
        id: json['id'] as String? ?? '',
        rideId: json['rideId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? 'Unknown',
        userPhone: json['userPhone'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'Active',
        triggeredAt: DateTime.tryParse(json['triggeredAt'] as String? ?? '') ??
            DateTime.now(),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.tryParse(json['resolvedAt'] as String),
        notes: json['notes'] as String?,
        vehicleType: json['vehicleType'] as String?,
        vehiclePlate: json['vehiclePlate'] as String?,
        emergencyContactName: json['emergencyContactName'] as String?,
        emergencyContactPhone: json['emergencyContactPhone'] as String?,
      );

  final String id;
  final String rideId;
  final String userId;
  final String userName;
  final String userPhone;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? notes;
  final String? vehicleType;
  final String? vehiclePlate;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
}

class AdminSosEvent {
  AdminSosEvent({
    required this.id,
    required this.userName,
    required this.message,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.isResolved,
  });

  factory AdminSosEvent.fromJson(Map<String, dynamic> json) => AdminSosEvent(
        id: json['id'] as String? ?? '',
        userName: json['userName'] as String? ?? 'Unknown',
        message: json['message'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        isResolved: json['isResolved'] as bool? ?? false,
      );

  final String id;
  final String userName;
  final String message;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final bool isResolved;
}

class AdminActiveRide {
  AdminActiveRide({
    required this.id,
    required this.userId,
    required this.riderName,
    required this.riderPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.status,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropLatitude,
    this.dropLongitude,
    required this.estimatedFare,
    required this.vehicleType,
    required this.createdAt,
  });

  factory AdminActiveRide.fromJson(Map<String, dynamic> json) => AdminActiveRide(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        riderName: json['riderName'] as String? ?? 'Unknown',
        riderPhone: json['riderPhone'] as String? ?? '',
        driverId: json['driverId'] as String?,
        driverName: json['driverName'] as String?,
        driverPhone: json['driverPhone'] as String?,
        status: json['status'] as String? ?? 'Requested',
        pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
        pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
        dropLatitude: (json['dropLatitude'] as num?)?.toDouble(),
        dropLongitude: (json['dropLongitude'] as num?)?.toDouble(),
        estimatedFare: (json['estimatedFare'] as num?)?.toDouble() ?? 0,
        vehicleType: json['vehicleType'] as String? ?? 'Bike',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String userId;
  final String riderName;
  final String riderPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String status;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropLatitude;
  final double? dropLongitude;
  final double estimatedFare;
  final String vehicleType;
  final DateTime createdAt;
}

class AdminSupportTicket {
  AdminSupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.status,
    required this.priority,
    required this.source,
    this.issueCategory,
    this.latitude,
    this.longitude,
    this.acknowledgedAt,
    this.resolvedAt,
    required this.createdAt,
  });

  factory AdminSupportTicket.fromJson(Map<String, dynamic> json) =>
      AdminSupportTicket(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? 'Unknown',
        userPhone: json['userPhone'] as String? ?? '',
        status: json['status'] as String? ?? 'Open',
        priority: json['priority'] as String? ?? 'Normal',
        source: json['source'] as String? ?? 'InApp',
        issueCategory: json['issueCategory'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        acknowledgedAt: json['acknowledgedAt'] == null
            ? null
            : DateTime.tryParse(json['acknowledgedAt'] as String),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.tryParse(json['resolvedAt'] as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String status;
  final String priority;
  final String source;
  final String? issueCategory;
  final double? latitude;
  final double? longitude;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
}

class AdminActionLog {
  AdminActionLog({
    required this.id,
    required this.adminUserId,
    required this.actionType,
    this.entityType,
    this.entityId,
    this.payload,
    this.ipAddress,
    required this.createdAt,
  });

  factory AdminActionLog.fromJson(Map<String, dynamic> json) => AdminActionLog(
        id: json['id'] as String? ?? '',
        adminUserId: json['adminUserId'] as String? ?? '',
        actionType: json['actionType'] as String? ?? '',
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
        payload: json['payload'] is String
            ? json['payload'] as String?
            : json['payload']?.toString(),
        ipAddress: json['ipAddress'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String adminUserId;
  final String actionType;
  final String? entityType;
  final String? entityId;
  final String? payload;
  final String? ipAddress;
  final DateTime createdAt;
}

/// Typed SignalR events broadcast from the admin hub.
/// Each event corresponds to a backend `SendAsync("EventName", ...)` call.
class AdminSignalREvent {
  AdminSignalREvent({required this.type, this.payload});

  /// Event name from the backend (e.g. "SosAlert", "CriticalTicketPushed").
  final String type;

  /// Raw JSON payload from the event.
  final Map<String, dynamic>? payload;

  /// Categories for provider invalidation logic.
  bool get affectsSos =>
      type == 'SosAlert' || type == 'SosAlertResolved';
  bool get affectsTickets =>
      type == 'CriticalTicketPushed' || type == 'SupportTicketResolved';
  bool get affectsUsers =>
      type == 'UserRoleChanged' || type == 'UserStatusChanged';
  bool get affectsDrivers =>
      type == 'DriverKycRejected' || type == 'DriverApproved';
  bool get affectsVendors =>
      type == 'VendorApproved' || type == 'VendorRejected';
  bool get affectsRides =>
      type == 'RideStarted' ||
      type == 'RideCompleted' ||
      type == 'RideCancelled' ||
      type == 'DriverAssigned' ||
      type == 'RideAccepted';
  bool get affectsStats =>
      affectsSos || affectsTickets || affectsUsers || affectsDrivers ||
      affectsVendors || affectsRides;
}

class RefundTicketResult {
  RefundTicketResult({
    required this.success,
    required this.refundAmount,
    this.message,
  });

  factory RefundTicketResult.fromJson(Map<String, dynamic> json) =>
      RefundTicketResult(
        success: json['success'] as bool? ?? false,
        refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0,
        message: json['message'] as String?,
      );

  final bool success;
  final double refundAmount;
  final String? message;
}

// === Finance ===

/// Finance summary returned by GET /api/admin/finance/summary.
class AdminFinanceSummary {
  const AdminFinanceSummary({
    required this.gmv,
    required this.commissionRevenue,
    required this.driverPayoutsDue,
    required this.totalTransactions,
  });

  factory AdminFinanceSummary.fromJson(Map<String, dynamic> json) =>
      AdminFinanceSummary(
        gmv: (json['gmv'] as num?)?.toDouble() ?? 0,
        commissionRevenue: (json['commissionRevenue'] as num?)?.toDouble() ?? 0,
        driverPayoutsDue: (json['driverPayoutsDue'] as num?)?.toDouble() ?? 0,
        totalTransactions: json['totalTransactions'] as int? ?? 0,
      );

  final double gmv;
  final double commissionRevenue;
  final double driverPayoutsDue;
  final int totalTransactions;
}

/// Settlement log entry returned by GET /api/admin/finance/settlements.
class AdminSettlementLog {
  const AdminSettlementLog({
    required this.paymentId,
    required this.providerOrderId,
    required this.providerPaymentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.capturedAt,
  });

  factory AdminSettlementLog.fromJson(Map<String, dynamic> json) =>
      AdminSettlementLog(
        paymentId: json['paymentId'] as String? ?? '',
        providerOrderId: json['providerOrderId'] as String? ?? '',
        providerPaymentId: json['providerPaymentId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
        status: json['status'] as String? ?? '',
        capturedAt: json['capturedAt'] as String? ?? '',
      );

  final String paymentId;
  final String providerOrderId;
  final String providerPaymentId;
  final double amount;
  final String currency;
  final String status;
  final String capturedAt;
}
