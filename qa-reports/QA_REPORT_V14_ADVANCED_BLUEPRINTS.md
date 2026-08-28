# QA Report V14 — Advanced Integration Blueprints (9-13)

**Date:** 2026-08-26
**Scope:** FCM notifications, Genie errand engine, background location telemetry, rating/tipping loop, split payment engine

---

## Summary

Implemented 5 advanced platform features (Blueprints 9-13) to elevate PY Connect toward unicorn-grade reliability. All backend builds pass with 0 errors, 289/289 architecture tests pass, and Flutter analysis is clean.

### Verification Results

| Check | Result |
|-------|--------|
| Backend build | ✅ 0 errors |
| Architecture tests | ✅ 289/289 pass |
| Flutter analyze (new files) | ✅ 0 errors |
| Flutter analyze (driver_shell) | ✅ 0 errors |

---

## Blueprint 9: Cross-App Notification Engine (FCM)

### Audit Findings
- **Backend:** FirebaseNotificationService fully implemented with FirebaseAdmin SDK. High-priority push for driver dispatch, vendor push, user push all functional. Deep-link routes sent in FCM payload.
- **Mobile:** FcmService with background handler, token registration, deep-link resolution, local notification channels all implemented.
- **Config issue:** `Firebase.IsEnabled = false` in appsettings.json — using MockNotificationService. Requires Firebase service account JSON to enable.
- **Missing:** `google-services.json` file not in repo (must be added per flavor).
- **Missing:** Consumer app AndroidManifest lacked `POST_NOTIFICATIONS` permission.

### Changes Made
| File | Change |
|------|--------|
| `mobile/android/app/src/consumer/AndroidManifest.xml` | Added `POST_NOTIFICATIONS` and `VIBRATE` permissions |

### Remaining Gaps
- `google-services.json` must be placed in `mobile/android/app/` for each flavor
- Firebase must be enabled in production appsettings with service account path
- Geo-promo broadcast system not implemented (location-based push marketing)

---

## Blueprint 10: Genie Custom Errand Engine

### Audit Findings
- **Backend:** GenieController with full CRUD (create, cancel, accept, complete). GenieErrand entity with state machine. RazorpayGateway supports auth-hold (capture: false) and capture/release.
- **Critical gap:** No payment integration — controller stored Razorpay IDs but never called the payment gateway.
- **Razorpay limitation:** Partial capture not supported. Must capture full auth-hold and refund the difference.
- **Mobile:** Consumer Genie screen exists with form and errand list. No driver/captain UI for accepting errands. No bill upload.

### Changes Made
| File | Change |
|------|--------|
| `backend/.../Controllers/GenieController.cs` | Injected `IPaymentGateway`. Create errand now creates Razorpay auth-hold order. Cancel releases auth-hold. Complete captures full amount + refunds difference. Added `POST /api/genie/{id}/confirm-payment` endpoint. |
| `backend/.../Domain/Entities/GenieErrand.cs` | Added `SetRazorpayOrderId()` and `SetRazorpayPaymentId()` methods |

### Payment Flow
1. `POST /api/genie` → creates errand + Razorpay auth-hold order (capture: false)
2. Consumer completes Razorpay checkout → `POST /api/genie/{id}/confirm-payment` stores paymentId
3. Captain accepts → `POST /api/genie/{id}/accept`
4. Captain completes with actual cost → `POST /api/genie/{id}/complete` → backend captures full auth-hold, refunds (auth-hold - actual cost)
5. Cancel → `POST /api/genie/{id}/cancel` → backend releases auth-hold

### Remaining Gaps
- Driver app has no Genie errand acceptance/completion UI
- No bill/receipt upload endpoint or UI
- Mobile consumer Genie screen needs Razorpay checkout integration

---

## Blueprint 11: Background Location Telemetry

### Audit Findings
- **Backend:** DriverHub.UpdateLocation receives GPS via SignalR. DriverLocationStore stores in-memory. RideDispatchService.NotifyDriverLocationUpdateAsync defined but **never called** — no worker to broadcast driver GPS to consumers.
- **Mobile:** BackgroundLocationService collects GPS every 5s but `service.invoke('locationUpdate')` had **no listener** in the main isolate — data was lost. Driver shell used HTTP polling (5s) instead of SignalR.

