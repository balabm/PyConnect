import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math';

import '../config/app_config.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    String? initialToken,
    this.onUnauthorized,
    this.onTokenRefreshed,
    this._maxRetries = 3,
    this._baseDelay = const Duration(milliseconds: 500),
  })  : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    _token = initialToken;
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // 401 handling is done centrally in _requestWithRetry which converts
        // it to an AuthRequiredException. We just pass the error through here.
        handler.next(error);
      },
    ));
  }

  final void Function()? onUnauthorized;
  /// Called with the new access token after a successful silent refresh,
  /// so the caller can persist it to secure storage.
  final Future<void> Function(String newToken)? onTokenRefreshed;
  final int _maxRetries;
  final Duration _baseDelay;

  final Dio _dio;
  String? _token;

  void setToken(String? token) => _token = token;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _requestWithRetry(() => _dio.get(path, queryParameters: queryParameters));

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _requestWithRetry(() => _dio.post(path, data: data, queryParameters: queryParameters));

  Future<dynamic> put(
    String path, {
    Object? data,
  }) =>
      _requestWithRetry(() => _dio.put(path, data: data));

  Future<dynamic> delete(
    String path, {
    Object? data,
  }) =>
      _requestWithRetry(() => _dio.delete(path, data: data));

  Future<dynamic> _requestWithRetry(Future<Response<dynamic>> Function() request) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await request();
        return _unwrap(response);
      } on DioException catch (e) {
        // 401 — attempt silent token refresh before clearing auth state.
        if (e.response?.statusCode == 401) {
          // Only attempt refresh if we actually had a token — a 401 without
          // a token means the request raced ahead of AuthController.build().
          // Attempt refresh on the first 401 (attempt == 0); subsequent 401s
          // after a failed refresh fall through to onUnauthorized.
          if (_token != null && _token!.isNotEmpty && attempt == 0) {
            // Attempt silent token refresh via POST /api/auth/refresh.
            final refreshed = await _attemptTokenRefresh();
            if (refreshed) {
              // Retry the original request with the new token.
              attempt++;
              continue;
            }
            // Refresh failed — clear auth state and throw.
            onUnauthorized?.call();
          } else if (_token != null && _token!.isNotEmpty) {
            onUnauthorized?.call();
          }
          throw AuthRequiredException();
        }
        // 403 — authenticated but lacking the required role or waiver.
        if (e.response?.statusCode == 403) {
          final data = e.response?.data;
          // Detect the liability waiver requirement from the backend's
          // RequireWaiverAttribute filter response.
          if (data is Map && data['error'] == 'Liability_Waiver_Required') {
            throw WaiverRequiredException();
          }
          String msg = 'You do not have permission to perform this action.';
          if (data is Map && data['message'] is String) {
            msg = data['message'] as String;
          }
          throw ApiException(msg);
        }
        attempt++;
        if (!_shouldRetry(e) || attempt > _maxRetries) {
          throw _friendlyException(e);
        }
        final delay = _calculateDelay(attempt);
        await Future.delayed(delay);
      }
    }
  }

  /// Converts a raw [DioException] into a user-friendly [ApiException]
  /// so the UI never displays raw Dio error strings.
  ApiException _friendlyException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException('The request timed out. Please check your connection and try again.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException('Could not reach PY Connect. Please check your internet connection.');
    }
    final status = e.response?.statusCode;
    if (status != null && status >= 500) {
      return ApiException('PY Connect is having a moment. Please try again shortly.');
    }
    if (status == 429) {
      return ApiException('Too many requests. Please slow down and try again.');
    }
    if (status != null && status >= 400) {
      // Try to extract a server-provided message.
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        final msg = (data['error'] as Map)['message']?.toString();
        if (msg != null && msg.isNotEmpty) return ApiException(msg);
      }
      if (data is Map && data['message'] is String) {
        return ApiException(data['message'] as String);
      }
      return ApiException('The request could not be completed (error $status).');
    }
    return ApiException('Something went wrong. Please try again.');
  }

  bool _shouldRetry(DioException e) {
    // Retry on network errors, timeouts, and 5xx server errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    if (e.response?.statusCode != null) {
      final status = e.response!.statusCode!;
      return status >= 500 || status == 429; // Retry on 5xx and rate limit (429)
    }
    return false;
  }

  Duration _calculateDelay(int attempt) {
    // Exponential backoff with jitter: baseDelay * 2^attempt + random jitter
    final exponential = _baseDelay.inMilliseconds * pow(2, attempt - 1);
    final jitter = Random().nextInt(200); // 0-200ms jitter
    return Duration(milliseconds: exponential.toInt() + jitter);
  }

  /// Attempts a silent token refresh by calling POST /api/auth/refresh
  /// with the current (still-valid) token to obtain a fresh 60-minute
  /// access token. Returns `true` on success, `false` on failure.
  ///
  /// Tries the consumer refresh endpoint first, then falls back to the
  /// vendor refresh endpoint so both token types are handled.
  Future<bool> _attemptTokenRefresh() async {
    if (_token == null || _token!.isEmpty) return false;
    try {
      final newToken = await _tryRefresh('/api/auth/refresh');
      if (newToken != null) return true;
      // Consumer refresh failed — try the vendor refresh endpoint.
      final vendorToken = await _tryRefresh('/api/vendor/auth/refresh');
      if (vendorToken != null) return true;
    } catch (_) {
      // Refresh failed — fall through to re-auth
    }
    return false;
  }

  /// Calls the given refresh endpoint with the current bearer token and
  /// returns the new access token on success, or `null` on failure.
  Future<String?> _tryRefresh(String endpoint) async {
    try {
      final response = await _dio.post(
        endpoint,
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        // Backend returns AuthResponse with `accessToken` (camelCase JSON).
        final newToken = (data['accessToken'] as String?) ??
            (data['token'] as String?); // fallback for alternate schemas
        if (newToken != null && newToken.isNotEmpty) {
          _token = newToken;
          // Persist the refreshed token so it survives app restarts.
          await onTokenRefreshed?.call(newToken);
          return newToken;
        }
      }
    } catch (_) {
      // This endpoint didn't work — caller will try the next one.
    }
    return null;
  }

  static dynamic _unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body != null && body is Map && body.containsKey('error')) {
      final message = (body['error'] as Map?)?['message']?.toString() ?? 'Request failed';
      throw ApiException(message);
    }
    return body;
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the API returns 401 Unauthorized.
/// The UI should catch this and prompt the user to sign in
/// rather than showing a raw error string.
class AuthRequiredException implements Exception {
  @override
  String toString() => 'Authentication required';
}

/// Thrown when the backend returns 403 with `Liability_Waiver_Required`.
/// The UI should catch this and show the waiver acceptance sheet.
class WaiverRequiredException implements Exception {
  @override
  String toString() => 'Liability waiver required';
}