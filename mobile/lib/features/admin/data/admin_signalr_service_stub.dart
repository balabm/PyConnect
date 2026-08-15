import 'dart:async';

import 'admin_api.dart';
import '../../support/data/support_api.dart';

/// Fallback stub for platforms that don't support SignalR.
/// Returns empty streams — polling providers handle data refresh.
class AdminSignalRService {
  AdminSignalRService._(this._controller, this._criticalController);

  final StreamController<AdminSignalREvent> _controller;
  final StreamController<CriticalTicketModel> _criticalController;

  Stream<AdminSignalREvent> get events => _controller.stream;
  Stream<CriticalTicketModel> get criticalTickets => _criticalController.stream;

  static Future<AdminSignalRService> connect({
    required String baseUrl,
    required String authToken,
  }) async {
    final controller = StreamController<AdminSignalREvent>.broadcast();
    final criticalController = StreamController<CriticalTicketModel>.broadcast();
    return AdminSignalRService._(controller, criticalController);
  }

  Future<void> dispose() async {
    await _controller.close();
    await _criticalController.close();
  }
}
