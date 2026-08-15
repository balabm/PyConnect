import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';
import 'package:signalr_netcore/ihub_protocol.dart';

import 'admin_api.dart';
import '../../support/data/support_api.dart';

/// Web implementation of the admin SignalR service.
/// Uses the signalr_netcore package which handles web via dart:html internally.
class AdminSignalRService {
  AdminSignalRService._(this._connection, this._controller, this._criticalController);

  final HubConnection _connection;
  final StreamController<AdminSignalREvent> _controller;
  final StreamController<CriticalTicketModel> _criticalController;

  Stream<AdminSignalREvent> get events => _controller.stream;
  Stream<CriticalTicketModel> get criticalTickets => _criticalController.stream;

  static Future<AdminSignalRService> connect({
    required String baseUrl,
    required String authToken,
  }) async {
    final headers = MessageHeaders();
    headers.setHeaderValue('Authorization', 'Bearer $authToken');

    final connection = HubConnectionBuilder()
        .withUrl(
          '$baseUrl/hubs/admin',
          options: HttpConnectionOptions(
            accessTokenFactory: () => Future.value(authToken),
            headers: headers,
          ),
        )
        .withAutomaticReconnect()
        .build();

    final controller = StreamController<AdminSignalREvent>.broadcast();
    final criticalController = StreamController<CriticalTicketModel>.broadcast();
    final service = AdminSignalRService._(connection, controller, criticalController);

    // Register all admin event handlers.
    final eventNames = [
      'SosAlert', 'SosAlertResolved',
      'CriticalTicketPushed', 'SupportTicketResolved',
      'UserRoleChanged', 'UserStatusChanged',
      'DriverKycRejected', 'DriverApproved',
      'VendorApproved', 'VendorRejected',
      'RideStarted', 'RideCompleted', 'RideCancelled',
      'DriverAssigned', 'RideAccepted',
      'SurgeModeChanged', 'VenueStatusChanged',
    ];

    for (final eventName in eventNames) {
      connection.on(eventName, (args) {
        if (args != null && args.isNotEmpty) {
          final raw = args[0];
          Map<String, dynamic> payload;
          if (raw is Map<String, dynamic>) {
            payload = raw;
          } else if (raw is Map) {
            payload = Map<String, dynamic>.from(raw);
          } else {
            payload = <String, dynamic>{};
          }
          if (!controller.isClosed) {
            controller.add(AdminSignalREvent(type: eventName, payload: payload));
          }
          if (eventName == 'CriticalTicketPushed' && !criticalController.isClosed) {
            try {
              criticalController.add(CriticalTicketModel.fromJson(payload));
            } catch (_) {}
          }
        }
      });
    }

    try {
      await connection.start();
      await connection.invoke('JoinAdminGroup');
    } catch (e) {
      // If connection fails, polling providers will still work.
      controller.add(AdminSignalREvent(
          type: 'ConnectionError', payload: {'error': e.toString()}));
    }

    return service;
  }

  Future<void> dispose() async {
    try {
      await _connection.invoke('LeaveAdminGroup');
      await _connection.stop();
    } catch (_) {}
    await _controller.close();
    await _criticalController.close();
  }
}
