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
flutter build apk --flavor consumer --release  # Consumer app
flutter build apk --flavor driver --release    # Driver app
flutter build apk --flavor partner --release   # Partner app
```

## Architecture

### Backend Layers
- **Domain**: Entities, Enums, Value Objects (zero dependencies)
- **Application**: MediatR CQRS handlers, DTOs, services, FluentValidation
- **Infrastructure**: EF Core, Redis, Razorpay, OSRM, FCM
- **API**: Controllers, SignalR hubs, middleware, rate limiting

### Mobile Apps (exactly 3)
1. **Consumer** (`main.dart`, `com.pondyconnect.app`)
2. **Driver/Captain** (`main_driver.dart`, `com.pondyconnect.driver`)
3. **Partner** (`main_partner.dart`, `com.pondyconnect.partner`) — adapts to vendor category

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
- GitHub Actions workflows in `.github/workflows/`
- Backend deploys to EC2 via Docker
- Nginx reverse proxy config in `deploy/nginx.conf` (WebSocket forwarding for `/hubs/`, security headers, rate limiting)
- Production secrets via environment variables (JWT signing key, DB credentials, Razorpay keys)
- **See `DEPLOYMENT.md` for the complete step-by-step go-live checklist**
- `.env.example` in `backend/` provides the template for production env vars

## Known Issues (Deployed Backend)
The deployed backend at `https://pyconnect.run.place` does NOT have the local fixes. All 90+ fixes need deployment. Key deployed-only issues:
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
- **Build**: 0 errors, 0 warnings
- **Architecture tests**: 288/288 pass
- **API tests**: 84 pass, 76 fail (all due to 429 rate limiting from deployed backend)
- **Total fixes applied**: 100+ across 4 QA rounds (including final pre-launch audit)

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

## Testing Notes
- Integration tests (`PondyConnect.Api.Tests`) hit the deployed backend and may fail with 429 (rate limiting).
- Architecture tests (`PondyConnect.Architecture.Tests`) are self-contained and should always pass (288 tests).
- OTP can be peeked via `GET /api/auth/otp/peek?phone=...` (dev only).
