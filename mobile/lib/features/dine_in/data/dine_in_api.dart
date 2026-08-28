import '../../../core/network/api_client.dart';

/// API client for dine-in QR table ordering.
class DineInApi {
  DineInApi(this._api);

  final ApiClient _api;

  /// Scans a table QR code. Opens a new session or returns the existing
  /// active session for "add to order" flow.
  Future<DineInSessionModel> scanTable({
    required String venueId,
    required String vendorId,
    required int tableId,
  }) async {
    final body = await _api.post('/api/dine-in/scan', data: {
      'venueId': venueId,
      'vendorId': vendorId,
      'tableId': tableId,
    });
    return DineInSessionModel.fromJson(body as Map<String, dynamic>);
  }

  /// Gets the active session for a table, if any.
  Future<DineInSessionModel?> getActiveSession({
    required String venueId,
    required int tableId,
  }) async {
    try {
      final body = await _api.get('/api/dine-in/active', queryParameters: {
        'venueId': venueId,
        'tableId': tableId,
      });
      final session = DineInSessionModel.fromJson(body as Map<String, dynamic>);
      return session.sessionId.isEmpty ? null : session;
    } catch (_) {
      return null;
    }
  }

  /// Closes a dine-in session when the bill is settled.
  Future<void> closeSession(String sessionId) async {
    await _api.post('/api/dine-in/$sessionId/close');
  }
}

class DineInSessionModel {
  DineInSessionModel({
    required this.sessionId,
    required this.tableId,
    required this.vendorId,
    this.rootOrderId,
    required this.isAddToOrder,
    required this.totalSettled,
  });

  factory DineInSessionModel.fromJson(Map<String, dynamic> json) =>
      DineInSessionModel(
        sessionId: (json['sessionId'] as String?) ?? '',
        tableId: (json['tableId'] as int?) ?? 0,
        vendorId: (json['vendorId'] as String?) ?? '',
        rootOrderId: json['rootOrderId'] as String?,
        isAddToOrder: (json['isAddToOrder'] as bool?) ?? false,
        totalSettled: (json['totalSettled'] as num?)?.toDouble() ?? 0,
      );

  final String sessionId;
  final int tableId;
  final String vendorId;
  final String? rootOrderId;
  final bool isAddToOrder;
  final double totalSettled;
}
