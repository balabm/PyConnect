# PY Connect — Mobile Apps

Flutter 3.x mobile applications for the PY Connect super-app (Pondicherry, India).

## Apps

### Mobile Apps (3)

| App | Entry Point | Application ID | Flavor | Purpose |
|-----|------------|----------------|--------|---------|
| **Consumer** | `lib/main.dart` | `com.pondyconnect.app` | `consumer` | Ride-hailing, food delivery, venues, transit, luggage, rentals, homestays |
| **Driver/Captain** | `lib/main_driver.dart` | `com.pondyconnect.driver` | `driver` | Ride acceptance, navigation, earnings, wallet, KYC |
| **Partner** | `lib/main_partner.dart` | `com.pondyconnect.partner` | `partner` | Category-aware vendor management (7 business types) |

### Web Apps (2)

| App | Entry Point | Base Href | Deploy Path | URL |
|-----|------------|-----------|-------------|-----|
| **Admin** | `lib/main_admin.dart` | `/` | `/var/www/admin/` | https://pyconnect.run.place/ |
| **Partner** | `lib/main_partner.dart` | `/partner/` | `/var/www/partner/` | https://pyconnect.run.place/partner/ |

> **Note**: The redundant `vendor` flavor has been removed. The Partner app handles all vendor categories.

## Partner App Categories

The Partner app adapts its navigation and screens based on the vendor's `VendorCategory`:

| Category | Description | Category-Specific Screens |
|----------|-------------|--------------------------|
| LuggageCloak | Luggage storage service | `cloak_capacity_screen.dart` |
| ScooterRental | Scooter rental service | `fleet_management_screen.dart`, `active_rentals_screen.dart` |
| TaxiOperator | Taxi fleet operator | `taxi_fleet_screen.dart`, `taxi_rides_screen.dart` |
| PubClub | Pub/club venue | `drinks_menu_screen.dart` |
| Restaurant | Restaurant | `vendor_menu_screen.dart`, `kitchen_display_screen.dart` |
| Cafe | Cafe | `vendor_menu_screen.dart`, `kitchen_display_screen.dart` |
| Pizzeria | Pizzeria | `vendor_menu_screen.dart`, `kitchen_display_screen.dart` |

### Category-Aware Navigation

| Category | Tab 1 | Tab 2 | Tab 3 | Tab 4 | Tab 5 |
|----------|-------|-------|-------|-------|-------|
| Restaurant/Cafe/Pizzeria | Dashboard | KDS | Menu | Scanner | Manage |
| PubClub | Dashboard | KDS | Drinks Menu | Scanner | Manage |
| ScooterRental | Dashboard | Fleet | Rentals | Scanner | Manage |
| TaxiOperator | Dashboard | Fleet | Rides | Scanner | Manage |
| LuggageCloak | Dashboard | Capacity | Bookings | Scanner | Manage |

## Tech Stack

- **Framework**: Flutter 3.x (Dart)
- **State Management**: Riverpod 2.x
- **Navigation**: GoRouter 17.x
- **HTTP Client**: Dio 5.x
- **Real-time**: signalr_netcore
- **Maps**: flutter_map 7.x + OpenStreetMap
- **Secure Storage**: flutter_secure_storage
- **Scanner**: mobile_scanner 5.x

## Theme System

### AppTheme — Semantic Colors

All screens use theme-aware semantic colors instead of hardcoded Material colors:

| Color | Hex | Usage |
|-------|-----|-------|
| `AppTheme.lagoon` | `0xFF0D9488` | Primary teal — buttons, accents |
| `AppTheme.coral` | `0xFFF97316` | Orange accent — highlights |
| `AppTheme.success` | `0xFF22C55E` | Success states, online indicators |
| `AppTheme.danger` | `0xFFEF4444` | Error states, SOS, delete |
| `AppTheme.warning` | `0xFFF59E0B` | Warning states, amber badges |
| `AppTheme.info` | `0xFF3B82F6` | Info states, blue indicators |
| `AppTheme.darkBackground` | `0xFF0F172A` | Partner app scaffold |
| `AppTheme.darkSurface` | `0xFF1E293B` | Partner app cards |

### AdminColors — Dark SaaS Palette

The Admin web app uses a dedicated dark palette:

