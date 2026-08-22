import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single GPS ping that was captured but could not be sent to the backend
/// because the device was offline (network error during a cell handover or
/// dead-zone traversal). Persisted to SharedPreferences so it survives
/// app kills and can be flushed when 4G is restored.
@immutable
class BufferedGpsPing {
  const BufferedGpsPing({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double? heading;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        if (heading != null) 'heading': heading,
        'at': capturedAt.toIso8601String(),
      };

  factory BufferedGpsPing.fromJson(Map<String, dynamic> json) => BufferedGpsPing(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        capturedAt: DateTime.parse(json['at'] as String),
      );
}

/// Buffers GPS pings in SharedPreferences when the Captain app loses
/// connectivity (cell handover, signal dead zones). When 4G is restored,
/// the queue is flushed to the backend so the trip trail remains complete.
///
/// Design:
/// - Lightweight: JSON in SharedPreferences, no Hive/SQLite dependency.
/// - Bounded: max 120 pings (10 minutes at 5s interval). Older pings
///   are dropped to prevent unbounded growth during extended outages.
/// - Non-blocking: the driver never sees the buffer — it flushes silently.
class GpsBufferService {
  static const _storageKey = 'gps_buffer_queue';
  static const _maxBufferSize = 120;

  final SharedPreferences _prefs;
  final Future<bool> Function(double lat, double lng, {double? heading}) _sender;

  final _controller = StreamController<int>.broadcast();

  /// Emits the current buffer size whenever it changes.
  Stream<int> get bufferSizeStream => _controller.stream;

  List<BufferedGpsPing> _buffer = [];
  bool _flushing = false;

  GpsBufferService(this._prefs, this._sender) {
    _loadBuffer();
  }

  /// Loads the persisted buffer from SharedPreferences on startup.
  void _loadBuffer() {
    try {
      final json = _prefs.getString(_storageKey);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List;
        _buffer = list
            .map((e) => BufferedGpsPing.fromJson(e as Map<String, dynamic>))
            .toList();
        _controller.add(_buffer.length);
      }
    } catch (_) {
      _buffer = [];
    }
  }

  /// Persists the current buffer to SharedPreferences.
  Future<void> _persist() async {
    try {
      final json = jsonEncode(_buffer.map((p) => p.toJson()).toList());
      await _prefs.setString(_storageKey, json);
    } catch (_) {
      // Storage write failed — buffer is still in memory.
    }
    _controller.add(_buffer.length);
  }

  /// Current buffer size (number of pending GPS pings).
  int get bufferSize => _buffer.length;

  /// Whether there are pending pings to flush.
  bool get hasPending => _buffer.isNotEmpty;

  /// Enqueues a GPS ping when the network is down. The ping is persisted
  /// to SharedPreferences so it survives app kills.
  Future<void> enqueue(double latitude, double longitude, {double? heading}) async {
    _buffer.add(BufferedGpsPing(
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      capturedAt: DateTime.now(),
    ));

    // Drop oldest pings if buffer exceeds max size
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeRange(0, _buffer.length - _maxBufferSize);
    }

    await _persist();
  }

  /// Attempts to flush all buffered GPS pings to the backend. Called when
  /// network connectivity is restored. Pings are sent in order. If any
  /// ping fails with a network error, the flush stops and remaining pings
  /// stay queued for the next attempt.
  Future<void> flush() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;

    try {
      while (_buffer.isNotEmpty) {
        final ping = _buffer.first;
        try {
          final success = await _sender(
            ping.latitude,
            ping.longitude,
            heading: ping.heading,
          );
          if (success) {
            _buffer.removeAt(0);
            await _persist();
          } else {
            break;
          }
        } catch (_) {
          // Network still down — stop flushing, try again later.
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// Clears the buffer without sending. Used on sign-out.
  Future<void> clear() async {
    _buffer.clear();
    await _prefs.remove(_storageKey);
    _controller.add(0);
  }

  void dispose() {
    _controller.close();
  }
}
