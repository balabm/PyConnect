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
* [ ] **House Party Module:** Build the custom P2P event creator form and hardware rental flow with upfront Escrow splits.

---

## Summary

| App | Total | Done | Pending |
|-----|-------|------|---------|
| God Mode (Admin) | 4 | 4 | 0 |
| Partner App | 7 | 7 | 0 |
| Captain App | 6 | 6 | 0 |
| Consumer App | 6 | 5 | 1 |
| **Total** | **23** | **22** | **1** |

## Next Priority

The **House Party Module** (P2P event creator + hardware rental escrow) is the
last remaining item. This is a larger feature requiring both backend and
mobile work.
