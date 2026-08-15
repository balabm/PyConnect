import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/network/api_client.dart';

/// API client for partner/vendor self-onboarding flows.
///
/// The registration endpoint is anonymous (no JWT required) because the
/// vendor doesn't exist yet. KYC upload is also anonymous but requires the
/// vendorId returned from registration. Operating hours update requires
/// vendor authentication.
class VendorOnboardingApi {
  VendorOnboardingApi(this._api);

  final ApiClient _api;

  /// Self-registers a new vendor. Creates a pending vendor record that
  /// the admin must approve before the partner can log in.
  Future<VendorRegistrationResult> registerVendor({
    required String businessName,
    required String category,
    required String contactPhone,
    String? description,
    String? address,
  }) async {
    final data = await _api.post('/api/vendor/register', data: {
      'businessName': businessName,
      'category': category,
      'contactPhone': contactPhone,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
    });
    return VendorRegistrationResult.fromJson(data as Map<String, dynamic>);
  }

  /// Uploads KYC documents (FSSAI, GST, PAN) for a self-registered vendor.
  /// Uses multipart form data. Files are optional but at least one
  /// identification number should be provided.
  Future<VendorKycResult> uploadKyc({
    required String vendorId,
    String? fssaiNumber,
    String? gstNumber,
    String? panNumber,
    File? fssaiDoc,
    File? gstDoc,
    File? panDoc,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankAccountName,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('KYC upload is not supported on web');
    }

    final formDataMap = <String, dynamic>{
      if (fssaiNumber != null) 'FssaiNumber': fssaiNumber,
      if (gstNumber != null) 'GstNumber': gstNumber,
      if (panNumber != null) 'PanNumber': panNumber,
      if (bankAccountNumber != null) 'BankAccountNumber': bankAccountNumber,
      if (bankIfsc != null) 'BankIfsc': bankIfsc,
      if (bankAccountName != null) 'BankAccountName': bankAccountName,
    };

    if (fssaiDoc != null) {
      formDataMap['FssaiDoc'] = await MultipartFile.fromFile(
        fssaiDoc.path,
        filename: 'fssai${_ext(fssaiDoc.path)}',
      );
    }
    if (gstDoc != null) {
      formDataMap['GstDoc'] = await MultipartFile.fromFile(
        gstDoc.path,
        filename: 'gst${_ext(gstDoc.path)}',
      );
    }
    if (panDoc != null) {
      formDataMap['PanDoc'] = await MultipartFile.fromFile(
        panDoc.path,
        filename: 'pan${_ext(panDoc.path)}',
      );
    }

    final formData = FormData.fromMap(formDataMap);
    final data = await _api.post('/api/vendor/$vendorId/kyc', data: formData);
    return VendorKycResult.fromJson(data as Map<String, dynamic>);
  }

  /// Updates operating hours for a vendor. [hoursJson] should be a JSON
  /// string keyed by day abbreviation, e.g.:
  /// {"mon":{"open":"09:00","close":"22:00","closed":false}, ...}
  Future<void> updateOperatingHours({
    required String vendorId,
    required String hoursJson,
  }) async {
    await _api.put('/api/vendor/$vendorId/operating-hours', data: {
      'hoursJson': hoursJson,
    });
  }

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot) : '.jpg';
  }
}

class VendorRegistrationResult {
  VendorRegistrationResult({required this.vendorId, required this.status});

  factory VendorRegistrationResult.fromJson(Map<String, dynamic> json) =>
      VendorRegistrationResult(
        vendorId: json['vendorId'] as String? ?? '',
        status: json['status'] as String? ?? 'Pending',
      );

  final String vendorId;
  final String status;
}

class VendorKycResult {
  VendorKycResult({required this.vendorId, required this.isKycSubmitted});

  factory VendorKycResult.fromJson(Map<String, dynamic> json) =>
      VendorKycResult(
        vendorId: json['vendorId'] as String? ?? '',
        isKycSubmitted: json['isKycSubmitted'] as bool? ?? false,
      );

  final String vendorId;
  final bool isKycSubmitted;
}
