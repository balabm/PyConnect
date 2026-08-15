import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../support/data/support_api.dart';
import '../data/admin_api.dart';
import '../data/admin_signalr_service.dart';

enum SurgeMode { normal, monsoon, festivalSurge }

final surgeModeProvider = StateNotifierProvider<SurgeModeNotifier, SurgeMode>(
  (ref) => SurgeModeNotifier(),
);

class SurgeModeNotifier extends StateNotifier<SurgeMode> {
  SurgeModeNotifier() : super(SurgeMode.normal);

  void setMode(SurgeMode mode) => state = mode;
}

// === Dashboard Stats (real API, refreshed every 15s) ===

final adminDashboardStatsProvider =
    StreamProvider<AdminDashboardStats>((ref) async* {
  final api = ref.watch(adminApiProvider);
  while (true) {
    try {
      yield await api.getDashboardStats();
    } catch (_) {
      yield AdminDashboardStats(
        totalUsers: 0, activeUsers: 0, totalDrivers: 0, approvedDrivers: 0,
        onlineDrivers: 0, activeRides: 0, activeSosAlerts: 0,
        openSupportTickets: 0, totalVendors: 0, approvedVendors: 0, totalVenues: 0,
      );
    }
    await Future.delayed(const Duration(seconds: 15));
  }
});

// === Vendors (real API, refreshed every 30s) ===

