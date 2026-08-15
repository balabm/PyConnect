# PY Connect (PondyConnect) — Agent Guide

## Project Overview

PY Connect is a production-grade super-app for Pondicherry, India covering travel, mobility, food, nightlife, local experiences, rentals, luggage services, and partner management. Three mobile apps (Consumer, Driver, Partner) + web admin.

## Repository

- **Root**: `C:\Users\balab\OneDrive\Documents\Projects\PY_Engine`
- **Backend**: `backend/` (.NET 8 clean architecture)
- **Mobile**: `mobile/` (Flutter 3.x)
- **E2E**: `e2e/` (Playwright)
- **Deployed**: `https://pyconnect.run.place`

## Build & Test Commands

### Backend
```powershell
cd backend
dotnet build                    # Build all projects
dotnet test --filter "FullyQualifiedName~Architecture"  # 288 architecture tests
dotnet test                     # All tests (integration tests hit deployed backend, may 429)
```

### Mobile
```powershell
cd mobile
flutter analyze                 # Static analysis
flutter build apk --flavor consumer --target lib/main.dart --release
flutter build apk --flavor driver --target lib/main_driver.dart --release
flutter build apk --flavor partner --target lib/main_partner.dart --release
```

## Architecture

### Backend Layers
- **Domain**: Entities, Enums, Value Objects (zero dependencies)
- **Application**: MediatR CQRS handlers, DTOs, services, FluentValidation
- **Infrastructure**: EF Core, Redis, Razorpay, OSRM, FCM
- **API**: Controllers, SignalR hubs, middleware, rate limiting

### Mobile Apps (exactly 3)
1. **Consumer** (`main.dart`, `com.pondyconnect.app`) — ride-hailing, food, venues, transit, stays
2. **Driver/Captain** (`main_driver.dart`, `com.pondyconnect.driver`) — ride acceptance, earnings, KYC
3. **Partner** (`main_partner.dart`, `com.pondyconnect.partner`) — adapts to vendor category (7 types)

A 4th web-only entry point `main_admin.dart` builds the Admin web app (not an Android app).

### Partner App Category-Specific Screens
- **PubClub**: `drinks_menu_screen.dart`
- **ScooterRental**: `fleet_management_screen.dart`, `active_rentals_screen.dart`
- **TaxiOperator**: `taxi_fleet_screen.dart`, `taxi_rides_screen.dart`
- **LuggageCloak**: `cloak_capacity_screen.dart`
- **Restaurant/Cafe/Pizzeria**: `vendor_menu_screen.dart`, `kitchen_display_screen.dart`

### Vendor Categories
`LuggageCloak=1, ScooterRental=2, TaxiOperator=3, PubClub=4, Restaurant=5, Cafe=6, Pizzeria=7`

## Key Conventions

### Security
- **Never trust client-provided IDs** for ownership. Derive vendorId/userId/driverId from JWT via `ICurrentUserService`.
- **Always validate ownership** before returning or mutating data (ride details, receipts, tickets, venue operations).
- **Admin operations** require `[Authorize(Roles = "Admin")]` at controller level.
- **Vendor operations** require `[Authorize(Roles = "Vendor")]` and resolve vendor from `_currentUser.Phone`.

### Error Handling
- Use `{ Message = "..." }` format (PascalCase) for error responses.
- Throw `InvalidOperationException` for domain rule violations.
- Throw `UnauthorizedAccessException` for auth/ownership failures.
- Throw `BookingConflictException` for capacity/conflict issues.

### State Transitions
- All entity mutations go through domain methods (no public setters).
- State transition validation is in the domain entity methods.
- `MarkUpdated()` is called on every mutation (for entities inheriting `BaseEntity`).

### API Design
- Controllers use `[ApiController]` and `[Route("api/...")]`.
- Swagger annotations with `[ProducesResponseType]` for all response types.
- Rate limiting: `AuthPolicy` (5/60s), `OrderPolicy` (10/60s).
- Service area validation: 3km radius around Pondicherry center (11.9356, 79.8301).

