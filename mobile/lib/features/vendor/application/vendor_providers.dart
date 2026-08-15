import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/vendor_dashboard_api.dart';
import '../data/kds_api.dart';
import '../../scanner/data/scanner_api.dart';

final vendorDashboardApiProvider = Provider<VendorDashboardApi>((ref) {
  return VendorDashboardApi(ref.read(apiClientProvider));
});

final kdsApiProvider = Provider<KdsApi>((ref) {
  return KdsApi(ref.read(apiClientProvider));
});

final scannerApiProvider = Provider<ScannerApi>((ref) {
  return ScannerApi(ref.read(apiClientProvider));
});

final vendorMenuProvider =
    StateNotifierProvider<VendorMenuNotifier, AsyncValue<List<MenuItemModel>>>(
  (ref) => VendorMenuNotifier(ref),
);

class VendorMenuNotifier extends StateNotifier<AsyncValue<List<MenuItemModel>>> {
  VendorMenuNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final items = await api.getMenu();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createItem(CreateMenuItemPayload payload) async {
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final item = await api.createMenuItem(payload);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, item]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleItem(String id) async {
    final api = _ref.read(vendorDashboardApiProvider);
    await api.toggleMenuItem(id);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current
          .map((item) =>
              item.id == id ? MenuItemModel(
                id: item.id,
                name: item.name,
                price: item.price,
                category: item.category,
                isAvailable: !item.isAvailable,
                description: item.description,
                imageUrl: item.imageUrl,
                isLateNight: item.isLateNight,
                isVeg: item.isVeg,
                prepTimeMinutes: item.prepTimeMinutes,
              ) : item)
          .toList(),
    );
  }

  Future<void> updateItem(String id, UpdateMenuItemPayload payload) async {
    final api = _ref.read(vendorDashboardApiProvider);
    await api.updateMenuItem(id, payload);
    await load();
  }

  Future<void> deleteItem(String id) async {
    final api = _ref.read(vendorDashboardApiProvider);
    await api.toggleMenuItem(id);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((item) => item.id != id).toList());
  }
}

final vendorPromotionsProvider =
    StateNotifierProvider<VendorPromotionsNotifier, AsyncValue<List<VendorPromotionModel>>>(
  (ref) => VendorPromotionsNotifier(ref),
);

class VendorPromotionsNotifier
    extends StateNotifier<AsyncValue<List<VendorPromotionModel>>> {
  VendorPromotionsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final promos = await api.getPromotions();
      state = AsyncValue.data(promos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createPromotion(CreatePromotionPayload payload) async {
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final promo = await api.createPromotion(payload);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, promo]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final vendorFlashPromosProvider =
    StateNotifierProvider<VendorFlashPromosNotifier, AsyncValue<List<FlashPromoModel>>>(
  (ref) => VendorFlashPromosNotifier(ref),
);

class VendorFlashPromosNotifier
    extends StateNotifier<AsyncValue<List<FlashPromoModel>>> {
  VendorFlashPromosNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final promos = await api.getFlashPromos();
      state = AsyncValue.data(promos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createFlashPromo(CreateFlashPromoPayload payload) async {
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final promo = await api.createFlashPromo(payload);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, promo]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final vendorAcceptingOrdersProvider = StateProvider<bool>((ref) => true);

/// Fetches the vendor's venue list to resolve the real venue ID.
final vendorVenuesProvider =
    FutureProvider<List<VendorVenueSummary>>((ref) async {
  final api = ref.read(vendorDashboardApiProvider);
  return api.getVenues();
});

// ── Vendor Orders ──

final vendorOrdersProvider =
    StateNotifierProvider<VendorOrdersNotifier, AsyncValue<List<VendorOrderModel>>>(
  (ref) => VendorOrdersNotifier(ref),
);

class VendorOrdersNotifier extends StateNotifier<AsyncValue<List<VendorOrderModel>>> {
  VendorOrdersNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final orders = await api.getOrders();
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      await api.updateOrderStatus(orderId, newStatus);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((o) => o.id == orderId
            ? VendorOrderModel(
                id: o.id,
                vendorName: o.vendorName,
                status: newStatus,
                totalAmount: o.totalAmount,
                placedAt: o.placedAt,
              )
            : o).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ── Venue Detail ──

final venueDetailProvider =
    StateNotifierProvider<VenueDetailNotifier, AsyncValue<VendorVenueDetail?>>(
  (ref) => VenueDetailNotifier(ref),
);

class VenueDetailNotifier extends StateNotifier<AsyncValue<VendorVenueDetail?>> {
  VenueDetailNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final venues = await api.getVenues();
      if (venues.isNotEmpty) {
        state = AsyncValue.data(VendorVenueDetail(
          venueId: venues.first.venueId,
          name: venues.first.name,
          category: venues.first.category,
          isActive: venues.first.isActive,
        ));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(UpdateVenuePayload payload) async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      await api.updateVenue(current.venueId, payload);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ── Vendor Bookings (all service types) ──

final vendorBookingsProvider =
    StateNotifierProvider<VendorBookingsNotifier, AsyncValue<List<BookingSummary>>>(
  (ref) => VendorBookingsNotifier(ref),
);

class VendorBookingsNotifier extends StateNotifier<AsyncValue<List<BookingSummary>>> {
  VendorBookingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      final bookings = await api.getBookings();
      state = AsyncValue.data(bookings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStatus(String bookingId, String serviceType, String newStatus) async {
    try {
      final api = _ref.read(vendorDashboardApiProvider);
      await api.updateBookingStatus(bookingId, serviceType, newStatus);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((b) => b.bookingId == bookingId
            ? BookingSummary(
                bookingId: b.bookingId,
                serviceType: b.serviceType,
                customerName: b.customerName,
                scheduledFor: b.scheduledFor,
                status: newStatus,
                amount: b.amount,
                paymentStatus: b.paymentStatus,
              )
            : b).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ── Wallet ──

final vendorWalletProvider =
    FutureProvider<VendorWalletModel>((ref) async {
  final api = ref.read(vendorDashboardApiProvider);
  return api.getWallet();
});

final vendorWalletTransactionsProvider =
    FutureProvider<List<WalletTransactionModel>>((ref) async {
  final api = ref.read(vendorDashboardApiProvider);
  return api.getWalletTransactions();
});
