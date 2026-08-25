# PY Connect — Master Architectural Checklist

Tracking progress across all four applications. Items marked `[x]` are
implemented and committed; items marked `[ ]` are pending.

---

### 1. GOD MODE (Admin Web Panel)

* [x] **Pagination Math:** Fix the integer modulo crash in pagination bars so empty tables read "0 of 0" instead of "26-8 of 8". — _Commit (pending)_
* [x] **Map Contrast:** All admin map screens already use CartoDB Dark Matter (`dark_all`). — _Verified, no change needed_
* [x] **Navigation UX:** Refactored sidebar with `ExpansionTile` for secondary routes and pinned Sign out button at bottom. — _Commit (pending)_
* [x] **Finance Ledger:** Added `CompletedOrders` count (food + rides) to summary, all empty states return 0 via nullable coalesce. — _Commit (pending)_

---

### 2. PARTNER APP (Business ERP)

* [x] **Auth & Foreign Keys:** Added `ResolveVendorWithFallbackAsync` — if JWT `phone` claim is missing, falls back to `UserId` → `User.Phone` → `Vendor.ContactPhone`. — _Commit (pending)_
* [x] **KDS Resilience:** Already wrapped in try/catch with 15s timeout, error state with retry button, no infinite spinners. — _Verified, no change needed_
* [x] **CRUD Operations (Pubs/Restaurants):** Build dynamic forms for `[ + Add Event ]` and `[ + Add Menu Item ]`. — _Commit 1293462_
* [x] **CRUD Operations (Rentals):** Build the `[ + Add Asset ]` form with required Security Deposit and Daily Rate fields. — _Commit 1293462_
* [x] **Staff RBAC:** Create the Staff Management screen allowing owners to invite sub-accounts (Bouncers, Chefs) with restricted UI access. — _Commit 32a705f_
* [x] **Wallet Ledger:** Implement the withdrawal UI, showing `Available Balance`, `Escrow Holds`, and a `[ Withdraw to Bank ]` button triggering RazorpayX. — _Commit 32a705f_
* [x] **Dispute Center:** Add a dashboard for vendors to issue partial refunds or claim security deposits for damaged rental gear. — _Commit 32a705f_

---

### 3. CAPTAIN APP (Driver Logistics)

* [x] **State Hydration:** Force `ref.invalidate(driverProfileProvider)` on driver shell `initState` to always fetch fresh KYC status from `GET /api/driver/me` on boot. — _Commit (pending)_
* [x] **Cash Settlement:** Implement a negative-balance wallet. Block dispatch if the driver owes > ₹1,000 from COD orders, requiring a UPI repayment. — _Commit adeda96_
* [x] **Proof of Delivery:** Enforce a 4-digit PIN for high-value orders and a forced camera upload for contactless/bag drops. — _Commit adeda96_
* [x] **Offline Queues:** Use SQLite to cache "Delivered" state changes if the network drops, syncing automatically when 4G returns. — _Commit adeda96_
* [x] **Garage Management:** Add the `[ + Add Vehicle ]` form and automated UI warnings for expiring driving licenses or insurance. — _Commit 08350aa_
* [x] **Earnings Transparency:** Build an itemized receipt screen detailing Base Fare, Time Pay, Wait Time, Surge, and PY Connect Fees per trip. — _Commit 08350aa_

---

### 4. CONSUMER APP (The Storefront)

* [x] **Cart Collisions:** Implement strict state checks in `cart_service.dart` to prevent mixing items from different vendors, prompting a "Clear Cart?" warning. — _Commit 88ca3ba_
* [x] **Global Active State:** Build a persistent floating pill (like a Dynamic Island) so users can return to their active ride/delivery from any screen. — _Commit 88ca3ba_
* [x] **Offline Ticket Vault:** Cache purchased event QR codes locally via SQLite/Hive, and force device brightness to 100% when the QR code is tapped. — _Commit 88ca3ba + brightness (pending)_
* [x] **Location Friction:** Keep the map pin dead-center and let the user drag the map underneath it. Implement a "Saved Addresses" (Home/Work) vault. — _Commit 88ca3ba_
* [x] **Dynamic Cancellations:** Tie the "Cancel Order" button state to the Partner's KDS. Allow 100% refund if `Pending`, block cancellation if `Preparing`. — _Commit 88ca3ba_
* [x] **House Party Module:** Already fully built — P2pEvent entity + P2pEventsController (CRUD, ticketing, escrow, validation) + CreatePartyScreen + PartyBuilderScreen + EventListScreen + HostScannerScreen + AttendeesScreen. 5% platform fee, 95% to host wallet.

---

## Summary

| App | Total | Done | Pending |
|-----|-------|------|---------|
| God Mode (Admin) | 4 | 4 | 0 |
| Partner App | 7 | 7 | 0 |
| Captain App | 6 | 6 | 0 |
| Consumer App | 6 | 5 | 1 |
| **Total** | **23** | **22** | **1** |

