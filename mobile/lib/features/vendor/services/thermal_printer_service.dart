import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single line item on an [OrderTicket].
class OrderTicketItem {
  OrderTicketItem({
    required this.name,
    required this.quantity,
    this.modifiers = const [],
  });

  final String name;
  final int quantity;

  /// Modifier / add-on labels printed indented and bold under the item.
  final List<String> modifiers;
}

/// Payment type shown in the ticket footer.
enum TicketPaymentType {
  /// Order prepaid online — footer reads "PAID".
  paid,

  /// Cash on delivery — footer reads "** COLLECT CASH **".
  collectCash,
}

/// A formatted order ticket ready to be sent to a thermal printer.
class OrderTicket {
  OrderTicket({
    required this.orderId,
    required this.customerName,
    required this.items,
    required this.total,
    required this.paymentType,
    required this.timestamp,
  });

  final String orderId;
  final String customerName;
  final List<OrderTicketItem> items;
  final double total;
  final TicketPaymentType paymentType;
  final DateTime timestamp;
}

/// Manages Bluetooth thermal printer connection and ESC/POS ticket printing.
///
/// Uses [BlueThermalPrinter] for Bluetooth discovery and connection, and
/// [esc_pos_utils_plus] `Generator` to build ESC/POS byte arrays compatible
/// with 58 mm and 80 mm thermal printers.
///
/// The last connected printer's MAC address is persisted to
/// [SharedPreferences] so [autoConnect] can re-establish the connection
/// without user intervention.
class ThermalPrinterService {
  ThermalPrinterService() : _bluetooth = BlueThermalPrinter();

  static const _prefKeyAddress = 'thermal_printer_address';
  static const _prefKeyName = 'thermal_printer_name';
  static const _prefKeyPrintQueue = 'thermal_printer_queue';

  final BlueThermalPrinter _bluetooth;
  BluetoothDevice? _connectedDevice;

  /// In-memory print queue for failed print jobs. Persisted to
  /// SharedPreferences so jobs survive app kills. When the printer
  /// reconnects, the queue is flushed automatically (bulk reprint).
  final List<OrderTicket> _printQueue = [];
  bool _isFlushingQueue = false;

  /// Stream that emits the current queue size whenever it changes.
  final _queueController = StreamController<int>.broadcast();
  Stream<int> get queueSizeStream => _queueController.stream;

  /// Current number of pending print jobs in the queue.
  int get queueSize => _printQueue.length;

  // ──────────────────────────────────────────────────────────────
  //  Discovery
  // ──────────────────────────────────────────────────────────────

