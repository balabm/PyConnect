/// Fake implementations for PY Connect integration tests.
///
/// Provides fake ApiClient, auth controllers, driver API, vendor dashboard API,
/// and theme controller that return canned data without hitting the network
/// or native platform channels.
library fake_overrides;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pondyconnect/core/network/api_client.dart';
import 'package:pondyconnect/core/storage/token_storage.dart';
import 'package:pondyconnect/core/theme/theme_controller.dart';
import 'package:pondyconnect/features/auth/application/auth_controller.dart';
import 'package:pondyconnect/features/auth/application/vendor_auth_controller.dart';
import 'package:pondyconnect/features/driver/data/driver_api.dart';
import 'package:pondyconnect/features/driver/domain/driver_models.dart';
import 'package:pondyconnect/features/vendor/data/vendor_dashboard_api.dart';
import 'package:pondyconnect/features/vendor/application/vendor_providers.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fake ApiClient
// ─────────────────────────────────────────────────────────────────────────

/// A stub ApiClient that returns canned JSON data based on the request path.
/// Never hits the network — all responses are synchronous futures.
///
/// Set [throwOnNextPost] to true to simulate a network error on the next POST.
/// This is used by the Captain offline-queue test.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://test');

  /// When set, the next POST throws a [DioException] with type
  /// connectionError — simulating a network failure (SocketException).
  bool throwOnNextPost = false;

  /// When set, all POSTs throw a [DioException] with type connectionError.
  bool throwAllPosts = false;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _getResponse(path, queryParameters);
  }

  @override
  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? queryParameters}) async {
    if (throwOnNextPost) {
      throwOnNextPost = false;
      throw _networkError();
    }
    if (throwAllPosts) {
      throw _networkError();
    }
    return _postResponse(path, data);
  }

  @override
  Future<dynamic> put(String path, {Object? data}) async {
    return _getResponse(path, null);
  }

  @override
  Future<dynamic> delete(String path, {Object? data}) async {
    return <dynamic>[];
  }

  DioException _networkError() {
    return DioException(
      requestOptions: RequestOptions(path: 'http://test'),
      type: DioExceptionType.connectionError,
      error: SocketException('Network unreachable'),
      message: 'Connection error: socket',
    );
  }

  dynamic _getResponse(String path, Map<String, dynamic>? qp) {
    // Venues
    if (path == '/api/venues') return _venues;

    // Food menu
    if (path.contains('/menu')) return menuItems;

    // Food vendors
    if (path == '/api/vendors') {
      if (qp != null && qp['foodVendorsOnly'] == true) {
        return _foodVendors;
      }
      return _vendors;
    }

    // Driver profile
    if (path == '/api/driver/me') return _driverProfile;

    // Driver tasks
    if (path == '/api/driver/tasks') return _driverTasks;

    // Vendor dashboard
    if (path == '/api/vendor/dashboard') return _vendorDashboard;

    // Vendor menu
    if (path == '/api/food/vendor/menu') return menuItems;

    // Auth
    if (path == '/api/auth/me') return _authMe;

    return <dynamic>[];
  }

  dynamic _postResponse(String path, Object? data) {
    // Auth OTP request
    if (path == '/api/auth/otp/request') {
      return {'phone': '9000000099', 'otpExpirySeconds': 300};
    }

    // Auth OTP verify
    if (path == '/api/auth/otp/verify') {
      return _authMe;
    }

    // Food checkout
    if (path == '/api/food/orders/checkout' || path == '/api/orders/checkout') {
      return {
        'orderId': 'order-test-1',
        'vendorPayout': 250,
        'subTotal': 280,
        'deliveryFee': 40,
        'lateNightDriverBonus': 0,
        'platformFee': 2,
        'totalAmount': 322,
        'status': 'Placed',
      };
    }

    // Driver task accept
    if (path.contains('/accept')) {
      return _driverTasks.first;
    }

    // Vendor menu toggle
    if (path.contains('/toggle')) {
      return <dynamic>[];
    }

    // Vendor partial refund
    if (path.contains('/partial-refund')) {
      return {'message': 'Item removed', 'refundAmount': 120, 'newTotal': 160};
    }

    return <dynamic>[];
  }

  // ── Canned data ──

  static final List<Map<String, dynamic>> _venues = [
    {
      'id': 'venue-test-1',
      'name': 'Fuoco Pizzeria',
      'category': 'Pizzeria',
      'address': '12 Rue Romain Rolland',
      'rating': 4.5,
      'reviewCount': 127,
      'imageUrl': '',
      'maxCapacity': 60,
      'currentCapacity': 10,
      'description': 'Wood-fired pizzas',
      'latitude': 11.9362,
      'longitude': 79.8346,
    },
  ];

  static final List<Map<String, dynamic>> menuItems = [
    {
      'id': 'menu-item-1',
      'name': 'Margherita Pizza',
      'price': 280,
      'category': 'Pizza',
      'isAvailable': true,
      'isVeg': true,
      'description': 'Classic margherita',
      'imageUrl': '',
      'isLateNight': false,
      'prepTimeMinutes': 15,
    },
    {
      'id': 'menu-item-2',
      'name': 'Garlic Bread',
      'price': 120,
      'category': 'Sides',
      'isAvailable': true,
      'isVeg': true,
      'description': 'Garlic bread with herbs',
      'imageUrl': '',
      'isLateNight': false,
      'prepTimeMinutes': 10,
    },
  ];

  static final List<Map<String, dynamic>> _foodVendors = [
    {
      'id': '00000000-0000-0000-0000-000000000001',
      'name': 'Fuoco Pizzeria',
      'category': 'Pizzeria',
      'cuisineType': 'Italian',
      'rating': 4.5,
      'description': 'Wood-fired pizzas',
      'imageUrl': '',
      'isVerified': true,
    },
  ];

  static final List<Map<String, dynamic>> _vendors = _foodVendors;

  static final Map<String, dynamic> _driverProfile = {
    'id': 'driver-test-1',
    'name': 'Test Driver',
    'phone': '9000000050',
    'vehicleType': 'Bike',
    'vehiclePlate': 'PY-01-AB-1234',
    'isApproved': true,
    'isKycUploaded': true,
    'hasCompletedTutorial': true,
    'hasSignedAgreement': true,
    'isOnline': false,
  };

  static final List<Map<String, dynamic>> _driverTasks = [
    {
      'id': 'task-test-1',
      'taskType': 'FoodDelivery',
      'pickupAddress': 'Fuoco Pizzeria',
      'dropoffAddress': '12 Rue Romain Rolland',
      'driverEarnings': 40.0,
      'status': 'Assigned',
      'driverId': 'driver-test-1',
    },
  ];

  static final Map<String, dynamic> _vendorDashboard = {
    'todayOrders': 5,
    'todayRevenue': 1200,
    'pendingOrders': 2,
    'activeBookings': 1,
  };

  static final Map<String, dynamic> _authMe = {
    'accessToken': 'test-token',
    'userId': 'user-test-1',
    'name': 'Test User',
    'phone': '9000000099',
    'role': 'Tourist',
    'isProMember': false,
    'isVerifiedLocal': false,
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Fake Token Storage
// ─────────────────────────────────────────────────────────────────────────

/// A no-op token storage that returns a fixed token (or null) without
/// touching FlutterSecureStorage (which is unavailable in tests).
/// Reuses the existing FakeTokenStorage from test/helpers/.
class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage({this.initialToken}) : super();

  final String? initialToken;

  @override
  Future<String?> read() async => initialToken;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

// ─────────────────────────────────────────────────────────────────────────
// Fake Auth Controller (Consumer)
// ─────────────────────────────────────────────────────────────────────────

class FakeAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async {
    return AuthSession(
      name: 'Test User',
      phone: '9000000099',
      role: 'Tourist',
      token: 'test-token',
      isProMember: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Fake Vendor Auth Controller (Partner)
// ─────────────────────────────────────────────────────────────────────────

class FakeVendorAuthController extends VendorAuthController {
  FakeVendorAuthController(this._session);

  final VendorAuthSession _session;

  @override
  Future<VendorAuthSession?> build() async => _session;
}

// ─────────────────────────────────────────────────────────────────────────
// Fake Theme Controller
// ─────────────────────────────────────────────────────────────────────────

class FakeThemeController extends ThemeController {
  FakeThemeController() : super(_NullStorage());
}

class _NullStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) async {
    if (invocation.memberName == const Symbol('read')) return null;
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Fake Driver API
// ─────────────────────────────────────────────────────────────────────────

/// A fake DriverApi that returns canned data and can simulate network errors.
class FakeDriverApi extends DriverApi {
  FakeDriverApi(FakeApiClient client) : super(client);

  /// When true, the next call to markArrivedAtStore or markOutForDelivery
  /// throws a DioException with type connectionError.
  bool throwNetworkErrorOnNext = false;

  @override
  Future<void> markArrivedAtStore(String taskId) async {
    if (throwNetworkErrorOnNext) {
      throwNetworkErrorOnNext = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/api/driver/tasks/$taskId/arrived-at-store'),
        type: DioExceptionType.connectionError,
        error: SocketException('Network unreachable'),
        message: 'socket connection error',
      );
    }
  }

  @override
  Future<void> markOutForDelivery(String taskId) async {
    if (throwNetworkErrorOnNext) {
      throwNetworkErrorOnNext = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/api/driver/tasks/$taskId/out-for-delivery'),
        type: DioExceptionType.connectionError,
        error: SocketException('Network unreachable'),
        message: 'socket connection error',
      );
    }
  }

  @override
  Future<void> completeTask(String taskId) async {}

  @override
  Future<DriverProfileModel> getProfile() async {
    return DriverProfileModel(
      id: 'driver-test-1',
      name: 'Test Driver',
      phone: '9000000050',
      vehicleType: 'Bike',
      vehiclePlate: 'PY-01-AB-1234',
      isApproved: true,
      isKycUploaded: true,
      hasCompletedTutorial: true,
      hasSignedAgreement: true,
      isOnline: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Fake Vendor Dashboard API
// ─────────────────────────────────────────────────────────────────────────

class FakeVendorDashboardApi extends VendorDashboardApi {
  FakeVendorDashboardApi(FakeApiClient client) : super(client);

  @override
  Future<List<MenuItemModel>> getMenu() async {
    return [
      MenuItemModel(
        id: 'menu-item-1',
        name: 'Margherita Pizza',
        price: 280,
        category: 'Pizza',
        isAvailable: true,
        isVeg: true,
        description: 'Classic margherita',
        imageUrl: '',
        isLateNight: false,
        prepTimeMinutes: 15,
      ),
      MenuItemModel(
        id: 'menu-item-2',
        name: 'Garlic Bread',
        price: 120,
        category: 'Sides',
        isAvailable: true,
        isVeg: true,
        description: 'Garlic bread with herbs',
        imageUrl: '',
        isLateNight: false,
        prepTimeMinutes: 10,
      ),
    ];
  }

  @override
  Future<void> toggleMenuItem(String id) async {
    // No-op — the notifier handles the optimistic state update.
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Fake Vendor Menu Notifier
// ─────────────────────────────────────────────────────────────────────────

class FakeVendorMenuNotifier extends VendorMenuNotifier {
  FakeVendorMenuNotifier(Ref ref, this._client) : super(ref);

  final FakeApiClient _client;

  @override
  Future<void> load() async {
    final api = FakeVendorDashboardApi(_client);
    try {
      final items = await api.getMenu();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