### Changes Made
| File | Change |
|------|--------|
| `backend/.../Api/Services/LocationBroadcastWorker.cs` | **NEW** — BackgroundService that runs every 3s, queries active rides (DriverAssigned/EnRoute/ArrivedAtPickup), gets driver GPS from DriverLocationStore, broadcasts via RideDispatchService.NotifyDriverLocationUpdateAsync to RideHub groups |
| `backend/.../Api/Program.cs` | Registered `LocationBroadcastWorker` as hosted service |
| `mobile/lib/shell/driver_shell.dart` | Added `flutter_background_service` import. Added `_bgLocationSub` listener for `locationUpdate` events from background isolate. Forwards GPS to backend via both HTTP API and SignalR `UpdateLocation`. Cancels subscription in dispose. |

### How It Works
1. Driver goes online → background service starts → foreground service collects GPS every 5s
2. Background isolate sends `locationUpdate` event to main isolate
3. Main isolate listener forwards GPS to backend via HTTP (`POST /api/driver/location`) and SignalR (`UpdateLocation`)
4. Backend DriverHub stores GPS in DriverLocationStore
5. LocationBroadcastWorker runs every 3s, queries active rides, broadcasts driver GPS to consumer RideHub groups
6. Consumer ride tracking screen receives `DriverLocationUpdate` via SignalR and updates map

### Remaining Gaps
- Driver ride screen (`driver_ride_screen.dart`) does not send location updates during active ride (only shell does when online)
- Consider switching from HTTP to SignalR-only for location updates (lower latency, less battery)

---

## Blueprint 12: Post-Action Rating & Tipping Loop

### Audit Findings
- **Backend:** Review entity with TipAmount/TipReference. ReviewsController with 3 endpoints. RideRequest two-way ratings. Driver.UpdateRating with weighted average.
- **Critical gap:** No tip payment integration — tips stored but never charged.
- **Critical gap:** No auto support ticket on low ratings.
- **Critical gap:** No driver dispatch pause for low-rated drivers.
- **Mobile:** PostCompletionSheet with 5-star rating, tip buttons (₹20/₹50/₹100), feedback field. RideRatingScreen with tip options. Driver rating screen. All functional UI.

### Changes Made
| File | Change |
|------|--------|
| `backend/.../Domain/Entities/Driver.cs` | Added `IsDispatchPaused` field. Added `PauseForReview()` method (sets paused + goes offline). Added `ResumeFromReview()` method. |
| `backend/.../Application/Features/RideHailing/RideHailingHandlers.cs` | `RateRideHandler` now auto-creates a `SupportTicket` (priority: High, category: "LowRatingFeedback") when rating ≤ 2 stars. Auto-pauses driver dispatch when rating ≤ 2 AND overall rating < 3.0. |
| `backend/.../Api/Services/DispatchEngine.cs` | Both parallel and sequential dispatch paths now query DB for paused driver IDs and exclude them from nearby driver results. |
| `backend/.../Controllers/AdminController.cs` | Added `POST /api/admin/drivers/{driverId}/resume-dispatch` endpoint for admins to resume a paused driver after review. |

### Quality Control Loop
1. Rider submits rating ≤ 2 stars → `RateRideHandler`:
   - Updates driver's weighted rating
   - If overall rating < 3.0: calls `driver.PauseForReview()` (driver goes offline, dispatch skips them)
   - Creates `SupportTicket` with priority High, category "LowRatingFeedback"
2. Admin sees ticket in God Mode Admin panel
3. Admin reviews feedback, investigates ride
4. Admin calls `POST /api/admin/drivers/{driverId}/resume-dispatch` to restore driver

### Remaining Gaps
- Tip payment via Razorpay not implemented (UI exists, tips stored as metadata only)
- Tip payout to driver wallet not implemented
- Mobile does not show "paused" status to driver

---

## Blueprint 13: Split Payment Engine

### Audit Findings
- **Backend:** SplitPaymentsController with full CRUD (create pool, get by slug, claim share, pay share, my pools, cancel). SplitPaymentPool entity with state machine. SplitPaymentContributor entity. Deep-link slug generation.
- **Mobile:** SplitPaymentScreen (creator) with WhatsApp share via `share_plus`. SplitPaymentApi with all methods.
- **Critical gap:** No join/claim screen for friends clicking the deep link.
- **Critical gap:** No SignalR real-time updates for pool progress.
- **Critical gap:** `/split/*` not in Android App Links config.

