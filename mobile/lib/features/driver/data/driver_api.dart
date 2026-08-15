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

  Future<DispatchTaskModel> acceptTask(String taskId) async {
    final data = await _api.post('api/driver/tasks/$taskId/accept');
    return DispatchTaskModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> completeTask(String taskId) async {
    await _api.post('api/driver/tasks/$taskId/complete');
  }

  Future<DriverWalletModel> getWallet() async {
    final data = await _api.get('api/driver/wallet');
    return DriverWalletModel.fromJson(data as Map<String, dynamic>);
  }

  Future<InstantPayoutResultModel> requestInstantPayout() async {
    final data = await _api.post('api/driver/wallet/instant-payout');
    return InstantPayoutResultModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> goOnline() async {
    await _api.post('api/driver/online');
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
