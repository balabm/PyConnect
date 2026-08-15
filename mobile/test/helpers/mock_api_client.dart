import 'package:pondyconnect/core/network/api_client.dart';

/// A stub ApiClient that returns canned JSON data based on the request path.
/// Never hits the network — all responses are synchronous futures.
///
/// Set [throwOnNext] to true to simulate an API error on the next request.
class MockApiClient extends ApiClient {
  MockApiClient() : super(baseUrl: 'http://test');

  /// When true, the next get/post/put throws an [ApiException].
  bool throwOnNext = false;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw ApiException('Mock error');
    }
    return _getResponse(path, queryParameters);
  }

  @override
  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? queryParameters}) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw ApiException('Mock error');
    }
    return _postResponse(path, data);
  }

  @override
  Future<dynamic> put(String path, {Object? data}) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw ApiException('Mock error');
    }
    return _getResponse(path, null);
  }

  dynamic _getResponse(String path, Map<String, dynamic>? qp) {
    // Venues
    if (path == '/api/venues') return _venues;
    if (path.startsWith('/api/venues/') && path.length > '/api/venues/'.length + 10) {
      return _venues.first;
    }

    // Food menu
    if (path.contains('/menu')) return _menuItems;

    // Food orders
    if (path == '/api/orders') return <dynamic>[];

    // Essentials
    if (path == '/api/essentials') {
      if (qp != null && qp['category'] != null) {
        return _products.where((p) => p['category'] == qp['category']).toList();
      }
      if (qp != null && qp['lateNight'] == true) {
        return _products.where((p) => p['isLateNightEssential'] == true).toList();
      }
      return _products;
    }
    if (path.startsWith('/api/essentials/') && !path.contains('orders') && !path.contains('suggestions')) {
      return _products.first;
    }
    if (path == '/api/essentials/orders') return <dynamic>[];

    // Rides
    if (path == '/api/rides/nearby-drivers') return _nearbyDrivers;
    if (path == '/api/rides' && qp == null) return <dynamic>[];

    // Transit
    if (path == '/api/transit/hubs') return _transitHubs;
    if (path == '/api/transit/trips') return <dynamic>[];

    // Luggage
    if (path == '/api/luggage/drop-offs') return <dynamic>[];

    // Rental
    if (path == '/api/rental/scooters') return <dynamic>[];

    // Vendors
    if (path == '/api/vendors') {
      if (qp != null && qp['foodVendorsOnly'] == true) {
        return _foodVendors;
      }
      if (qp != null && qp['category'] != null) {
        return _vendors.where((v) => v['category'] == qp['category']).toList();
      }
      return _vendors;
    }

    // Flash promos
    if (path == '/api/flash-promos') return _flashPromos;

    // Service area
    if (path == '/api/service-area') return _serviceArea;

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
    if (path == '/api/orders/checkout') {
      return {
        'orderId': 'order-test-1',
        'vendorPayout': 250,
        'subTotal': 250,
        'deliveryFee': 40,
        'lateNightDriverBonus': 0,
        'platformFee': 0,
        'totalAmount': 290,
        'status': 'Placed',
      };
    }

    // Ride request
    if (path == '/api/rides') {
      return {
        'rideId': 'ride-test-1',
        'fare': 12,
        'platformBookingFee': 15,
        'totalAmount': 27,
        'distanceKm': 1.5,
        'estimatedDurationMin': 8,
        'status': 'Requested',
      };
    }

    // Essentials order
    if (path == '/api/essentials/orders') {
      return {
        'orderId': 'ess-order-1',
        'subTotal': 60,
        'deliveryFee': 40,
        'totalAmount': 100,
        'status': 'Placed',
      };
    }

    // Essentials suggestions
    if (path == '/api/essentials/suggestions') {
      return [
        {'id': 'prod-sugg-1', 'name': 'Lighter', 'price': 20, 'category': 'SmokingAccessories'}
      ];
    }

    // Transit trip
    if (path == '/api/transit/trips') {
      return _transitTrips.first;
    }

    // Luggage drop-off
    if (path == '/api/luggage/drop-offs') {
      return _luggageDropOffs.first;
    }

    // Rental
    if (path == '/api/rental/scooters') {
      return _rentals.first;
    }

    return <dynamic>{};
  }

  // --- Mock data ---

  static final List<Map<String, dynamic>> _venues = [
    {
      'id': 'ven-1',
      'name': 'Bon Appétit',
      'category': 'Cafe',
      'latitude': 11.93,
      'longitude': 79.83,
      'occupancy': 50,
      'isOpen': true,
      'maxCapacity': 100,
      'address': '12 Rue Romain Rolland',
    },
    {
      'id': 'ven-2',
      'name': 'The Lighthouse Bar',
      'category': 'Bar',
      'latitude': 11.94,
      'longitude': 79.84,
      'occupancy': 80,
      'isOpen': true,
      'maxCapacity': 100,
      'address': '5 Rue Suffren',
    },
    {
      'id': 'ven-3',
      'name': 'Surf Café',
      'category': 'Cafe',
      'latitude': 11.95,
      'longitude': 79.85,
      'occupancy': 20,
      'isOpen': true,
      'maxCapacity': 80,
      'address': '8 Bussy Street',
    },
  ];

  static final List<Map<String, dynamic>> _menuItems = [
    {
      'id': 'item-1',
      'name': 'Margherita',
      'description': 'Classic pizza with basil',
      'price': 250,
      'category': 'Pizza',
      'isAvailable': true,
      'isLateNight': false,
    },
    {
      'id': 'item-2',
      'name': 'Pepperoni',
      'description': 'Spicy pepperoni pizza',
      'price': 320,
      'category': 'Pizza',
      'isAvailable': true,
      'isLateNight': false,
    },
    {
      'id': 'item-3',
      'name': 'Tiramisu',
      'description': 'Classic Italian dessert',
      'price': 180,
      'category': 'Dessert',
      'isAvailable': true,
      'isLateNight': true,
    },
  ];

  static final List<Map<String, dynamic>> _products = [
    {
      'id': 'prod-1',
      'name': 'ORS Sachet',
      'description': 'Hydration recovery',
      'price': 30,
      'category': 'HydrationRecovery',
      'isLateNightEssential': true,
      'stockCount': 50,
      'brand': 'Electral',
    },
    {
      'id': 'prod-2',
      'name': 'Coconut Water',
      'description': 'Fresh coconut water',
      'price': 50,
      'category': 'HydrationRecovery',
      'isLateNightEssential': false,
      'stockCount': 20,
      'brand': 'Tender',
    },
    {
      'id': 'prod-3',
      'name': 'Raw Classic Papers',
      'description': 'Rolling papers',
      'price': 100,
      'category': 'SmokingAccessories',
      'isLateNightEssential': true,
      'stockCount': 30,
      'brand': 'Raw',
    },
    {
      'id': 'prod-4',
      'name': 'Sunscreen SPF50',
      'description': 'Beach sunscreen',
      'price': 200,
      'category': 'BeachEssentials',
      'isLateNightEssential': false,
      'stockCount': 15,
      'brand': 'Neutrogena',
    },
  ];

  static final List<Map<String, dynamic>> _nearbyDrivers = [
    {'id': 'drv-1', 'name': 'Ravi', 'vehicleType': 'Bike', 'rating': 4.8, 'totalRides': 120},
    {'id': 'drv-2', 'name': 'Suresh', 'vehicleType': 'Auto', 'rating': 4.5, 'totalRides': 85},
  ];

  static final List<Map<String, dynamic>> _flashPromos = [
    {
      'id': 'promo-1',
      'title': 'Flash Sale at Bon Appétit',
      'discountPercentage': 20,
      'expiryTime': '2026-12-31T23:59:59Z',
      'venueName': 'Bon Appétit',
    },
  ];

  static final Map<String, dynamic> _serviceArea = {
    'centerLatitude': 11.9356,
    'centerLongitude': 79.8301,
    'radiusKm': 3.0,
  };

  static final Map<String, dynamic> _authMe = {
    'accessToken': 'test-token',
    'userId': 'user-test-1',
    'name': 'Test User',
    'phone': '9000000099',
    'role': 'Tourist',
    'isProMember': false,
  };

  static final List<Map<String, dynamic>> _vendors = [
    {
      'id': 'vendor-luggage-1',
      'name': 'Rock Beach Luggage',
      'category': 'LuggageCloak',
      'contactPhone': '9000000001',
    },
  ];

  static final List<Map<String, dynamic>> _foodVendors = [
    {
      'id': '00000000-0000-0000-0000-000000000001',
      'name': 'Fuoco Pizzeria',
      'category': 'Restaurant',
      'cuisineType': 'Italian',
      'rating': 4.5,
      'description': 'Wood-fired artisanal pizzeria in White Town.',
      'deliveryFee': 40,
      'prepTimeMinutes': 25,
      'menuItemCount': 8,
    },
    {
      'id': '00000000-0000-0000-0000-000000000002',
      'name': 'Satsanga Garden Kitchen',
      'category': 'Restaurant',
      'cuisineType': 'Indian',
      'rating': 4.2,
      'description': 'Multi-cuisine garden restaurant.',
      'deliveryFee': 30,
      'prepTimeMinutes': 20,
      'menuItemCount': 5,
    },
    {
      'id': '00000000-0000-0000-0000-000000000005',
      'name': 'Café des Arts',
      'category': 'Cafe',
      'cuisineType': 'Cafe',
      'rating': 4.4,
      'description': 'AC cafe with gallery space.',
      'deliveryFee': 25,
      'prepTimeMinutes': 15,
      'menuItemCount': 5,
    },
  ];

  static final List<Map<String, dynamic>> _transitHubs = [
    {
      'id': 'hub-1',
      'name': 'Pondicherry Bus Stand',
      'kind': 'BusStand',
      'latitude': 11.93,
      'longitude': 79.83,
      'address': 'Maraimalai Adigal Salai',
    },
    {
      'id': 'hub-2',
      'name': 'Pondicherry Airport',
      'kind': 'Airport',
      'latitude': 11.97,
      'longitude': 79.81,
      'address': 'Lawspet',
    },
  ];

  static final List<Map<String, dynamic>> _transitTrips = [
    {
      'id': 'trip-1',
      'hubName': 'Pondicherry Bus Stand',
      'arrivalFrom': 'Chennai',
      'arrivalMode': 'Bus',
      'arrivalAt': '2026-08-15T10:00:00Z',
      'partySize': 2,
      'dropOffLocation': 'White Town',
      'status': 'Requested',
      'price': 250,
      'paymentStatus': 'Pending',
    },
  ];

  static final List<Map<String, dynamic>> _luggageDropOffs = [
    {
      'id': 'lug-1',
      'vendorName': 'Rock Beach Luggage',
      'scheduledFor': '2026-08-15T10:00:00Z',
      'droppedAt': '2026-08-15T10:00:00Z',
      'bagCount': 2,
      'ratePerHour': 60,
      'totalAmount': 480,
      'status': 'Dropped',
      'paymentStatus': 'Captured',
    },
  ];

  static final List<Map<String, dynamic>> _rentals = [
    {
      'id': 'rental-1',
      'vendorName': 'Promotion Beach Riders',
      'vehicleName': 'Honda Activa',
      'vehiclePlate': 'PY01 1234',
      'rentalStart': '2026-08-15T10:00:00Z',
      'rentalEnd': '2026-08-15T14:00:00Z',
      'ratePerHour': 140,
      'totalAmount': 560,
      'status': 'Active',
      'paymentStatus': 'Captured',
    },
  ];
}
