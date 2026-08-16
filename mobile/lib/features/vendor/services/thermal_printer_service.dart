import 'dart:async';
import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
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

  final BlueThermalPrinter _bluetooth;
  BluetoothDevice? _connectedDevice;

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
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device);
      _connectedDevice = device;
      await _savePrinter(device);
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
  Future<bool> autoConnect() async {
    if (await isConnected()) return true;

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
  /// also fails, returns `false`.
  Future<bool> printOrderTicket(OrderTicket ticket) async {
    if (!await isConnected()) {
      if (!await autoConnect()) return false;
    }

    try {
      final bytes = await _buildTicketBytes(ticket);
      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
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
}
