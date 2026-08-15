import '../../../core/network/api_client.dart';

/// Client for the /api/auth endpoints. Mirrors the backend DTOs.
class AuthApi {
  AuthApi(this._api);

  final ApiClient _api;

  Future<OtpRequestedResult> requestOtp(String phone) async {
    final body = await _api.post('/api/auth/otp/request', data: {
      'phone': phone,
    });
    return OtpRequestedResult.fromJson(body as Map<String, dynamic>);
  }

  Future<AuthResult> verifyOtp(String phone, String otp, {String? name}) async {
    final body = await _api.post('/api/auth/otp/verify', data: {
      'phone': phone,
      'otp': otp,
      'name': name,
    });
    return AuthResult.fromJson(body as Map<String, dynamic>);
  }

  Future<AuthResult> me() async {
    final body = await _api.get('/api/auth/me');
    return AuthResult.fromJson(body as Map<String, dynamic>);
  }

  /// Sends a Google idToken to the backend and returns a PondyConnect JWT.
  /// [phone] is optional; the backend will ask for it if this is a new account.
  Future<SocialAuthResult> signInWithGoogle(
    String idToken, {
    String? phone,
  }) async {
    final body = await _api.post('/api/auth/social/google', data: {
      'idToken': idToken,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return SocialAuthResult.fromJson(body as Map<String, dynamic>);
  }

  /// Links the currently authenticated user to a Google account.
  /// Requires a valid bearer token to identify the phone-verified user.
  Future<SocialAuthResult> linkGoogleAccount(String idToken) async {
    final body = await _api.post('/api/auth/social/google/link', data: {
      'idToken': idToken,
    });
    return SocialAuthResult.fromJson(body as Map<String, dynamic>);
  }

  /// Testing-only: peek the most recently issued OTP for [phone].
  /// Returns null when peek is disabled (production with real SMS).
  Future<String?> peekOtp(String phone) async {
    try {
      final body = await _api.get('/api/auth/otp/peek?phone=$phone');
      return (body as Map<String, dynamic>)['code'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class OtpRequestedResult {
  OtpRequestedResult({required this.phone, required this.otpExpirySeconds});

  factory OtpRequestedResult.fromJson(Map<String, dynamic> json) =>
      OtpRequestedResult(
        phone: json['phone'] as String,
        otpExpirySeconds: (json['otpExpirySeconds'] as num).toInt(),
      );

  final String phone;
  final int otpExpirySeconds;
}

class AuthResult {
  AuthResult({
    required this.accessToken,
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    this.isProMember = false,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['accessToken'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        role: json['role'] as String,
        isProMember: json['isProMember'] as bool? ?? false,
      );

  final String accessToken;
  final String userId;
  final String name;
  final String phone;
  final String role;
  final bool isProMember;
}

class SocialAuthResult {
  SocialAuthResult({
    required this.accessToken,
    this.userId,
    this.name,
    this.phone,
    this.role,
    this.isProMember = false,
    this.needsPhone = false,
    this.message,
  });

  factory SocialAuthResult.fromJson(Map<String, dynamic> json) =>
      SocialAuthResult(
        accessToken: json['accessToken'] as String? ?? '',
        userId: json['userId'] as String?,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String?,
        isProMember: json['isProMember'] as bool? ?? false,
        needsPhone: json['needsPhone'] as bool? ?? false,
        message: json['message'] as String?,
      );

  final String? accessToken;
  final String? userId;
  final String? name;
  final String? phone;
  final String? role;
  final bool isProMember;
  final bool needsPhone;
  final String? message;

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
}