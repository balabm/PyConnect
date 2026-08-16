import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';

/// Wrapper around the SignalR .NET Core client for managing hub connections.
/// Handles auth token injection, auto-reconnect, and event subscription.
class SignalRClient {
  SignalRClient({required this.hubPath, required this.tokenProvider});

  final String hubPath;
  final String? Function()? tokenProvider;

  HubConnection? _connection;
  final Map<String, List<void Function(List<Object?>?)>> _handlers = {};
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  bool _isReconnecting = false;

  /// Callback invoked when the reconnection state changes. Receives `true`
  /// when the connection is lost and a reconnect is in progress, `false`
  /// when the connection has been restored. The driver shell can listen to
  /// this to show/hide a "Reconnecting…" banner.
  void Function(bool isReconnecting)? onConnectionStateChanged;

  final List<StreamController<List<Object?>>> _controllers = [];

  bool get isConnected => _connection?.state == HubConnectionState.Connected;
  bool get isReconnecting => _isReconnecting;

  String get _hubUrl {
    final base = AppConfig.apiBaseUrl;
    return '$base$hubPath';
  }

  /// Connect to the hub. Idempotent — safe to call multiple times.
  Future<void> connect() async {
    if (_isConnecting || isConnected) return;
    _isConnecting = true;
    _shouldReconnect = true;

    try {
      _connection = HubConnectionBuilder()
          .withUrl(_hubUrl, options: HttpConnectionOptions(
            accessTokenFactory: () async {
              final token = tokenProvider?.call();
              return token ?? '';
            },
          ))
          .withAutomaticReconnect()
          .build();

      _connection!.onreconnecting(({error}) {
        // Connection lost, attempting to reconnect
        _isReconnecting = true;
        onConnectionStateChanged?.call(true);
      });

      _connection!.onreconnected(({connectionId}) {
        // Reconnected — handlers are automatically preserved
        _isReconnecting = false;
        onConnectionStateChanged?.call(false);
      });

      _connection!.onclose(({error}) {
        if (_shouldReconnect) {
          Future.delayed(const Duration(seconds: 3), () {
            if (_shouldReconnect) connect();
          });
        } else {
          _isReconnecting = false;
          onConnectionStateChanged?.call(false);
        }
      });

      // Register all pending handlers before starting
      for (final entry in _handlers.entries) {
        for (final callback in entry.value) {
          _connection!.on(entry.key, callback);
        }
      }

      await _connection!.start();
    } finally {
      _isConnecting = false;
    }
  }

  /// Subscribe to a server event. Returns a stream of events.
  Stream<List<Object?>> on(String eventName) {
    final controller = StreamController<List<Object?>>.broadcast();
    void callback(List<Object?>? args) {
      if (!controller.isClosed) controller.add(args ?? []);
    }

    _handlers.putIfAbsent(eventName, () => []).add(callback);

    if (_connection != null) {
      _connection!.on(eventName, callback);
    }

    _controllers.add(controller);
    return controller.stream;
  }

  /// Invoke a server method.
  Future<void> invoke(String methodName, [List<Object?>? args]) async {
    if (_connection == null || !isConnected) {
      await connect();
    }
    await _connection?.invoke(methodName, args: args?.cast<Object>());
  }

  /// Disconnect from the hub.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    for (final c in _controllers) {
      await c.close();
    }
    _controllers.clear();
    _handlers.clear();
    await _connection?.stop();
    _connection = null;
  }
}
