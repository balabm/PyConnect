import '../../../core/network/api_client.dart';

class PublicApi {
  PublicApi(this._api);
  final ApiClient _api;

  Future<List<dynamic>> listFlashPromos() async {
    return await _api.get('/api/flash-promos') as List<dynamic>;
  }

  Future<Map<String, dynamic>> getServiceArea() async {
    return await _api.get('/api/service-area') as Map<String, dynamic>;
  }
}