  /// Discovers available Bluetooth printers.
  ///
  /// Returns the list of bonded / nearby Bluetooth devices. On platforms
  /// where the scan fails (e.g. permissions not granted, Bluetooth off),
  /// an empty list is returned.
  Future<List<BluetoothDevice>> scanPrinters() async {
    try {
      return await _bluetooth.getDevices();
    } catch (_) {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Connection
  // ──────────────────────────────────────────────────────────────

  /// Connects to [device]. Returns `true` on success.
  ///
  /// On successful connection, automatically flushes any queued print
  /// jobs (bulk reprint) from a previous disconnection.
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device);
      _connectedDevice = device;
      await _savePrinter(device);
      // Trigger bulk reprint of any queued tickets
      _flushPrintQueue();
      return true;
    } catch (_) {
      _connectedDevice = null;
      return false;
    }
  }

  /// Disconnects the current printer.
  Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (_) {
      // Ignore — we are disconnecting anyway.
    }
    _connectedDevice = null;
  }

  /// Returns `true` if a printer is currently connected.
  Future<bool> isConnected() async {
    try {
      final connected = await _bluetooth.isConnected;
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Attempts to reconnect to the last saved printer. Returns `true` if
  /// a connection was (re)established.
  ///
  /// If already connected, returns `true` immediately without re-connecting.
  /// On successful reconnection, flushes any queued print jobs.
  Future<bool> autoConnect() async {
    if (await isConnected()) {
      // Already connected — flush any pending jobs
      _flushPrintQueue();
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_prefKeyAddress);
    final name = prefs.getString(_prefKeyName);
    if (address == null) return false;

    final device = BluetoothDevice(address: address, name: name ?? '');
    return connect(device);
  }

  /// Returns the saved printer address, or `null` if none has been saved.
  Future<String?> getSavedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyAddress);
  }

  /// Returns the saved printer display name, or `null`.
  Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyName);
  }

  /// Clears the saved printer from preferences.
  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAddress);
    await prefs.remove(_prefKeyName);
  }

  // ──────────────────────────────────────────────────────────────
  //  Printing
  // ──────────────────────────────────────────────────────────────

  /// Prints [ticket] to the connected printer. Returns `true` on success.
  ///
  /// If no printer is connected, attempts [autoConnect] first. If that
  /// also fails, the ticket is queued in the print queue (persisted to
  /// SharedPreferences) and will be automatically reprinted when the
  /// printer reconnects.
  Future<bool> printOrderTicket(OrderTicket ticket) async {
    if (!await isConnected()) {
      if (!await autoConnect()) {
        // Printer unavailable — queue the ticket for bulk reprint
        await _enqueuePrintJob(ticket);
        return false;
      }
    }

    try {
      final bytes = await _buildTicketBytes(ticket);
      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      // Print failed (e.g. printer powered off mid-batch) — queue for reprint
      await _enqueuePrintJob(ticket);
      return false;
    }
  }

  /// Prints a sample / test ticket. Returns `true` on success.
  Future<bool> printTestTicket() async {
    if (!await isConnected()) {
      if (!await autoConnect()) return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = <int>[];
      bytes += generator.text(
        'PY Connect',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ),
      );
      bytes += generator.text(
        'Test Print',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        'Printer connected successfully!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(2);
      bytes += generator.cut();
      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Internals
  // ──────────────────────────────────────────────────────────────

  Future<List<int>> _buildTicketBytes(OrderTicket ticket) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    // Header — big bold Order ID (double-height + double-width)
    bytes += generator.text(
      'Order #${ticket.orderId}',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.feed(1);

    // Timestamp
    final ts = ticket.timestamp;
    final timeStr =
        '${ts.day}/${ts.month}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    bytes += generator.text(timeStr);
    bytes += generator.feed(1);

    // Customer name
    bytes += generator.text(
      'Customer: ${ticket.customerName}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.feed(1);

    // Separator
    bytes += generator.text('-' * 32);
    bytes += generator.feed(1);

    // Items
    for (final item in ticket.items) {
      bytes += generator.text(
        '${item.quantity}x  ${item.name}',
        styles: const PosStyles(bold: true),
      );
      // Modifiers / add-ons — indented and bold
      for (final mod in item.modifiers) {
        bytes += generator.text(
          '    + $mod',
          styles: const PosStyles(bold: true),
        );
      }
    }

    bytes += generator.feed(1);
    bytes += generator.text('-' * 32);
    bytes += generator.feed(1);

    // Total
    bytes += generator.text(
      'Total: Rs.${ticket.total.toStringAsFixed(0)}',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.feed(2);

    // Footer — payment status in large text
    switch (ticket.paymentType) {
      case TicketPaymentType.paid:
        bytes += generator.text(
          'PAID',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center,
          ),
        );
      case TicketPaymentType.collectCash:
        bytes += generator.text(
          '** COLLECT CASH **',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center,
          ),
        );
    }
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<void> _savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyAddress, device.address ?? '');
    await prefs.setString(_prefKeyName, device.name ?? '');
  }

  // ──────────────────────────────────────────────────────────────
  //  Print Queue (reprint on reconnection)
  // ──────────────────────────────────────────────────────────────

  /// Enqueues a failed print job. The ticket is persisted to
  /// SharedPreferences so it survives app kills. When the printer
  /// reconnects, [_flushPrintQueue] reprints all queued tickets.
  Future<void> _enqueuePrintJob(OrderTicket ticket) async {
    _printQueue.add(ticket);
    await _persistPrintQueue();
  }

  /// Persists the print queue to SharedPreferences as JSON.
  Future<void> _persistPrintQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_printQueue.map(_ticketToJson).toList());
      await prefs.setString(_prefKeyPrintQueue, json);
    } catch (_) {
      // Storage write failed — queue is still in memory.
    }
    _queueController.add(_printQueue.length);
  }

  /// Loads the persisted print queue on startup.
  Future<void> loadPrintQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefKeyPrintQueue);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List;
        _printQueue.clear();
        for (final e in list) {
          _printQueue.add(_ticketFromJson(e as Map<String, dynamic>));
        }
        _queueController.add(_printQueue.length);
      }
    } catch (_) {
      // Corrupted queue — start fresh.
    }
  }

  /// Flushes all queued print jobs (bulk reprint). Called automatically
  /// when the printer reconnects. Tickets are printed in order.
  Future<void> _flushPrintQueue() async {
    if (_isFlushingQueue || _printQueue.isEmpty) return;
    _isFlushingQueue = true;

    try {
      while (_printQueue.isNotEmpty) {
        final ticket = _printQueue.first;
        try {
          final bytes = await _buildTicketBytes(ticket);
          await _bluetooth.writeBytes(Uint8List.fromList(bytes));
          _printQueue.removeAt(0);
          await _persistPrintQueue();
        } catch (_) {
          // Printer failed again — stop flushing, keep remaining jobs queued.
          break;
        }
      }
    } finally {
      _isFlushingQueue = false;
    }
  }

  /// Clears the print queue without reprinting. Used on sign-out.
  Future<void> clearPrintQueue() async {
    _printQueue.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyPrintQueue);
    _queueController.add(0);
  }

  void dispose() {
    _queueController.close();
  }

  // ── Ticket JSON serialization for queue persistence ──

  static Map<String, dynamic> _ticketToJson(OrderTicket t) => {
        'orderId': t.orderId,
        'customerName': t.customerName,
        'items': t.items
            .map((i) => {
                  'name': i.name,
                  'quantity': i.quantity,
                  'modifiers': i.modifiers,
                })
            .toList(),
        'total': t.total,
        'paymentType': t.paymentType.name,
        'timestamp': t.timestamp.toIso8601String(),
      };

  static OrderTicket _ticketFromJson(Map<String, dynamic> j) => OrderTicket(
        orderId: j['orderId'] as String,
        customerName: j['customerName'] as String,
        items: (j['items'] as List)
            .map((i) => OrderTicketItem(
                  name: (i as Map<String, dynamic>)['name'] as String,
                  quantity: i['quantity'] as int,
                  modifiers:
                      (i['modifiers'] as List?)?.cast<String>() ?? const [],
                ))
            .toList(),
        total: (j['total'] as num).toDouble(),
        paymentType: TicketPaymentType.values.byName(j['paymentType'] as String),
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}
