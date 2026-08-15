import 'dart:convert';

/// Minimal JWT decoder for offline token validation (exp claim).
/// Does NOT verify signature — only extracts claims for client-side checks.
class JwtDecoder {
  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      // Add padding if needed
      final normalized = base64Url.normalize(payload);
      final decoded = base64Url.decode(normalized);
      final json = utf8.decode(decoded);
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  static DateTime? getExpiry(String token) {
    final claims = decode(token);
    if (claims == null) return null;
    final exp = claims['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    return null;
  }

  static bool isExpired(String token, {Duration buffer = const Duration(seconds: 30)}) {
    final expiry = getExpiry(token);
    if (expiry == null) return true; // Treat unparseable as expired
    return DateTime.now().toUtc().add(buffer).isAfter(expiry);
  }

  static String? getRole(String token) {
    final claims = decode(token);
    return claims?['role'] as String?;
  }

  static String? getUserId(String token) {
    final claims = decode(token);
    final id = claims?['userId'] as String?;
    if (id != null && id.isNotEmpty) return id;
    return claims?['sub'] as String?;
  }
}