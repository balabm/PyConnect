import '../../../core/network/api_client.dart';
import '../domain/kds_models.dart';

/// API client for Kitchen Display System endpoints.
class KdsApi {
  KdsApi(this._api);

  final ApiClient _api;

  /// Fetch all active KDS orders for the vendor's venues.
  Future<List<KdsOrder>> getOrders() async {
    final body = await _api.get('/api/vendor/kds/orders');
    final list = body as List? ?? [];
    return list
        .map((e) => KdsOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Advance an order to the next KDS stage.
  Future<KdsOrder> advanceStage(String orderId) async {
    final body = await _api.post('/api/vendor/kds/orders/$orderId/advance');
    return KdsOrder.fromJson(body as Map<String, dynamic>);
  }
}
