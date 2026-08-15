import '../../../core/network/api_client.dart';

class QuickCommerceApi {
  QuickCommerceApi(this._api);
  final ApiClient _api;

  Future<List<dynamic>> listProducts({String? category, bool? lateNight}) async {
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    if (lateNight != null) params['lateNight'] = lateNight;
    return await _api.get('/api/essentials', queryParameters: params) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getProduct(String id) async {
    return await _api.get('/api/essentials/$id') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    return await _api.post('/api/essentials/orders', data: body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listOrders({int page = 1, int pageSize = 20}) async {
    return await _api.get('/api/essentials/orders', queryParameters: {'page': page, 'pageSize': pageSize}) as List<dynamic>;
  }

  Future<List<dynamic>> getSuggestions(List<String> productIds) async {
    return await _api.post('/api/essentials/suggestions', data: {'productIds': productIds}) as List<dynamic>;
  }
}
