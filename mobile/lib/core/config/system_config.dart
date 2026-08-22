import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// System configuration (kill switches) fetched from the backend.
/// These toggles allow the app to gracefully degrade during
/// 3rd-party API outages (Razorpay, Google Maps, etc.).
class SystemConfig {
  final bool isRazorpayActive;
  final bool isGoogleMapsActive;
  final bool isFoodDeliveryActive;
  final bool isRideHailingActive;
  final bool isStaysActive;
  final bool isLuggageCloakActive;
  final bool isScooterRentalActive;
  final bool isNightlifeActive;

  const SystemConfig({
    this.isRazorpayActive = true,
    this.isGoogleMapsActive = true,
    this.isFoodDeliveryActive = true,
    this.isRideHailingActive = true,
    this.isStaysActive = true,
    this.isLuggageCloakActive = true,
    this.isScooterRentalActive = true,
    this.isNightlifeActive = true,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    final toggles = (json['toggles'] as Map<String, dynamic>?) ?? {};
    return SystemConfig(
      isRazorpayActive: toggles['IsRazorpayActive'] as bool? ?? true,
      isGoogleMapsActive: toggles['IsGoogleMapsActive'] as bool? ?? true,
      isFoodDeliveryActive: toggles['IsFoodDeliveryActive'] as bool? ?? true,
      isRideHailingActive: toggles['IsRideHailingActive'] as bool? ?? true,
      isStaysActive: toggles['IsStaysActive'] as bool? ?? true,
      isLuggageCloakActive: toggles['IsLuggageCloakActive'] as bool? ?? true,
      isScooterRentalActive: toggles['IsScooterRentalActive'] as bool? ?? true,
      isNightlifeActive: toggles['IsNightlifeActive'] as bool? ?? true,
    );
  }
}

/// Provider that fetches the system config from the backend.
/// Falls back to all-true (everything active) on network errors.
final systemConfigProvider = FutureProvider<SystemConfig>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('/api/system-config');
    return SystemConfig.fromJson(response as Map<String, dynamic>);
  } on DioException catch (_) {
    // Network error — default to everything active.
    // The app continues to work normally; if a 3rd-party API is
    // actually down, the individual API calls will fail and be
    // handled by their respective error handlers.
    return const SystemConfig();
  }
});