### Changes Made
| File | Change |
|------|--------|
| `backend/.../Api/Hubs/SplitPaymentHub.cs` | **NEW** — SignalR hub with `JoinPool(slug)` and `LeavePool(slug)` methods. Creator joins group `split:{slug}` to receive real-time updates. |
| `backend/.../Api/Program.cs` | Registered `SplitPaymentHub` at `/hubs/split-payment` |
| `backend/.../Controllers/SplitPaymentsController.cs` | Injected `IHubContext<SplitPaymentHub>`. ClaimShare now broadcasts `ShareClaimed` event. PayShare now broadcasts `SharePaid` event with updated collected amount and status. |
| `mobile/lib/features/split_payments/presentation/split_payment_join_screen.dart` | **NEW** — Join screen for friends clicking deep link. Shows pool details, progress bar, contributors list, claim & pay button. |
| `mobile/lib/router/app_router.dart` | Added import for `SplitPaymentJoinScreen`. Added route `split/:slug` → `SplitPaymentJoinScreen`. |
| `mobile/android/app/src/main/AndroidManifest.xml` | Added `/split` path prefix to Android App Links intent filter. |

### Split Payment Flow
1. User books ₹20,000 villa → taps "Split with Friends"
2. `POST /api/split-payments` creates pool with deep-link slug (e.g., `abcd123`)
3. User shares `https://pyconnect.run.place/split/abcd123` to WhatsApp
4. Friends click link → app opens `SplitPaymentJoinScreen`
5. Friend claims share → `POST /api/split-payments/{id}/claim` → backend broadcasts `ShareClaimed` to creator via SignalR
6. Friend pays via Razorpay → `POST /api/split-payments/{id}/pay` → backend broadcasts `SharePaid` with updated progress
7. Creator's screen shows progress bar filling in real-time
8. When all shares paid → pool status flips to `FullyPaid` → booking confirmed

### Remaining Gaps
- Razorpay checkout integration in join screen (placeholder currently)
- SignalR client-side listener in creator screen (backend broadcasts ready)
- "Split with Friends" button not yet added to booking flows (stays, villa rentals)

---

## Files Changed Summary

### Backend (8 files)
1. `backend/src/PondyConnect.Api/Services/LocationBroadcastWorker.cs` — **NEW**
2. `backend/src/PondyConnect.Api/Hubs/SplitPaymentHub.cs` — **NEW**
3. `backend/src/PondyConnect.Api/Program.cs` — Registered LocationBroadcastWorker + SplitPaymentHub
4. `backend/src/PondyConnect.Api/Controllers/GenieController.cs` — Payment integration
5. `backend/src/PondyConnect.Api/Controllers/AdminController.cs` — Resume dispatch endpoint
6. `backend/src/PondyConnect.Api/Controllers/SplitPaymentsController.cs` — SignalR broadcasting
7. `backend/src/PondyConnect.Api/Services/DispatchEngine.cs` — Paused driver filtering
8. `backend/src/PondyConnect.Domain/Entities/GenieErrand.cs` — SetRazorpayOrderId/PaymentId methods
9. `backend/src/PondyConnect.Domain/Entities/Driver.cs` — IsDispatchPaused + PauseForReview/ResumeFromReview
10. `backend/src/PondyConnect.Application/Features/RideHailing/RideHailingHandlers.cs` — Auto ticket + dispatch pause

### Mobile (5 files)
1. `mobile/lib/features/split_payments/presentation/split_payment_join_screen.dart` — **NEW**
2. `mobile/lib/shell/driver_shell.dart` — Background location listener
3. `mobile/lib/router/app_router.dart` — Split payment join route
4. `mobile/android/app/src/main/AndroidManifest.xml` — /split App Link
5. `mobile/android/app/src/consumer/AndroidManifest.xml` — POST_NOTIFICATIONS permission

---

## Recommendations for Next Iteration

### P0 — Critical
1. Add `google-services.json` to mobile project and enable Firebase in production
2. Build driver app Genie errand acceptance + bill upload UI
3. Integrate Razorpay checkout in Genie consumer screen and SplitPaymentJoinScreen
4. Add SignalR client listener in SplitPaymentScreen (creator) for real-time progress

### P1 — High
1. Add "Split with Friends" button to stays and villa booking flows
2. Implement tip payment via Razorpay in PostCompletionSheet
3. Add tip payout to driver wallet
4. Show "dispatch paused" status in driver app

### P2 — Medium
1. Implement geo-promo broadcast system (location-based FCM)
2. Add bill/receipt upload endpoint for Genie errands
3. Switch driver location updates from HTTP to SignalR-only
4. Add driver location streaming during active ride (not just when online)
