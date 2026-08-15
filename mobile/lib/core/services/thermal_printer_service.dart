import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';

import '../../features/vendor/domain/kds_models.dart';
import '../../features/vendor/data/vendor_dashboard_api.dart';

/// Service for printing Kitchen Order Tickets (KOT) and receipts
/// to Bluetooth thermal printers using ESC/POS commands.
class ThermalPrinterService {
  ThermalPrinterService._();

  static final _instance = ThermalPrinterService._();
  static ThermalPrinterService get instance => _instance;

  NetworkPrinter? _printer;
  String? _connectedAddress;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  String? get connectedAddress => _connectedAddress;

  /// Connect to a Bluetooth thermal printer at the given IP and port.
  /// Typical port for ESC/POS network printers is 9100.
  Future<bool> connect(String ip, {int port = 9100}) async {
    if (kIsWeb) return false;

    try {
      const paper = PaperSize.mm80;
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(paper, profile);
      final result = await printer.connect(ip, port: port);

      if (result == PosPrintResult.success) {
        _printer = printer;
        _connectedAddress = ip;
        _isConnected = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Thermal printer connect error: $e');
      return false;
    }
  }

  /// Disconnect from the printer.
  void disconnect() {
    _printer?.disconnect();
    _printer = null;
    _connectedAddress = null;
    _isConnected = false;
  }

  /// Print a Kitchen Order Ticket (KOT) for a KDS order.
  Future<bool> printKot(KdsOrder order) async {
    if (_printer == null || !_isConnected) return false;

    try {
      final p = _printer!;

      // Header
      p.text(order.vendorName,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      p.text('KITCHEN ORDER TICKET',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      p.hr();
      p.text('Order: #${order.orderNumber}',
          styles: const PosStyles(bold: true));
      p.text('Customer: ${order.customerName}');
      p.text('Time: ${_formatDateTime(order.placedAt)}');
      p.hr();

      // Items
      for (final item in order.items) {
        p.text('${item.quantity}x  ${item.name}',
            styles: const PosStyles(bold: true));
        if (item.specialInstructions != null) {
          p.text('  *** ${item.specialInstructions}',
              styles: const PosStyles(align: PosAlign.left));
        }
      }

      p.hr();
      if (order.deliveryAddress != null) {
        p.text('Delivery to:',
            styles: const PosStyles(bold: true));
        p.text(order.deliveryAddress!,
            styles: const PosStyles(align: PosAlign.left));
      }
      if (order.notes != null) {
        p.text('Notes: ${order.notes}');
      }

      p.feed(2);
      p.cut();

      return true;
    } catch (e) {
      debugPrint('Print KOT error: $e');
      return false;
    }
  }

  /// Print a booking receipt.
  Future<bool> printReceipt(BookingSummary booking) async {
    if (_printer == null || !_isConnected) return false;

    try {
      final p = _printer!;

      p.text('PY Connect',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      p.text('Booking Receipt',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      p.hr();
      p.text('Booking ID: ${booking.bookingId}');
      p.text('Customer: ${booking.customerName}');
      p.text('Type: ${booking.serviceType}');
      p.text('Scheduled: ${booking.scheduledFor}');
      p.text('Status: ${booking.status}');
      p.text('Payment: ${booking.paymentStatus}');
      p.hr();
      p.text('Amount: Rs. ${booking.amount.toStringAsFixed(0)}',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            align: PosAlign.right,
          ));
      p.feed(2);
      p.cut();

      return true;
    } catch (e) {
      debugPrint('Print receipt error: $e');
      return false;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
