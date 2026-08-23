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
- **GitHub Actions**: 4 workflows in `.github/workflows/` (see CI/CD section below)
- **GitHub Secrets**: 12/12 configured (see CI/CD section below)
- Backend deploys to EC2 via Docker (automated via `deploy-backend.yml`)
- Web apps deploy to EC2 via SCP + Nginx (automated via `deploy-web.yml`)
- Nginx reverse proxy config in `deploy/nginx.conf` (WebSocket forwarding for `/hubs/`, security headers, rate limiting)
- Production secrets via environment variables (JWT signing key, DB credentials, Razorpay keys)
- **See `DEPLOYMENT.md` for the complete step-by-step go-live checklist**
- `.env.example` in `backend/` provides the template for production env vars

## CI/CD

### Workflows (4)
| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PR + push to main | Backend build + architecture tests + mobile analyze (parallel jobs) |
| `deploy-backend.yml` | Push to main (backend changes) | Docker → Docker Hub → EC2 → health check |
| `deploy-web.yml` | Push to main (mobile changes) | Flutter web → SCP to EC2 → Nginx reload |
| `release.yml` | Tag push `v*` | Signed APK + AAB builds → GitHub artifacts |

### GitHub Secrets (12/12 configured)
`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY`, `API_BASE_URL`, `KEYSTORE_BASE64`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, `GOOGLE_SERVICES_JSON`, `RAZORPAY_KEY_ID`

### Branch Protection (Recommended)
Require `CI` status checks before merging PRs to `main`.

## Deployment Status

| Component | Status | Details |
|-----------|--------|---------|
| Web Admin | ✅ Deployed & Verified | https://pyconnect.run.place/ (Admin app at root) |
| Web Partner | ✅ Deployed & Verified | https://pyconnect.run.place/partner/ |
| Backend | ✅ Deployed & Healthy | Docker container on EC2, PostgreSQL on RDS |
| Mobile APKs | ✅ Built Locally | 76.5 MB each (Consumer, Driver, Partner) |
| Git Repo | ✅ Pushed | https://github.com/balabm/PyConnect.git |
| GitHub Secrets | ✅ 12/12 Configured | All deployment secrets set |

## EC2 Instance Configuration

### Host
- **IP**: `16.16.120.192`
- **SSH user**: `ubuntu`
- **SSH key**: `s1bucket.pem` (stored locally, not in repo)
- **OS**: Ubuntu 24.04 (AWS t-series EC2)
- **Domain**: `pyconnect.run.place` (Let's Encrypt TLS via Certbot)

### Nginx (reverse proxy + static serving)
- **Config**: `/etc/nginx/sites-enabled/pondyconnect` (symlinked from sites-available)
- **WebSocket map**: `/etc/nginx/conf.d/websocket.conf` (defines `$connection_upgrade`)
- **TLS**: Certbot-managed (`/etc/letsencrypt/live/pyconnect.run.place/`)
- **HTTP→HTTPS**: Automatic 301 redirect on port 80

### Route mapping
| Path | Serves |
|------|--------|
| `/` | Admin Flutter web app (`/var/www/admin/`) |
| `/partner/` | Partner Flutter web app (`/var/www/partner/`) |
| `/api/` | Backend proxy → `localhost:5000` |
| `/hubs/` | SignalR WebSocket proxy → `localhost:5000` |
| `/health` | Backend health check |
| `/admin` | 301 redirect → `/` |
| `/vendor` | 301 redirect → `/partner/` |
| `/privacy-policy` | Static HTML (`/var/www/static/privacy-policy.html`) |

### Backend (Docker)
- **Container**: `pondyconnect_api` (image: `balabm/pondyconnect-api:latest`)
- **Port mapping**: `5000 → 8080` (host → container)
- **Database**: PostgreSQL on AWS RDS (`pyconnect.ch2i68eyk0ii.eu-north-1.rds.amazonaws.com`)
- **Cache**: Redis container (`pondyconnect-redis`, `redis:7-alpine`)
- **SMS**: Console provider (mock mode)
- **Storage**: Mock mode (no S3/real blob storage)
- **Payments**: Razorpay test keys configured
- **Health**: `GET /health` returns Healthy (database, signalr, redis checks)

### Web app directories on EC2
- `/var/www/admin/` — Admin Flutter web build (base href `/`)
- `/var/www/partner/` — Partner Flutter web build (base href `/partner/`)
- `/var/www/static/` — Static pages (privacy policy)

### Deploy web apps manually
```bash
# Build admin locally
cd mobile
flutter build web --target lib/main_admin.dart --dart-define=API_BASE_URL=https://pyconnect.run.place --dart-define=APP_FLAVOR=admin --release

# Deploy admin
ssh -i s1bucket.pem ubuntu@16.16.120.192 "sudo rm -rf /var/www/admin/* && mkdir -p /tmp/admin-web"
scp -i s1bucket.pem -r mobile/build/web/* ubuntu@16.16.120.192:/tmp/admin-web/
ssh -i s1bucket.pem ubuntu@16.16.120.192 "sudo cp -r /tmp/admin-web/* /var/www/admin/ && sudo chown -R www-data:www-data /var/www/admin/ && sudo chmod -R a+rX /var/www/admin/ && rm -rf /tmp/admin-web"

# Build partner (overwrites build/web)
flutter build web --target lib/main_partner.dart --dart-define=API_BASE_URL=https://pyconnect.run.place --dart-define=APP_FLAVOR=partner --release --base-href /partner/

# Deploy partner
ssh -i s1bucket.pem ubuntu@16.16.120.192 "sudo rm -rf /var/www/partner/* && mkdir -p /tmp/partner-web"
scp -i s1bucket.pem -r mobile/build/web/* ubuntu@16.16.120.192:/tmp/partner-web/
ssh -i s1bucket.pem ubuntu@16.16.120.192 "sudo cp -r /tmp/partner-web/* /var/www/partner/ && sudo chown -R www-data:www-data /var/www/partner/ && sudo chmod -R a+rX /var/www/partner/ && rm -rf /tmp/partner-web && sudo systemctl reload nginx"
```

### Known EC2 config issues
- **CORS origins**: ✅ Fixed — `Cors__AllowedOrigins__0=https://pyconnect.run.place` (verified in container env).
- **JWT issuer/audience**: ✅ Fixed — `Jwt__Issuer` and `Jwt__Audience` both `https://pyconnect.run.place` (verified via freshly minted token payload). Container was recreated ~2026-08-15; existing browser tokens minted with the old `http://16.16.120.192` issuer are rejected with 401 — users must log out and back in once to get a valid token.

## QA Status (Local)
- **Backend build**: 0 errors, 0 warnings
- **Architecture tests**: 288/288 pass
- **Flutter analyze**: 0 errors (28 info/warnings — pre-existing, non-blocking)
- **Release APKs**: 3 built (Consumer, Driver, Partner — 76.5 MB each)
- **Web apps**: Admin + Partner deployed & verified on EC2

## Testing Notes
- Integration tests (`PondyConnect.Api.Tests`) hit the deployed backend and may fail with 429 (rate limiting).
- Architecture tests (`PondyConnect.Architecture.Tests`) are self-contained and should always pass (288 tests).
- OTP can be peeked via `GET /api/auth/otp/peek?phone=...` (dev only, blocked in production).