final adminVendorsProvider = StreamProvider<List<AdminVendor>>((ref) async* {
  final api = ref.watch(adminApiProvider);
  while (true) {
    try {
      yield await api.getVendors();
    } catch (_) {
      yield <AdminVendor>[];
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

// === Users (real API, on-demand with filters) ===

final adminUsersProvider =
    FutureProvider.family<AdminPagedResult<AdminUser>, AdminListParams>(
        (ref, params) async {
  final api = ref.watch(adminApiProvider);
  return api.getUsers(
    search: params.search,
    role: params.role,
    isActive: params.isActive,
    page: params.page,
    pageSize: params.pageSize,
  );
});

// === Drivers (real API, on-demand with filters) ===

final adminDriversProvider =
    FutureProvider.family<AdminPagedResult<AdminDriver>, AdminListParams>(
        (ref, params) async {
  final api = ref.watch(adminApiProvider);
  return api.getDrivers(
    search: params.search,
    isApproved: params.isApproved,
    isOnline: params.isOnline,
    kycUploadedOnly: params.kycUploadedOnly,
    page: params.page,
    pageSize: params.pageSize,
  );
});

/// Live driver locations for map display — real data, refreshed every 10s.
final adminDriverLocationsProvider =
    StreamProvider<List<DriverLocation>>((ref) async* {
  final api = ref.watch(adminApiProvider);
  while (true) {
    try {
      final result = await api.getDrivers(page: 1, pageSize: 200);
      yield result.items
          .where((d) => d.latitude != null && d.longitude != null)
          .map((d) => DriverLocation(
                id: d.id,
                name: d.name,
                lat: d.latitude!,
                lng: d.longitude!,
                isOnline: d.isOnline,
              ))
          .toList();
    } catch (_) {
      yield <DriverLocation>[];
    }
    await Future.delayed(const Duration(seconds: 10));
  }
});

// === Active Rides (real API, refreshed every 10s) ===

final adminActiveRidesProvider =
    StreamProvider<List<AdminActiveRide>>((ref) async* {
  final api = ref.watch(adminApiProvider);
  while (true) {
    try {
      yield await api.getActiveRides();
    } catch (_) {
      yield <AdminActiveRide>[];
    }
    await Future.delayed(const Duration(seconds: 10));
  }
});

// === Active Food Deliveries (for admin live ops map) ===

final adminActiveDeliveriesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final api = ref.watch(adminApiProvider);
  while (true) {
    try {
      yield await api.getActiveDeliveries();
    } catch (_) {
      yield <Map<String, dynamic>>[];
    }
    await Future.delayed(const Duration(seconds: 10));
  }
});

// === SOS Alerts (real API, refreshed every 10s) ===

final adminSosAlertsProvider =
    StreamProvider<List<AdminSosAlert>>((ref) async* {
  final api = ref.watch(adminApiProvider);
  while (true) {
    try {
      yield await api.getActiveSosAlerts();
    } catch (_) {
      yield <AdminSosAlert>[];
    }
    await Future.delayed(const Duration(seconds: 10));
  }
});

/// Legacy SOS events provider — kept for backward compatibility.
final adminSosEventsProvider = StreamProvider<List<AdminSosEvent>>((ref) async* {
  while (true) {
    try {
      final api = ref.read(adminApiProvider);
      yield await api.getSosEvents();
    } catch (_) {
      yield [];
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

// === Support Tickets (real API, on-demand with filters) ===

final adminSupportTicketsProvider =
    FutureProvider.family<AdminPagedResult<AdminSupportTicket>, AdminTicketParams>(
        (ref, params) async {
  final api = ref.watch(adminApiProvider);
  return api.getSupportTickets(
    status: params.status,
    page: params.page,
    pageSize: params.pageSize,
  );
});

// === Action Logs (real API, on-demand with filters) ===

final adminActionLogsProvider =
    FutureProvider.family<AdminPagedResult<AdminActionLog>, AdminLogParams>(
        (ref, params) async {
  final api = ref.watch(adminApiProvider);
  return api.getActionLogs(
    actionType: params.actionType,
    adminUserId: params.adminUserId,
    page: params.page,
    pageSize: params.pageSize,
  );
});

// === Legacy venue status provider — mapped from real vendor data ===

final adminVenueStatusProvider = StreamProvider<List<AdminVenueStatus>>((ref) async* {
  while (true) {
    try {
      final api = ref.read(adminApiProvider);
      final vendors = await api.getVendors();
      yield vendors
          .where((v) => v.isActive)
          .map((v) => AdminVenueStatus(
                name: v.name,
                currentCapacity: 0,
                maxCapacity: 100,
                isForceSoldOut: !v.isApproved,
              ))
          .toList();
    } catch (_) {
      yield [];
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

/// Real-time SignalR connection for the admin dashboard.
/// Connects to /hubs/admin and emits typed events that trigger provider
/// invalidation for instant UI updates. Falls back gracefully if the
/// connection fails — polling providers continue to refresh data.
final adminSignalRProvider = StreamProvider<AdminSignalREvent>((ref) async* {
  final token = ref.read(authTokenProvider);
  if (token == null || token.isEmpty) {
    yield* const Stream<AdminSignalREvent>.empty();
    return;
  }

  final service = await AdminSignalRService.connect(
    baseUrl: AppConfig.apiBaseUrl,
    authToken: token,
  );

  // Route events to the unified stream.
  yield* service.events;

  // Keep the service alive until the provider is disposed.
  ref.onDispose(() => service.dispose());
});

/// Side-effect provider that listens to SignalR events and invalidates
/// the relevant data providers for instant UI refresh. Must be watched
/// from the admin shell to keep the subscription alive.
final adminSignalREventHandlerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AdminSignalREvent>>(adminSignalRProvider, (_, next) {
    next.whenData((event) {
      // Add critical tickets to the notifier.
      if (event.type == 'CriticalTicketPushed' && event.payload != null) {
        try {
          ref
              .read(criticalTicketsProvider.notifier)
              .addTicket(CriticalTicketModel.fromJson(event.payload!));
        } catch (_) {}
      }

      // Invalidate relevant providers based on event category.
      if (event.affectsStats) {
        ref.invalidate(adminDashboardStatsProvider);
      }
      if (event.affectsSos) {
        ref.invalidate(adminSosAlertsProvider);
      }
      if (event.affectsTickets) {
        ref.invalidate(adminSupportTicketsProvider);
      }
      if (event.affectsRides) {
        ref.invalidate(adminActiveRidesProvider);
      }
      if (event.affectsVendors) {
        ref.invalidate(adminVendorsProvider);
      }
      if (event.affectsDrivers) {
        // Invalidate all driver list queries.
        ref.invalidate(adminDriversProvider);
        ref.invalidate(adminDriverLocationsProvider);
      }
      if (event.affectsUsers) {
        ref.invalidate(adminUsersProvider);
      }
    });
  });
});

final criticalTicketsProvider =
    StateNotifierProvider<CriticalTicketsNotifier, List<CriticalTicketModel>>(
  (ref) => CriticalTicketsNotifier(),
);

class CriticalTicketsNotifier extends StateNotifier<List<CriticalTicketModel>> {
  CriticalTicketsNotifier() : super([]);

  void addTicket(CriticalTicketModel ticket) {
    state = [ticket, ...state];
  }

  void acknowledge(String ticketId) {
    state = state.where((t) => t.id != ticketId).toList();
  }

  void clear() => state = [];
}

final hasUnacknowledgedCriticalProvider = Provider<bool>((ref) {
  return ref.watch(criticalTicketsProvider).isNotEmpty;
});

// === Parameter classes for family providers ===

class AdminListParams {
  const AdminListParams({
    this.search,
    this.role,
    this.isActive,
    this.isApproved,
    this.isOnline,
    this.kycUploadedOnly = false,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? search;
  final String? role;
  final bool? isActive;
  final bool? isApproved;
  final bool? isOnline;
  final bool kycUploadedOnly;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminListParams &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          role == other.role &&
          isActive == other.isActive &&
          isApproved == other.isApproved &&
          isOnline == other.isOnline &&
          kycUploadedOnly == other.kycUploadedOnly &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode =>
      Object.hash(search, role, isActive, isApproved, isOnline,
          kycUploadedOnly, page, pageSize);
}

class AdminTicketParams {
  const AdminTicketParams({
    this.status,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? status;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminTicketParams &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(status, page, pageSize);
}

class AdminLogParams {
  const AdminLogParams({
    this.actionType,
    this.adminUserId,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? actionType;
  final String? adminUserId;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminLogParams &&
          runtimeType == other.runtimeType &&
          actionType == other.actionType &&
          adminUserId == other.adminUserId &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(actionType, adminUserId, page, pageSize);
}

// === Legacy model classes kept for existing widgets ===

class AdminOrder {
  final String id;
  final String type;
  final String status;
  final double amount;
  final String customer;
  final DateTime timestamp;

  AdminOrder({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.customer,
    required this.timestamp,
  });
}

class AdminVenueStatus {
  final String name;
  final int currentCapacity;
  final int maxCapacity;
  final bool isForceSoldOut;

  AdminVenueStatus({
    required this.name,
    required this.currentCapacity,
    required this.maxCapacity,
    required this.isForceSoldOut,
  });

  double get fillPercent => maxCapacity > 0 ? currentCapacity / maxCapacity : 0;
}

class DriverLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final bool isOnline;

  DriverLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.isOnline,
  });
}

class SosEvent {
  final String id;
  final String userName;
  final String message;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final bool isResolved;

  SosEvent({
    required this.id,
    required this.userName,
    required this.message,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.isResolved,
  });
}

// === Finance ===

final adminFinanceSummaryProvider =
    FutureProvider.autoDispose<AdminFinanceSummary>((ref) async {
  final api = ref.watch(adminApiProvider);
  return await api.getFinanceSummary();
});

final adminSettlementsProvider =
    FutureProvider.autoDispose<List<AdminSettlementLog>>((ref) async {
  final api = ref.watch(adminApiProvider);
  return await api.getSettlements();
});
