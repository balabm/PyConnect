import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

import '../../../core/network/api_client.dart';
import '../domain/driver_models.dart';

class DriverApi {
  DriverApi(this._api);

  final ApiClient _api;

  Future<List<DispatchTaskModel>> getAvailableTasks() async {
    final data = await _api.get('/api/driver/tasks');
    final list = data as List;
    return list
        .map((e) => DispatchTaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DispatchTaskModel>> getBatchedTasks(String batchGroupId) async {
    final data = await _api.get('/api/driver/tasks/batch/$batchGroupId');
    final list = data as List;
    return list
        .map((e) => DispatchTaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Verifies the 4-digit OTP and starts the ride for a dispatch task.
  /// Called when the driver taps [Start Trip] after arriving at the pickup.
  Future<void> startTask(String taskId, String otp) async {
    await _api.post('/api/driver/tasks/$taskId/start', data: {'otp': otp});
  }

  Future<DispatchTaskModel> acceptTask(String taskId) async {
    final data = await _api.post('/api/driver/tasks/$taskId/accept');
    return DispatchTaskModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> completeTask(String taskId) async {
    await _api.post('/api/driver/tasks/$taskId/complete');
  }

  /// Completes a high-value task (≥ ₹1000) with a completion OTP collected
  /// from the customer at drop-off. The backend verifies the OTP before
  /// marking the ride/delivery as completed.
  Future<void> completeTaskWithOtp(String taskId, String otp) async {
    await _api.post('/api/driver/tasks/$taskId/complete', data: {'otp': otp});
  }

  /// Triggers an SOS alert for the specified ride. Sends the driver's GPS
  /// coordinates to the backend, which pushes a high-priority alert to the
  /// admin panel and notifies the fleet manager.
  Future<void> triggerSos(String rideId, double latitude, double longitude) async {
    await _api.post('/api/rides/$rideId/sos', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Fetches the current surge zones for the driver heatmap. Each zone
  /// includes the geographic center, demand/supply ratio, surge level,
  /// and bonus amount.
  Future<List<Map<String, dynamic>>> getSurgeZones() async {
    final data = await _api.get('/api/heatmap/surge-zones');
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ── Module 6: Garage ──

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final data = await _api.get('/api/driver/vehicles');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addVehicle({
    required String vehicleType,
    required String registrationNumber,
    String? color,
    String? model,
  }) async {
    return await _api.post('/api/driver/vehicles', data: {
      'vehicleType': vehicleType,
      'registrationNumber': registrationNumber,
      if (color != null) 'color': color,
      if (model != null) 'model': model,
    }) as Map<String, dynamic>;
  }

  Future<void> activateVehicle(String vehicleId) async {
    await _api.post('/api/driver/vehicles/$vehicleId/activate');
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _api.delete('/api/driver/vehicles/$vehicleId');
  }

  Future<Map<String, dynamic>> getComplianceStatus() async {
    return await _api.get('/api/driver/compliance') as Map<String, dynamic>;
  }

  // ── Module 8: Preferences ──

  Future<Map<String, dynamic>> getPreferences() async {
    return await _api.get('/api/driver/preferences') as Map<String, dynamic>;
  }

  Future<void> setDestination(double latitude, double longitude, String? label) async {
    await _api.put('/api/driver/preferences/destination', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (label != null) 'label': label,
    });
  }

  Future<void> clearDestination() async {
    await _api.delete('/api/driver/preferences/destination');
  }

  Future<void> updateServiceToggles({
    bool? foodDelivery,
    bool? rides,
    bool? intercity,
    bool? luggage,
    bool? essentials,
  }) async {
    await _api.put('/api/driver/preferences/service-toggles', data: {
      if (foodDelivery != null) 'foodDelivery': foodDelivery,
      if (rides != null) 'rides': rides,
      if (intercity != null) 'intercity': intercity,
      if (luggage != null) 'luggage': luggage,
      if (essentials != null) 'essentials': essentials,
    });
  }

  // ── Module 9: Communication ──

  Future<Map<String, dynamic>> initiateCall(String rideId) async {
    return await _api.post('/api/driver/communications/call', data: {
      'rideId': rideId,
    }) as Map<String, dynamic>;
  }

  Future<void> sendQuickMessage(String rideId, String message) async {
    await _api.post('/api/driver/communications/quick-message', data: {
      'rideId': rideId,
      'message': message,
    });
  }

  /// Emergency release: unassigns the driver from the task and pushes it
  /// back to the dispatch queue for the next nearest driver. Used when the
  /// driver has a breakdown or emergency and cannot complete the trip.
  Future<void> emergencyRelease(String taskId) async {
    await _api.post('/api/driver/tasks/$taskId/emergency-release');
  }

  /// Marks the driver as arrived at the store/restaurant for a food or
  /// essentials delivery. Persists the phase for app-restart resume.
  Future<void> markArrivedAtStore(String taskId) async {
    await _api.post('/api/driver/tasks/$taskId/arrived-at-store');
  }

  /// Marks the order as picked up and the driver as en route to customer.
  /// Persists the phase for app-restart resume.
  Future<void> markOutForDelivery(String taskId) async {
    await _api.post('/api/driver/tasks/$taskId/out-for-delivery');
  }

  /// Uploads a proof-of-delivery photo for a food/essentials order.
  /// Called by the Captain when tapping "Delivered" — they snap a photo
  /// of the bag at the door. The photo is uploaded and attached to the
  /// order record to eliminate "I never got my food" disputes.
  Future<String?> uploadDeliveryProof(String orderId, File photo) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photo.path),
      });
      final response = await _api.post(
        '/api/driver/orders/$orderId/delivery-proof',
        data: formData,
      );
      return (response as Map<String, dynamic>?)?['proofUrl'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<DriverWalletModel> getWallet() async {
    final data = await _api.get('/api/driver/wallet');
    return DriverWalletModel.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches the cash-collection ledger wallet (balance, suspended status,
  /// recent transactions) from GET /api/driver/wallet.
  Future<DriverWalletDetailModel> getWalletDetail() async {
    final data = await _api.get('/api/driver/wallet');
    return DriverWalletDetailModel.fromJson(data as Map<String, dynamic>);
  }

  /// Initiates a Razorpay top-up order for settling wallet dues via
  /// POST /api/driver/wallet/topup. Returns the provider order ID.
  Future<WalletTopUpOrderModel> initiateTopUp(double amount) async {
    final data = await _api.post('/api/driver/wallet/topup', data: {
      'amount': amount,
    });
    return WalletTopUpOrderModel.fromJson(data as Map<String, dynamic>);
  }

  /// Requests a wallet withdrawal to the driver's linked UPI/bank.
  Future<DriverWithdrawalModel> requestWithdrawal(double amount) async {
    final data = await _api.post('/api/driver/wallet/withdraw', data: {
      'amount': amount,
    });
    return DriverWithdrawalModel.fromJson(data as Map<String, dynamic>);
  }

  /// Returns the driver's withdrawal history.
  Future<List<DriverWithdrawalModel>> getWithdrawals() async {
    final data = await _api.get('/api/driver/wallet/withdrawals');
    final list = data as List;
    return list
        .map((e) => DriverWithdrawalModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Verifies a Razorpay payment and credits the wallet via
  /// POST /api/driver/wallet/topup/verify. Returns true on success.
  Future<bool> verifyTopUp({
    required double amount,
    required String paymentId,
    required String orderId,
    String? signature,
  }) async {
    try {
      await _api.post('/api/driver/wallet/topup/verify', data: {
        'amount': amount,
        'razorpayPaymentId': paymentId,
        'razorpayOrderId': orderId,
        if (signature != null) 'razorpaySignature': signature,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<InstantPayoutResultModel> requestInstantPayout() async {
    final data = await _api.post('/api/driver/wallet/instant-payout');
    return InstantPayoutResultModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> goOnline() async {
    await _api.post('/api/driver/online');
  }

  /// Fetches the current driver's profile including approval, tutorial and
  /// signature status. Used for router guards and SignalR channel join.
  Future<DriverProfileModel> getProfile() async {
    final data = await _api.get('/api/driver/me');
    if (kDebugMode) {
      print('DEBUG DriverProfile: $data');
    }
    return DriverProfileModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> goOffline() async {
    await _api.post('/api/driver/offline');
  }

  /// Updates the driver's current GPS location on the backend.
  /// Called periodically while the driver is online for dispatch matching.
  Future<void> updateLocation(double latitude, double longitude) async {
    await _api.post('/api/driver/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Logs a mock/fake GPS location detection anomaly to the backend.
  /// The driver is flagged for review and forced offline server-side.
  Future<void> reportMockLocation(double latitude, double longitude) async {
    try {
      await _api.post('/api/driver/mock-location-report', data: {
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (_) {
      // Best-effort — the anomaly is handled client-side regardless.
    }
  }

  /// Deletes the driver's account, shreds all KYC documents from S3, and
  /// anonymizes all PII. Called by the Captain app's "Delete Account & Data"
  /// flow. After this call, the token is invalid and the driver must sign
  /// out locally.
  Future<void> deleteAccount() async {
    await _api.post('/api/driver/account/delete');
  }

  /// Uploads all three KYC documents (Aadhaar, Driving License, RC) in a
  /// single multipart request. The backend routes these to the private
  /// storage bucket so they are never publicly accessible.
  ///
  /// [aadhaar], [drivingLicense], and [rc] must be [File] objects pointing
  /// to captured/selected images.
  ///
  /// Throws [UnsupportedError] on web. Throws [ApiException] on network or
  /// server errors. Throws [AuthRequiredException] if the token expired.
  Future<KycUploadResult> uploadKyc({
    required File aadhaar,
    required File drivingLicense,
    required File rc,
    required String upiId,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('KYC upload is not supported on web');
    }

    final formData = FormData.fromMap({
      'aadhaar': await MultipartFile.fromFile(aadhaar.path,
          filename: 'aadhaar${_ext(aadhaar.path)}'),
      'drivingLicense': await MultipartFile.fromFile(drivingLicense.path,
          filename: 'dl${_ext(drivingLicense.path)}'),
      'rc': await MultipartFile.fromFile(rc.path,
          filename: 'rc${_ext(rc.path)}'),
      'upiId': upiId,
    });
    final data = await _api.post('/api/driver/upload-kyc', data: formData);
    return KycUploadResult.fromJson(data as Map<String, dynamic>);
  }

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot) : '.jpg';
  }

  /// Registers a new driver profile. Creates a pending driver record.
  Future<void> registerDriver({
    required String name,
    required String phone,
    required String vehicleType,
    String? vehiclePlate,
    String? licenseNumber,
  }) async {
    await _api.post('/api/driver/register', data: {
      'name': name,
      'phone': phone,
      'vehicleType': vehicleType,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
    });
  }

  /// Marks the mandatory safety tutorial as completed.
  Future<void> completeTutorial() async {
    await _api.post('/api/driver/complete-tutorial');
  }

  /// Records the driver's digital signature on the safety agreement.
  Future<void> signAgreement() async {
    await _api.post('/api/driver/sign-agreement');
  }

  /// Uploads extended KYC documents (insurance + selfie).
  Future<void> uploadExtendedKyc({
    File? insurance,
    File? selfie,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('KYC upload is not supported on web');
    }

    final formDataMap = <String, dynamic>{};
    if (insurance != null) {
      formDataMap['insurance'] = await MultipartFile.fromFile(
        insurance.path,
        filename: 'insurance${_ext(insurance.path)}',
      );
    }
    if (selfie != null) {
      formDataMap['selfie'] = await MultipartFile.fromFile(
        selfie.path,
        filename: 'selfie${_ext(selfie.path)}',
      );
    }

    final formData = FormData.fromMap(formDataMap);
    await _api.post('/api/driver/upload-extended-kyc', data: formData);
  }
}
