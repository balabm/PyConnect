import '../../../core/network/api_client.dart';

/// API for registering FCM device tokens with the backend.
/// The endpoint differs by auth context:
///   - Consumer/Driver apps use /api/user/device-token (User entity)
///   - Partner app uses /api/vendor/device-token (Vendor entity)
class DeviceTokenApi {
  DeviceTokenApi(this._client, {this.useVendorEndpoint = false});

  final ApiClient _client;
  final bool useVendorEndpoint;

  Future<void> updateToken(String token) async {
    final endpoint = useVendorEndpoint ? '/api/vendor/device-token' : '/api/user/device-token';
    await _client.post(endpoint, data: {'token': token});
  }

  Future<void> clearToken() async {
    if (useVendorEndpoint) {
      await _client.delete('/api/vendor/device-token');
    }
  }
}
