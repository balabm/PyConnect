import '../../../core/network/api_client.dart';

class RideHailingApi {
  RideHailingApi(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> requestRide(Map<String, dynamic> body) async {
    return await _api.post('/api/rides', data: body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptRide(String rideId) async {
    return await _api.post('/api/rides/$rideId/accept') as Map<String, dynamic>;
  }

  Future<void> startRide(String rideId) async {
    await _api.post('/api/rides/$rideId/start');
  }

  Future<void> arriveAtPickup(String rideId) async {
    await _api.post('/api/rides/$rideId/arrive');
  }

  Future<void> verifyOtpAndStart(String rideId, String otp) async {
    await _api.post('/api/rides/$rideId/verify-otp', data: {'otp': otp});
  }

  /// Testing helper: peeks the ride-start OTP from the backend.
  /// Returns null if peek is disabled (production) or no OTP has been set.
  Future<String?> peekRideOtp(String rideId) async {
    try {
      final body = await _api.get('/api/rides/$rideId/otp/peek');
      if (body is Map<String, dynamic>) {
        return body['otp'] as String?;
      }
    } catch (_) {
      // Silent — peek is a testing convenience
    }
    return null;
  }

  Future<void> completeWithMetrics(String rideId, double actualDistanceKm, int actualDurationMin) async {
    await _api.post('/api/rides/$rideId/complete-with-metrics', data: {
      'actualDistanceKm': actualDistanceKm,
      'actualDurationMin': actualDurationMin,
    });
  }

  Future<void> completeRide(String rideId) async {
    await _api.post('/api/rides/$rideId/complete');
  }

  Future<void> cancelRide(String rideId, {String? reason}) async {
    await _api.post('/api/rides/$rideId/cancel', data: {'reason': reason});
  }

  Future<Map<String, dynamic>> cancelByRider(String rideId, {String? reason, bool waiveFee = false}) async {
    return await _api.post('/api/rides/$rideId/cancel-by-rider', data: {
      'reason': reason,
      'waiveFee': waiveFee,
    }) as Map<String, dynamic>;
  }

  Future<void> cancelByDriver(String rideId, {String? reason}) async {
    await _api.post('/api/rides/$rideId/cancel-by-driver', data: {'reason': reason});
  }

  /// COD exact-change reconciliation. Debits the driver's ledger and credits
  /// the consumer's PY Wallet with the change amount.
  Future<Map<String, dynamic>> codReconcile(
    String rideId,
    double collectedAmount,
    double orderTotal,
  ) async {
    return await _api.post('/api/rides/$rideId/cod-reconcile', data: {
      'collectedAmount': collectedAmount,
      'orderTotal': orderTotal,
    }) as Map<String, dynamic>;
  }

  Future<void> rateRide(String rideId, int rating, {String? feedback, bool byDriver = false}) async {
    await _api.post('/api/rides/$rideId/rate', data: {
      'rating': rating,
      'feedback': feedback,
      'byDriver': byDriver,
    });
  }

  Future<Map<String, dynamic>> enableTripSharing(String rideId) async {
    return await _api.post('/api/rides/$rideId/share') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTripShare(String token) async {
    return await _api.get('/api/trip/$token') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> triggerSos(String rideId, double lat, double lng) async {
    return await _api.post('/api/rides/$rideId/sos', data: {'latitude': lat, 'longitude': lng}) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addEmergencyContact(String name, String phone, {String? relationship}) async {
    return await _api.post('/api/emergency-contacts', data: {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    }) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listEmergencyContacts() async {
    return await _api.get('/api/emergency-contacts') as List<dynamic>;
  }

  Future<Map<String, dynamic>> getRide(String rideId) async {
    return await _api.get('/api/rides/$rideId') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReceipt(String rideId) async {
    return await _api.get('/api/rides/$rideId/receipt') as Map<String, dynamic>;
  }

  Future<List<dynamic>> listRides({int page = 1, int pageSize = 20}) async {
    return await _api.get('/api/rides', queryParameters: {'page': page, 'pageSize': pageSize}) as List<dynamic>;
  }

  Future<List<dynamic>> nearbyDrivers(double lat, double lng, {double radius = 3.0}) async {
    return await _api.get('/api/rides/nearby-drivers', queryParameters: {'lat': lat, 'lng': lng, 'radius': radius}) as List<dynamic>;
  }

  Future<Map<String, dynamic>> registerDriver(Map<String, dynamic> body) async {
    return await _api.post('/api/driver/register', data: body) as Map<String, dynamic>;
  }

  Future<void> goOnline() async {
    await _api.post('/api/driver/online');
  }

  Future<void> goOffline() async {
    await _api.post('/api/driver/offline');
  }

  Future<void> updateLocation(double lat, double lng) async {
    await _api.post('/api/driver/location', data: {'latitude': lat, 'longitude': lng});
  }

  // === Saved Locations ===

  Future<List<dynamic>> listSavedLocations() async {
    return await _api.get('/api/saved-locations') as List<dynamic>;
  }

  Future<Map<String, dynamic>> addSavedLocation(String label, String address, double lat, double lng) async {
    return await _api.post('/api/saved-locations', data: {
      'label': label, 'address': address, 'latitude': lat, 'longitude': lng,
    }) as Map<String, dynamic>;
  }

  Future<void> updateSavedLocation(String id, String label, String address, double lat, double lng) async {
    await _api.put('/api/saved-locations/$id', data: {
      'label': label, 'address': address, 'latitude': lat, 'longitude': lng,
    });
  }

  Future<void> deleteSavedLocation(String id) async {
    await _api.delete('/api/saved-locations/$id');
  }

  // === Scheduled Rides ===

  Future<List<dynamic>> listScheduledRides() async {
    return await _api.get('/api/scheduled-rides') as List<dynamic>;
  }

  Future<Map<String, dynamic>> scheduleRide(Map<String, dynamic> body) async {
    return await _api.post('/api/scheduled-rides', data: body) as Map<String, dynamic>;
  }

  Future<void> cancelScheduledRide(String id) async {
    await _api.post('/api/scheduled-rides/$id/cancel');
  }

  // === Driver Earnings ===

  Future<Map<String, dynamic>> getDriverEarnings() async {
    return await _api.get('/api/driver/earnings') as Map<String, dynamic>;
  }

  // === Ride Events ===

  Future<List<dynamic>> getRideEvents(String rideId) async {
    return await _api.get('/api/rides/$rideId/events') as List<dynamic>;
  }

  // === Reassignment ===

  Future<void> reassignRide(String rideId) async {
    await _api.post('/api/rides/$rideId/reassign');
  }
}
