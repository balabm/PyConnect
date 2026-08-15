# PY Connect — Mobile Apps

Flutter 3.x mobile applications for the PY Connect super-app (Pondicherry, India).

## Three Apps

| App | Entry Point | Application ID | Flavor | Purpose |
|-----|------------|----------------|--------|---------|
| **Consumer** | `lib/main.dart` | `com.pondyconnect.app` | `consumer` | Ride-hailing, food delivery, venues, transit, luggage, rentals, homestays |
| **Driver/Captain** | `lib/main_driver.dart` | `com.pondyconnect.driver` | `driver` | Ride acceptance, navigation, earnings, wallet, KYC |
| **Partner** | `lib/main_partner.dart` | `com.pondyconnect.partner` | `partner` | Vendor management (restaurants, cafes, pubs, rentals, luggage, taxi) |

## Tech Stack

- **Framework**: Flutter 3.x (Dart)
- **State Management**: Riverpod 2.x
- **Navigation**: GoRouter 17.x
- **HTTP Client**: Dio 5.x
- **Real-time**: signalr_netcore
- **Maps**: flutter_map 7.x + OpenStreetMap
- **Secure Storage**: flutter_secure_storage
- **Scanner**: mobile_scanner 5.x

## Project Structure

```
mobile/lib/
├── core/           # Design system, network, providers, theme, storage, config
│   ├── config/     # app_config.dart — API base URL configuration
│   ├── network/    # api_client.dart — Dio HTTP client with auth interceptor
│   ├── providers.dart  # Riverpod providers + SignalR connections
│   └── theme/      # AppTheme, colors, typography
├── features/       # 18 feature modules
│   ├── auth/       # OTP login, phone entry, profile
│   ├── rides/      # Ride-hailing UI, driver tracking, SOS
│   ├── food/       # Food delivery, menu browsing, cart
│   ├── venues/     # Nightlife/dining venue list + detail + booking
│   ├── transit/    # Transit trips, luggage cloak, scooter rentals
│   ├── vendor/     # Partner app — vendor onboarding, dashboard, KDS
│   ├── driver/     # Driver app — registration, online/offline, ride accept
│   ├── admin/      # Admin app — user/vendor/driver management
│   └── ...
├── router/         # GoRouter configuration per app
├── shell/          # HomeShell (bottom nav)
└── app.dart        # MaterialApp.router root
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

- Product flavors defined in `android/app/build.gradle.kts`
- MainActivity: `com.pondyconnect.pondyconnect.MainActivity`
- Min SDK, target SDK, and compile SDK configured in `android/app/build.gradle.kts`