## Authentication
- JWT Bearer tokens (60-min access tokens).
- OTP via `POST /api/auth/otp` → `POST /api/auth/otp/verify`.
- Vendor auth: `POST /api/vendor/auth/otp/request` → `POST /api/vendor/auth/otp/verify` (uses `Phone`/`OtpCode` fields).
- `CurrentUserService` resolves UserId from `ClaimTypes.NameIdentifier`, Phone from `phone` claim, Role from `ClaimTypes.Role`.

## SignalR Hubs
- `/hubs/ride` — Rider-facing ride updates
- `/hubs/driver` — Driver-facing ride offers + location updates
- `/hubs/admin` — Admin dispatch monitoring

## Database
- **Dev**: SQLite (`backend/.env` or local)
- **Prod**: PostgreSQL
- **Cache**: Redis (optional, falls back to in-memory)
- EF Core migrations via `dotnet ef database update`

## Deployment
- **Git repo**: https://github.com/balabm/PyConnect.git (618 files, zero secrets tracked)
- **GitHub Actions**: 5 workflows in `.github/workflows/` (see CI/CD section below)
- **GitHub Secrets**: 12/12 configured (see CI/CD section below)
- Backend deploys to EC2 via Docker (automated via `deploy-backend.yml`)
- Web apps deploy to EC2 via SCP + Nginx (automated via `deploy-web.yml`)
- Nginx reverse proxy config in `deploy/nginx.conf` (WebSocket forwarding for `/hubs/`, security headers, rate limiting)
- Production secrets via environment variables (JWT signing key, DB credentials, Razorpay keys)
- **See `DEPLOYMENT.md` for the complete step-by-step go-live checklist**
- `.env.example` in `backend/` provides the template for production env vars

## CI/CD

### Workflows (5)
| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci-backend.yml` | PR + push to main | Build + 288 architecture tests |
| `ci-mobile.yml` | PR + push to main | Flutter static analysis |
| `deploy-backend.yml` | Push to main (backend changes) | Docker → Docker Hub → EC2 → health check |
| `deploy-web.yml` | Push to main (mobile changes) | Flutter web → SCP to EC2 → Nginx reload |
| `deploy-mobile.yml` | Tag push `v*` | Signed APK + AAB builds → GitHub artifacts |

### GitHub Secrets (12/12 configured)
`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY`, `API_BASE_URL`, `KEYSTORE_BASE64`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, `GOOGLE_SERVICES_JSON`, `RAZORPAY_KEY_ID`

### Branch Protection (Recommended)
Require `Backend CI` + `Mobile CI` status checks before merging PRs to `main`.

## Deployment Status

| Component | Status | Details |
|-----------|--------|---------|
| Web Admin | ✅ Deployed & Verified | https://pyconnect.run.place/ (200 OK, 2026-08-15) |
| Web Partner | ✅ Deployed & Verified | https://pyconnect.run.place/partner/ (200 OK, 2026-08-15) |
| Backend | ⏳ Pending Deployment | 90+ local fixes not yet deployed to EC2 |
| Mobile APKs | ✅ Built Locally | 76.4 MB each (debug-signed, not yet on Play Store) |
| Git Repo | ✅ Pushed | https://github.com/balabm/PyConnect.git |
| GitHub Secrets | ✅ 12/12 Configured | All deployment secrets set |

### Backend — Pending Deployment
The deployed backend at `https://pyconnect.run.place` does NOT have the local fixes. All 90+ fixes are committed locally and need deployment via `deploy-backend.yml` workflow. Key issues that will be resolved by deployment:
- Menu delete returns 405
- OTP not enforced on ride start
- Driver state stuck after ride completion
- Ride events not persisted
- Admin can change own role / deactivate self
- No one-active-ride-per-consumer constraint
- Vendor self-registration doesn't create User account
- IDOR vulnerabilities in support tickets, ride details, KYC access
- No ownership checks on ride lifecycle (start/complete/cancel)
- ReassignRide accessible to any authenticated user
- Priority ping credit double-spend race condition
- Client-provided userId accepted in luggage/rental/trip listings
- Admin SOS events returns mock data instead of real alerts
- Surge state lost on app restart
- No security event logging for auth/SOS/payments
- Missing input validation on nearby-drivers coordinates
- Missing Guid.Empty validation on domain entities

