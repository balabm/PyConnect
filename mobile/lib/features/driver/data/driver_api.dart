import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/network/api_client.dart';
import '../domain/driver_models.dart';

class DriverApi {
  DriverApi(this._api);

  final ApiClient _api;

  Future<List<DispatchTaskModel>> getAvailableTasks() async {
    final data = await _api.get('api/driver/tasks');
    final list = data as List;
    return list
        .map((e) => DispatchTaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DispatchTaskModel>> getBatchedTasks(String batchGroupId) async {
    final data = await _api.get('api/driver/tasks/batch/$batchGroupId');
    final list = data as List;
    return list
        .map((e) => DispatchTaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DispatchTaskModel> acceptTask(String taskId) async {
    final data = await _api.post('api/driver/tasks/$taskId/accept');
    return DispatchTaskModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> completeTask(String taskId) async {
    await _api.post('api/driver/tasks/$taskId/complete');
  }

  /// Emergency release: unassigns the driver from the task and pushes it
  /// back to the dispatch queue for the next nearest driver. Used when the
  /// driver has a breakdown or emergency and cannot complete the trip.
  Future<void> emergencyRelease(String taskId) async {
    await _api.post('api/driver/tasks/$taskId/emergency-release');
  }

  /// Marks the driver as arrived at the store/restaurant for a food or
  /// essentials delivery. Persists the phase for app-restart resume.
  Future<void> markArrivedAtStore(String taskId) async {
    await _api.post('api/driver/tasks/$taskId/arrived-at-store');
  }

  /// Marks the order as picked up and the driver as en route to customer.
  /// Persists the phase for app-restart resume.
  Future<void> markOutForDelivery(String taskId) async {
    await _api.post('api/driver/tasks/$taskId/out-for-delivery');
  }

  Future<DriverWalletModel> getWallet() async {
    final data = await _api.get('api/driver/wallet');
    return DriverWalletModel.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches the cash-collection ledger wallet (balance, suspended status,
  /// recent transactions) from GET /api/driver/wallet.
  Future<DriverWalletDetailModel> getWalletDetail() async {
    final data = await _api.get('api/driver/wallet');
    return DriverWalletDetailModel.fromJson(data as Map<String, dynamic>);
  }

  /// Initiates a Razorpay top-up order for settling wallet dues via
  /// POST /api/driver/wallet/topup. Returns the provider order ID.
  Future<WalletTopUpOrderModel> initiateTopUp(double amount) async {
    final data = await _api.post('api/driver/wallet/topup', data: {
      'amount': amount,
    });
    return WalletTopUpOrderModel.fromJson(data as Map<String, dynamic>);
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
      await _api.post('api/driver/wallet/topup/verify', data: {
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
    final data = await _api.post('api/driver/wallet/instant-payout');
    return InstantPayoutResultModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> goOnline() async {
    await _api.post('api/driver/online');
  }

  /// Fetches the current driver's profile including approval, tutorial and
  /// signature status. Used for router guards and SignalR channel join.
  Future<DriverProfileModel> getProfile() async {
    final data = await _api.get('api/driver/me');
    return DriverProfileModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> goOffline() async {
    await _api.post('api/driver/offline');
  }

  /// Updates the driver's current GPS location on the backend.
  /// Called periodically while the driver is online for dispatch matching.
  Future<void> updateLocation(double latitude, double longitude) async {
    await _api.post('api/driver/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
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
    final data = await _api.post('api/driver/upload-kyc', data: formData);
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
    await _api.post('api/driver/register', data: {
      'name': name,
      'phone': phone,
      'vehicleType': vehicleType,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
    });
  }

  /// Marks the mandatory safety tutorial as completed.
  Future<void> completeTutorial() async {
    await _api.post('api/driver/complete-tutorial');
  }

  /// Records the driver's digital signature on the safety agreement.
  Future<void> signAgreement() async {
    await _api.post('api/driver/sign-agreement');
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
    await _api.post('api/driver/upload-extended-kyc', data: formData);
  }
}
