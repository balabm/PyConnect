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

  /// Updates the authenticated user's profile (currently supports name).
  Future<void> updateMe(String name) async {
    await _api.put('/api/auth/me', data: {'name': name});
  }

  /// Accepts the liability waiver. Required before booking rides or rentals.
  Future<void> acceptWaiver() async {
    await _api.post('/api/auth/waiver/accept');
  }

  /// Sends a Google idToken to the backend and returns a PY Connect JWT.
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

  /// Step 1 of phone change: sends an OTP to the new phone number.
  Future<void> requestPhoneChange(String newPhone) async {
    await _api.post('/api/auth/change-phone/request', data: {
      'newPhone': newPhone,
    });
  }

  /// Step 2 of phone change: verifies the OTP and updates the user's
  /// phone. Returns a fresh JWT with the new phone claim.
  Future<AuthResult> verifyPhoneChange(String newPhone, String otpCode) async {
    final body = await _api.post('/api/auth/change-phone/verify', data: {
      'newPhone': newPhone,
      'otpCode': otpCode,
    });
    return AuthResult.fromJson(body as Map<String, dynamic>);
  }

  /// Deletes the user's account and anonymizes all PII (Right to be Forgotten).
  /// The user record is kept for financial auditing but all personal data is
  /// hard-deleted. After this call, the token is invalid and the user must
  /// sign out locally.
  Future<void> deleteAccount() async {
    await _api.delete('/api/auth/account');
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