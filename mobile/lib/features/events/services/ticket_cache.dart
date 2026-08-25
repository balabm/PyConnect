import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache service for event tickets backed by [SharedPreferences].
///
/// Tickets are stored individually as JSON under `cached_ticket_<id>` keys,
/// and a manifest of cached ticket IDs is maintained under `cached_ticket_ids`
/// so [loadTickets] can reconstruct the full list without scanning every key.
class TicketCache {
  static const _ticketKeyPrefix = 'cached_ticket_';
  static const _idsKey = 'cached_ticket_ids';

  /// Persists a single ticket to local storage and registers its ID in the
  /// manifest so it can be discovered by [loadTickets].
  Future<void> saveTicket(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final id = ticket['id']?.toString();
    if (id == null || id.isEmpty) return;

    await prefs.setString('$_ticketKeyPrefix$id', jsonEncode(ticket));

    final ids = prefs.getStringList(_idsKey) ?? <String>[];
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setStringList(_idsKey, ids);
    }
  }

  /// Loads every cached ticket, preserving manifest order. Tickets whose JSON
  /// fails to parse are silently skipped so a single corrupt entry never
  /// blanks the whole wallet.
  Future<List<Map<String, dynamic>>> loadTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_idsKey) ?? <String>[];
    final tickets = <Map<String, dynamic>>[];
    for (final id in ids) {
      final raw = prefs.getString('$_ticketKeyPrefix$id');
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) tickets.add(decoded);
      } catch (_) {
        // Ignore malformed entries — they'll be overwritten on next sync.
      }
    }
    return tickets;
  }

  /// Removes a single ticket (and its manifest entry) from local storage.
  Future<void> clearTicket(String ticketId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_ticketKeyPrefix$ticketId');
    final ids = prefs.getStringList(_idsKey) ?? <String>[];
    if (ids.contains(ticketId)) {
      ids.remove(ticketId);
      await prefs.setStringList(_idsKey, ids);
    }
  }

  /// Returns a single cached ticket, or `null` if it isn't cached.
  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_ticketKeyPrefix$ticketId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Malformed entry — treat as a miss.
    }
    return null;
  }
}

/// Riverpod provider for [TicketCache].
final ticketCacheProvider = Provider<TicketCache>((ref) => TicketCache());
