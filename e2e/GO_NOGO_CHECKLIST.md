# PondyConnect — Go/No-Go Checklist

Critical failure points to verify before and during E2E test runs.
Any **NO** on a RED item is a **NO-GO** — stop and fix before continuing.

---

## RED — Critical Blockers (Any NO = Stop)

### 1. CORS Configuration
- [ ] **GO** Backend CORS policy `MobileClient` allows all origins in Development
- [ ] **GO** Flutter web app at `http://localhost:8090` can reach `http://localhost:5000` without CORS errors
- [ ] **GO** SignalR hub endpoints (`/hubs/driver`, `/hubs/ride`, `/hubs/admin`) allow cross-origin connections
- [ ] **GO** No `Access-Control-Allow-Origin` errors in browser console

**How to verify**: Open browser DevTools → Console. Navigate to `http://localhost:8090`. Look for CORS errors.

### 2. SignalR Authentication
- [ ] **GO** JWT token is passed via `accessTokenFactory` in SignalR client (`signalr_client.dart`)
- [ ] **GO** DriverHub `[Authorize]` attribute accepts the JWT
- [ ] **GO** `GetDriverIdFromContext` correctly extracts driverId from JWT claims (`nameid` or `sub`)
- [ ] **GO** No `401 Unauthorized` on SignalR hub connection
- [ ] **GO** No `403 Forbidden` on SignalR hub methods

**How to verify**: Watch backend logs for `HubConnection` errors. Check driver app for connection status indicator.

### 3. Timezone Consistency
- [ ] **GO** `OrderPricingService` uses `orderTime.AddMinutes(330)` for IST conversion (not `DateTime.Now`)
- [ ] **GO** `CreateBookingCommandValidator` uses `DateTimeOffset.UtcNow` for `ScheduledFor` validation
- [ ] **GO** Backend server timezone does not affect pricing calculations (all UTC-based)
- [ ] **GO** Flutter client sends `scheduledFor.toUtc().toIso8601String()` (not local time)

**How to verify**: Place a food order at 11:30 PM IST → verify `lateNightDriverBonus = 30` in API response.

### 4. Backend Port Consistency
- [ ] **GO** `launchSettings.json` uses `http://localhost:5000`
- [ ] **GO** `app_config.dart` uses `http://localhost:5000` (and `10.0.2.2:5000` for Android)
- [ ] **GO** `e2e/playwright.config.ts` uses `http://localhost:5000`
- [ ] **GO** `e2e/fixtures/helpers.ts` uses `http://localhost:5000`
- [ ] **GO** `e2e/scripts/build-web.ps1` uses `--dart-define=API_BASE_URL=http://localhost:5000`

---

## YELLOW — Important Warnings (Fix if test fails)

### 5. Redis / Distributed Locking
- [ ] **GO** Redis connection string in `appsettings.json` is valid (or empty for in-memory fallback)
- [ ] **GO** `BookingEngineService` acquires `venue:slot:{venueId}` lock before capacity check
- [ ] **GO** Concurrent booking attempts for the same venue are serialized correctly
- [ ] **GO** Lock is released on exception (rollback path)

**How to verify**: Open two browser tabs, book the same venue simultaneously. Only one should succeed if capacity is 1.

### 6. Database State
- [ ] **GO** SQLite database file exists (`pondyconnect.db`) or PostgreSQL is running
- [ ] **GO** `DataInitializer` has seeded: venues, vendors, drivers, menu items, test passes
- [ ] **GO** Seeded test passes have `PaymentStatus.Captured` and `BookingStatus.Confirmed`
- [ ] **GO** Drunken Daddy venue exists with `MaxCapacity = 50`
- [ ] **GO** Fuoco Pizzeria vendor exists with phone `9000000001`

### 7. Payment Settlement Integrity
- [ ] **GO** `SettlementCalculationService` returns `VendorPayout = SubTotal` for food orders
- [ ] **GO** `PlatformFee = 0` for food delivery (zero commission)
- [ ] **GO** `DriverPayout = DeliveryFee + LateNightDriverBonus` for food delivery
- [ ] **GO** No duplicate settlement records for the same payment

### 8. QR Pass Token Integrity
- [ ] **GO** `PassIssuer.Issue()` generates a unique, non-empty pass token
- [ ] **GO** `BookingResult.passToken` is populated from `CreateBookingResponse.PassToken`
- [ ] **GO** Booking success screen displays the actual `passToken` (not truncated bookingId)
- [ ] **GO** `ValidateTicketHandler` checks `PassToken` field against `ServiceBookings` table
- [ ] **GO** Second validation of same token returns "Already used."

---

## GREEN — Nice-to-Have Verifications

### 9. SignalR Reconnection
- [ ] **GO** `SignalRClient.connect()` uses `.withAutomaticReconnect()`
- [ ] **GO** Driver app reconnects within 10 seconds after network restore
- [ ] **GO** No zombie connections (old connection IDs cleaned up)

### 10. Food Delivery Dispatch
- [ ] **GO** `FoodDeliveryDispatchService` finds nearby drivers via `DriverLocationStore.GetNearby()`
- [ ] **GO** `FoodDeliveryOffer` event sent to `driver:{driverId}` SignalR group
- [ ] **GO** Driver app `foodDeliveryOfferStream` receives and parses the offer
- [ ] **GO** Offer includes vendor name, pickup/delivery addresses, and driver earnings

### 11. Vendor Venue Toggle
- [ ] **GO** `PUT /api/vendor/venues/{venueId}/availability` endpoint exists and works
- [ ] **GO** Toggle calls `Venue.ToggleActive(!venue.IsActive)` and saves
- [ ] **GO** Frontend `_toggleAcceptingOrders` calls API (not just `setState`)
- [ ] **GO** Error handling: failed API call shows error snackbar, doesn't change local state

### 12. Capacity Constraint
- [ ] **GO** `CreateBookingCommandValidator` allows seats up to 200 (not 20)
- [ ] **GO** `Venue.HasAvailability(seats)` checks `CurrentCapacity + seats <= MaxCapacity`
- [ ] **GO** Overflow booking returns 409 Conflict with "full capacity" message
- [ ] **GO** UI seat stepper allows values > 20 (up to 200)

---

## Quick Smoke Test (5 minutes)

Run these 5 commands to verify the system is alive before starting full E2E:

```powershell
# 1. Backend health check
curl http://localhost:5000/swagger

# 2. Venues API
curl http://localhost:5000/api/venues

# 3. Fuoco menu
curl http://localhost:5000/api/vendors/00000000-0000-0000-0000-000000000001/menu

# 4. Request OTP
curl -X POST http://localhost:5000/api/auth/otp/request -H "Content-Type: application/json" -d '{"phone":"9000000099"}'

# 5. Peek OTP (dev only)
curl "http://localhost:5000/api/auth/otp/peek?phone=9000000099"
```

If all 5 return successfully, the system is **GO** for E2E testing.

---

## Playwright Test Execution

```powershell
# Build the Flutter web app first
cd e2e\scripts
.\build-web.ps1

# Serve the web app
npx http-server ../../mobile/build/web -p 8090 --cors

# Run Playwright tests (backend must be running on port 5000)
cd e2e
npx playwright test --reporter=list

# Run only Scenario 1
npx playwright test scenario1-late-night-flow --reporter=list

# Run only Scenario 2
npx playwright test scenario2-vip-nightlife --reporter=list
```
