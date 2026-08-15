import '../../../core/network/api_client.dart';

/// Client for the /api/vendor/auth endpoints.
/// Used by the partner/vendor app to authenticate with vendor-scoped JWTs.
class VendorAuthApi {
  VendorAuthApi(this._api);

  final ApiClient _api;

  /// Request an OTP for a vendor phone number.
  Future<VendorOtpResult> requestOtp(String phone) async {
    final body = await _api.post('/api/vendor/auth/otp/request', data: {
      'phone': phone,
    });
    return VendorOtpResult.fromJson(body as Map<String, dynamic>);
  }

  /// Verify the OTP and get a vendor JWT.
  Future<VendorLoginResult> verifyOtp(String phone, String otpCode) async {
    final body = await _api.post('/api/vendor/auth/otp/verify', data: {
      'phone': phone,
      'otpCode': otpCode,
    });
    return VendorLoginResult.fromJson(body as Map<String, dynamic>);
  }

  /// Testing-only: peek the most recently issued vendor OTP for [phone].
  /// Returns null when peek is disabled (production with real SMS).
  Future<String?> peekOtp(String phone) async {
    try {
      final body = await _api.get('/api/vendor/auth/otp/peek?phone=$phone');
      return (body as Map<String, dynamic>)['code'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class VendorOtpResult {
  VendorOtpResult({required this.phone, required this.otpExpirySeconds});

  factory VendorOtpResult.fromJson(Map<String, dynamic> json) => VendorOtpResult(
        phone: json['phone'] as String? ?? '',
        otpExpirySeconds: (json['otpExpirySeconds'] as num?)?.toInt() ?? 300,
      );

  final String phone;
  final int otpExpirySeconds;
}

class VendorLoginResult {
  VendorLoginResult({
    required this.accessToken,
    required this.vendorId,
    required this.vendorName,
    required this.category,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.status,
    this.rejectionReason,
  });

  factory VendorLoginResult.fromJson(Map<String, dynamic> json) =>
      VendorLoginResult(
        accessToken: json['accessToken'] as String? ?? '',
        vendorId: json['vendorId'] as String? ?? '',
        vendorName: json['vendorName'] as String? ?? '',
        category: json['category'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'Pending',
        rejectionReason: json['rejectionReason'] as String?,
      );

  final String accessToken;
  final String vendorId;
  final String vendorName;
  final String category;
  final String userId;
  final String userName;
  final String phone;
  final String status;
  final String? rejectionReason;
}
