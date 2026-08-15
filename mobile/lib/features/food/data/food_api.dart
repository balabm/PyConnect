import '../../../core/network/api_client.dart';

class FoodDeliveryApi {
  FoodDeliveryApi(this._api);
  final ApiClient _api;

  Future<List<dynamic>> getMenu(String vendorId) async {
    return await _api.get('/api/vendors/$vendorId/menu') as List<dynamic>;
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> body) async {
    return await _api.post('/api/orders/checkout', data: body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    return await _api.get('/api/orders/$orderId') as Map<String, dynamic>;
  }

  Future<List<dynamic>> listOrders({int page = 1, int pageSize = 20}) async {
    return await _api.get('/api/orders', queryParameters: {'page': page, 'pageSize': pageSize}) as List<dynamic>;
  }

  Future<List<dynamic>> listVendors({bool foodVendorsOnly = false}) async {
    return await _api.get('/api/vendors',
        queryParameters: {'foodVendorsOnly': foodVendorsOnly}) as List<dynamic>;
  }
}