## QA Status (Local)
- **Backend build**: 0 errors, 0 warnings
- **Architecture tests**: 288/288 pass
- **API tests**: 84 pass, 76 fail (all due to 429 rate limiting from deployed backend)
- **Flutter analyze**: 0 errors (30 info/warnings — pre-existing, non-blocking)
- **Total fixes applied**: 100+ backend security + 330+ UI fixes across 4 QA rounds
- **Release APKs**: 3 built (Consumer, Driver, Partner — 76.4 MB each)
- **Web apps**: Admin + Partner deployed & verified on EC2

## Pre-Launch Audit Fixes (Round 4)
- OTP peek endpoint now explicitly blocked in production via `IHostEnvironment.IsDevelopment()` check
- HSTS enabled in production (`app.UseHsts()`)
- Forwarded headers middleware added (`X-Forwarded-For`, `X-Forwarded-Proto`) for Nginx reverse proxy
- CORS localhost entries removed from `docker-compose.prod.yml`
- `AllowedHosts` restricted from `*` to `pyconnect.run.place;localhost`
- Mobile API base URL now defaults to `https://pyconnect.run.place` in release builds
- Mobile `usesCleartextTraffic` set to `false` (HTTPS only)
- Mobile `.env` removed from pubspec assets (no longer bundled in APK)
- Mobile `.gitignore` updated to exclude `.env` files
- Nginx config added to repo at `deploy/nginx.conf` with WebSocket forwarding, security headers, and rate limiting

## UI Remediation (Round 5)
- Added semantic colors to AppTheme: `success` (#22C55E), `danger` (#EF4444), `warning` (#F59E0B), `info` (#3B82F6)
- Added dark theme constants: `darkBackground` (#0F172A), `darkSurface` (#1E293B)
- 330+ UI fixes across 67+ files (Consumer 28, Driver 6, Partner 18, Admin 15)
- Eliminated all hardcoded `Colors.grey` (was 329+ instances, now 0)
- Replaced `Colors.red/green/amber/blue` with `AppTheme.danger/success/warning/info`
- Fixed invisible text (dark-on-dark) in admin pagination, partner menu, partner promotions
- Fixed admin SOS phone button (was no-op, now launches `tel:` URI)
- All SnackBars now have `backgroundColor`
- All loading indicators now have visible theme colors

## 3-App Consolidation (Round 5)
- Removed redundant `vendor` Android flavor (was duplicate of `partner`)
- Deleted `main_vendor.dart` (identical to `main_partner.dart`)
- Partner app adapts to vendor category (7 categories with category-specific screens)
- Web deployment path changed from `/var/www/vendor/` to `/var/www/partner/`

## Git & CI/CD Setup (Round 5)
- Git repository initialized, 618 files committed to https://github.com/balabm/PyConnect.git
- Zero secrets tracked (verified: no .env, .pem, .jks, key.properties, google-services.json)
- 5 CI/CD workflows created (ci-backend, ci-mobile, deploy-backend, deploy-web, deploy-mobile)
- 12 GitHub secrets configured
- Web apps deployed to EC2 via SSH/SCP, verified at https://pyconnect.run.place/

## Testing Notes
- Integration tests (`PondyConnect.Api.Tests`) hit the deployed backend and may fail with 429 (rate limiting).
- Architecture tests (`PondyConnect.Architecture.Tests`) are self-contained and should always pass (288 tests).
- OTP can be peeked via `GET /api/auth/otp/peek?phone=...` (dev only).
