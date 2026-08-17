import '../../../core/network/api_client.dart';

/// API for registering FCM device tokens with the backend.
/// The endpoint differs by auth context:
///   - Consumer/Driver apps use /api/auth/fcm-token (User entity)
///   - Partner app uses /api/vendor/fcm-token (Vendor entity)
class DeviceTokenApi {
  DeviceTokenApi(this._client, {this.useVendorEndpoint = false});

  final ApiClient _client;
  final bool useVendorEndpoint;

  Future<void> updateToken(String token) async {
    if (useVendorEndpoint) {
      await _client.put('/api/vendor/fcm-token', data: {'token': token});
    } else {
      await _client.updateFcmToken(token);
    }
  }

  Future<void> clearToken() async {
    if (useVendorEndpoint) {
      await _client.delete('/api/vendor/fcm-token');
    } else {
      await _client.deleteFcmToken();
    }
  }
}