| Color | Hex | Usage |
|-------|-----|-------|
| `AdminColors.bg` | `0xFF0B0F19` | Admin scaffold |
| `AdminColors.surface` | `0xFF111827` | Cards, panels |
| `AdminColors.textPrimary` | `0xFFF9FAFB` | Primary text |
| `AdminColors.textMuted` | `0xFF9CA3AF` | Secondary text |
| `AdminColors.accent` | `0xFF0D9488` | Primary actions |
| `AdminColors.danger` | `0xFFEF4444` | Destructive actions |
| `AdminColors.success` | `0xFF22C55E` | Success |
| `AdminColors.warning` | `0xFFF59E0B` | Warning |

> **Note**: All 329+ hardcoded `Colors.grey` instances have been eliminated. All `Colors.red/green/amber/blue` replaced with semantic `AppTheme.*` or `AdminColors.*` equivalents.

## Project Structure

```
mobile/lib/
├── core/               # Design system, network, providers, theme, storage, config
│   ├── config/         # app_config.dart — API base URL configuration
│   ├── network/        # api_client.dart — Dio HTTP client with auth interceptor
│   ├── providers.dart  # Riverpod providers + SignalR connections
│   └── theme/          # AppTheme (semantic colors), AdminColors, dark theme
├── features/           # 18 feature modules
│   ├── auth/           # OTP login, phone entry, profile
│   ├── rides/          # Ride-hailing UI, driver tracking, SOS
│   ├── food/           # Food delivery, menu browsing, cart
│   ├── venues/         # Nightlife/dining venue list + detail + booking
│   ├── transit/        # Transit trips, luggage cloak, scooter rentals
│   ├── vendor/         # Partner app — vendor onboarding, dashboard, KDS
│   ├── driver/         # Driver app — registration, online/offline, ride accept
│   ├── admin/          # Admin web app — user/vendor/driver management
│   └── ...
├── router/             # GoRouter configuration per app (app, driver, partner, admin)
├── shell/              # HomeShell, PartnerShell, DriverShell (bottom nav)
├── main.dart           # Consumer entry point
├── main_driver.dart    # Driver entry point
├── main_partner.dart   # Partner entry point
├── main_admin.dart     # Admin web entry point
└── app.dart            # MaterialApp.router root
```

## Build Commands

### Prerequisites
```powershell
flutter pub get
```

### Debug Builds
```powershell
flutter run --flavor consumer --target lib/main.dart
flutter run --flavor driver --target lib/main_driver.dart
flutter run --flavor partner --target lib/main_partner.dart
```

### Release APKs
```powershell
flutter build apk --flavor consumer --target lib/main.dart --release
flutter build apk --flavor driver --target lib/main_driver.dart --release
flutter build apk --flavor partner --target lib/main_partner.dart --release
```

### Web App Builds
```powershell
# Admin web app
flutter build web --target lib/main_admin.dart --dart-define=APP_FLAVOR=admin --release

# Partner web app (with base-href for /partner/ subdirectory)
flutter build web --target lib/main_partner.dart --dart-define=APP_FLAVOR=partner --release --base-href /partner/
```

Web apps are deployed to:
- Admin: `/var/www/admin/` → https://pyconnect.run.place/
- Partner: `/var/www/partner/` → https://pyconnect.run.place/partner/

### Static Analysis
```powershell
flutter analyze
```

## API Configuration

The API base URL is configured via environment variable or defaults to the deployed backend:

- **Production**: `https://pyconnect.run.place`
- **Local dev**: `http://localhost:5000`

See `lib/core/config/app_config.dart` for details.

## Authentication

- OTP-based login (phone number → OTP → JWT)
- JWT stored in flutter_secure_storage
- Auth interceptor adds Bearer token to all API requests
- Vendor auth uses separate endpoint (`/api/vendor/auth/otp/verify`)

## SignalR Real-time

- Ride hub: `/hubs/ride` — ride status updates for consumers
- Driver hub: `/hubs/driver` — ride offers and location updates for drivers
- Admin hub: `/hubs/admin` — dispatch monitoring

## Maps

Uses OpenStreetMap via flutter_map (no Google Maps API key required). Road-based routing is provided by the backend's OSRM integration.

## Android Configuration

- Product flavors: `consumer`, `driver`, `partner` (no `vendor` flavor — removed)
- MainActivity: `com.pondyconnect.pondyconnect.MainActivity`
- Min SDK, target SDK, and compile SDK configured in `android/app/build.gradle.kts`
- `usesCleartextTraffic` set to `false` (HTTPS only in production)
- `.env` files are NOT bundled in APK assets (removed from pubspec.yaml)
- Release signing: keystore configured via `key.properties` (excluded from git)
- Google Services: `google-services.json` excluded from git, injected via CI/CD secrets