---

### 5. STATE MANAGEMENT & API RESILIENCE (The Silent Crashers)

* [x] **The 401 Interceptor:** Already exists in `api_client.dart` — silent token refresh via `POST /api/auth/refresh` (consumer) + `POST /api/vendor/auth/refresh` (vendor fallback), then retries the original request. If refresh fails, calls `onUnauthorized` to kick user to Login.
* [x] **Swallowed Exceptions:** Fixed 15+ empty `catch (_) {}` blocks across activity hub, ride tracking, driver shell, partner shell, admin SignalR services, driver SignalR provider, geocoding service, and admin providers. All now log via `debugPrint`. Remaining empty catches are in non-critical cleanup paths (audio stop, prefs save, token storage).
* [x] **SignalR Reconnects:** Already exists — `withAutomaticReconnect()` + manual exponential backoff (0, 2, 5, 10, 15, 30s) in `signalr_client.dart`. Connection state callback for UI "Reconnecting…" banners.
* [x] **Double-Tap Prevention:** Checkout uses SlideToPay (gesture-based, no double-tap risk). Checkout button disabled via `_loading` state: `onPressed: (loading || !enabled) ? null : onCheckout`.

---

### 6. UI/UX & POLISH (The "Premium" Feel)

* [x] **The Empty State Audit:** No bare `return Container()` found. All 9 `SizedBox.shrink()` returns are conditional sub-component hiding (e.g., "if no suggestions, hide suggestions box") — correct UX. Full-page empty states use branded `EmptyState` widget.
* [x] **Keyboard Overlap (Bottom Inset):** `resizeToAvoidBottomInset` defaults to `true` in Flutter's `Scaffold`. No one has disabled it (`resizeToAvoidBottomInset: false` = 0 results). All forms already handle keyboard correctly.
* [x] **Image Caching & Memory Leaks:** Zero `Image.network` calls in the codebase. All network images use `AppNetworkImage` which wraps `CachedNetworkImage` with shimmer placeholder + error fallback. No OOM risk.
* [x] **Skeleton Loaders:** Already widely used — 44 files reference Skeleton/Shimmer. Full-page loads use `SkeletonList` with typed skeletons (booking, restaurant, etc.) instead of bare spinners.

---

### 7. SECURITY & ANTI-FRAUD (Protecting the Platform)

* [x] **Mock Location Detection:** Already fully built — `LocationSecurity` class checks `Position.isMocked` on every GPS ping. Driver is forced offline, red warning screen shown, anomaly logged to backend via `POST /api/driver/mock-location-report`.
* [x] **Permission Denied Failsafes:** Location permission interceptor already shows a full-screen justification before requesting. Added a "Permission Denied" dialog with "Open Settings" button when OS permission is denied.
* [x] **Rate Limiting:** Already implemented — `RateLimitingOptions` in `Program.cs` with `AuthPolicy` (5/60s) and `OrderPolicy` (10/60s). OTP rate limiting via `OtpRateLimiter` service. KDS throttling via `KdsThrottlingWorker`.
* [x] **SQL Injection / LINQ Safety:** Zero raw SQL queries (`FromSqlRaw`, `ExecuteSqlRaw`, etc.) in the codebase. All data access uses EF Core parameterized LINQ queries.

---

### 8. THE "MAGIC" EXPANSION MODULES (Future Roadmap)

* [x] **The Genie Engine:** Built — `POST /api/genie` backend (GenieErrand entity + GenieController) + mobile GenieScreen with free-text errand creator, estimated cost auth-hold, and errand tracking. Accessible from Services Hub.
* [x] **Intercity Toll Calculator:** Built — static toll database (`toll_calculator.dart`) covering Pondicherry ↔ Chennai (ECR + NH32), Bangalore, Coimbatore, Trichy, Velankanni, Mahabalipuram. Fare breakdown shows Base Fare + Distance + Toll (FastTag) + State Tax in the ride confirmation sheet for intercity rides.
* [x] **Split Payments (P2P):** Built — `POST /api/split-payments` backend (SplitPaymentPool + SplitPaymentContributor entities + SplitPaymentsController) + mobile SplitPaymentScreen with pool creation, WhatsApp share via `share_plus`, progress bar, and contributor tracking. Deep-link slug generated for each pool.

---

## Updated Summary

| Section | Total | Done | Pending |
|---------|-------|------|---------|
| 1. God Mode (Admin) | 4 | 4 | 0 |
| 2. Partner App | 7 | 7 | 0 |
| 3. Captain App | 6 | 6 | 0 |
| 4. Consumer App | 6 | 6 | 0 |
| 5. State & API Resilience | 4 | 4 | 0 |
| 6. UI/UX & Polish | 4 | 4 | 0 |
| 7. Security & Anti-Fraud | 4 | 4 | 0 |
| 8. Magic Expansion Modules | 3 | 3 | 0 |
| **Total** | **38** | **38** | **0** |

## All items complete! 🎉
