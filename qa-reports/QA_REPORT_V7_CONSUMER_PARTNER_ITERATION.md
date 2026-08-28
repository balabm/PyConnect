# QA Report V7 — Consumer & Partner Iteration

**Date**: 2026-08-27
**Scope**: Consumer UX polish, Partner UX polish, unimplemented features, cross-app reliability
**Status**: All P1-P5 tasks complete, verified

---

## Summary

This iteration addressed 7 critical Consumer feature gaps, broad UX polish across Consumer and Partner apps, new revenue features, and cross-app reliability verification. All changes compile cleanly with zero analyzer errors and the Consumer APK builds successfully.

### Verification Results
- **Flutter analyze**: 0 errors (189 info/warnings — all pre-existing)
- **Consumer APK build**: 84.4MB, built successfully
- **Backend build**: 0 errors, 0 warnings
- **Architecture tests**: 289/289 pass (fixed 2 pre-existing Driver test failures)

---

## P1: Consumer Feature Completion

### P1.1: Wallet Send/History/Bank (Completed in prior session)
- **Files**: `consumer_wallet_screen.dart`, `user_wallet_api.dart`, `UserWalletController.cs`, `UserWalletTransactionType.cs`
- **Fix**: Replaced empty callbacks with functional Send transfer sheet, Bank info sheet, and History scroll-to-section
- **Backend**: Added P2P transfer endpoint with `TransferSent`/`TransferReceived` transaction types

### P1.2: Scheduled Rides FAB Loop
- **File**: `scheduled_rides_screen.dart`
- **Bug**: FAB and empty-state button called `context.push('/rides/scheduled')` from the scheduled rides screen itself, creating a navigation loop
- **Fix**: Replaced with a functional "Schedule a Ride" bottom sheet featuring:
  - Pickup/dropoff address inputs
  - Date & time picker (30-day range)
  - Vehicle type selector (Bike/Auto/Car)
  - Payment method selector (Cash/UPI/Card)
  - Estimated fare calculation
  - Backend integration via `scheduleRide()` API
  - Success/error feedback with snackbar

### P1.3: Support Chat (Replace "Coming Soon")
- **Files**: `support_chat_screen.dart` (NEW), `app_router.dart`, `services_hub_screen.dart`
- **Bug**: Services hub "Support chat is coming soon" snackbar was a no-op
- **Fix**: Built full conversational support chat screen with:
  - Message sending via `SupportApi.sendMessage()`
  - AI reply display and critical issue detection
  - Ticket history dropdown selector
  - Auto-refresh every 15 seconds
  - Quick prompt chips (Ride issue, Food order, Payment issue, Refund request)
  - Welcome state with benefits explanation
  - Error/retry states
- **Route**: `/support-chat` and `/support-chat/:ticketId`
- **Services hub**: Added "Live Chat" tile

### P1.4: Referral Program UI
- **Files**: `referral_api.dart` (NEW), `referral_screen.dart` (NEW), `app_router.dart`, `services_hub_screen.dart`
- **Feature**: Full referral program screen with:
  - Hero card with referral code and copy button
  - Share via WhatsApp using `share_plus`
  - Stats grid (Invited, Completed, Pending, Earned)
  - "How It Works" 3-step guide
  - Backend integration via `/api/referrals/me`
- **Route**: `/referral`
- **Services hub**: Added "Invite Friends" tile

### P1.5: PY Prime Subscription UI
- **Files**: `subscription_api.dart` (NEW), `prime_screen.dart` (NEW), `SubscriptionsController.cs`, `app_router.dart`, `services_hub_screen.dart`
- **Feature**: Full PY Prime subscription screen with:
  - Dark gradient hero card with pricing
  - 6 benefits listed (free delivery, ride discounts, priority dispatch, event access, 2x coins, free cancellations)
  - Monthly plan card
  - Razorpay checkout integration (create-order → pay → activate)
  - Active subscription status card with grace period warning
  - FAQ section with expandable tiles
  - Manage subscription section for active members
- **Backend**: Added `POST /api/subscriptions/create-order` endpoint
- **Route**: `/prime`
- **Services hub**: Added "PY Prime" tile
- **Profile screen**: Added "Rewards & Perks" section with referral and Prime links

### P1.6: Cross-Sell Ride Upsell
- **Files**: `cross_sell_api.dart` (NEW), `ride_upsell_sheet.dart` (NEW), `booking_screen.dart`
- **Feature**: After booking confirmation, shows a ride upsell bottom sheet with:
  - Venue name and suggested pickup time
  - Discount badge (e.g. "10% off your ride")
  - "Book Ride" CTA navigating to transit tab
  - "Maybe later" dismiss option
- **Backend integration**: Uses `/api/cross-sell/ride-upsell/:bookingId`

### P1.7: Dine-In QR Ordering
- **Files**: `dine_in_api.dart` (NEW), `dine_in_screen.dart` (NEW), `app_router.dart`, `services_hub_screen.dart`
- **Feature**: Full dine-in QR ordering screen with:
  - Mobile scanner camera view with overlay
  - QR code parsing (URL and JSON formats)
  - Table session creation via `/api/dine-in/scan`
  - Manual table entry fallback (venue ID, vendor ID, table number)
  - Error handling for invalid QR codes
  - Navigation to vendor menu with dine-in context
- **Route**: `/dine-in`
- **Services hub**: Added "Dine In" tile

---

## P2: Consumer UX Polish

### Venue List Screen
- **File**: `venue_list_screen.dart`
- **Improvements**:
  - Added result count header ("X venues found")
  - Added "Clear filters" action on empty state
  - Animated list items with staggered fade-slide

### Ride Vehicle Selector
- **File**: `vehicle_selector.dart`, `rides_screen.dart`
- **Improvements**:
  - Added vehicle descriptions ("Quick & affordable", "Best for short trips", "Comfort for 4")
  - Descriptions show below vehicle name in selector cards

### Stays Screen
- **File**: `stays_screen.dart`
- **Improvements**:
  - Added result count header in search results ("X stays available")

### Profile Screen
- **File**: `profile_screen.dart`
- **Improvements**:
  - Added "Rewards & Perks" section with Invite Friends and PY Prime links
  - Prime link shows different label based on membership status

---

## P3: Partner UX Polish

### Partner Shell
- **File**: `partner_shell.dart`
- **Improvement**: Added error snackbar feedback when accepting-orders toggle fails (previously silently failed)

### Verification
- Partner dashboard: Already has good loading/error/empty states
- Partner KDS: Already has good empty state with icon and message
- Partner orders: Already has good empty state
- Partner menu: Already has good empty state with "Tap + to add" guidance
- Partner promotions: Both create promotion and flash promo buttons have labels (QA V6 issue resolved)
- Partner manage hub: All tiles have functional routes, no no-op tiles

---

## P4: New Revenue Features

### Reorder from Food Order History
- **File**: `food_order_history_screen.dart`
- **Feature**: Added "Reorder" button on delivered order cards
  - Navigates to vendor menu with vendor name
  - Only shows for delivered orders
  - Emerald-themed outlined button

### Notifications Screen
- **Files**: `notifications_screen.dart` (NEW), `app_router.dart`, `services_hub_screen.dart`
- **Feature**: Aggregated notifications/activity feed screen with:
  - Recent food orders (last 5)
  - Recent rides (last 5)
  - Sorted by timestamp descending
  - Color-coded status icons
  - Tap to navigate to order/ride detail
  - Empty state with icon and guidance
  - Error/retry states
  - Pull-to-refresh
- **Route**: `/notifications`
- **Services hub**: Added "Notifications" tile

---

## P5: Cross-App Reliability

### Verification Results
- **API Client**: Already has comprehensive error handling with friendly messages, retry logic with exponential backoff + jitter, and token refresh
- **SignalR Client**: Already has exponential backoff reconnection (2s, 5s, 10s, 20s, 30s, 45s, 60s, 60s), auth error detection, and connection state callbacks
- **Offline Banner**: Already exists with connectivity checker polling `/health` every 30 seconds
- **No new reliability issues found** — existing infrastructure is robust

---

## Backend Changes

### New Endpoints
1. `POST /api/subscriptions/create-order` — Creates Razorpay order for PY Prime subscription

### New Response Models
- `SubscriptionOrderResponse(string RazorpayOrderId, decimal Amount)`

### Test Fixes
- Fixed `GoOnline_GoOffline_TogglesIsOnline` — added `Approve()` and `UploadKyc()` calls before `GoOnline()`
- Fixed `GoOnline_WhileOnRide_Throws` — added `UploadKyc()` call before `GoOnline()`
- **Result**: 289/289 architecture tests pass

---

## Files Changed

### New Files (11)
1. `mobile/lib/features/support/presentation/support_chat_screen.dart`
2. `mobile/lib/features/referral/data/referral_api.dart`
3. `mobile/lib/features/referral/presentation/referral_screen.dart`
4. `mobile/lib/features/subscription/data/subscription_api.dart`
5. `mobile/lib/features/subscription/presentation/prime_screen.dart`
6. `mobile/lib/features/cross_sell/data/cross_sell_api.dart`
7. `mobile/lib/features/cross_sell/presentation/ride_upsell_sheet.dart`
8. `mobile/lib/features/dine_in/data/dine_in_api.dart`
9. `mobile/lib/features/dine_in/presentation/dine_in_screen.dart`
10. `mobile/lib/features/notifications/presentation/notifications_screen.dart`

### Modified Files (12)
1. `mobile/lib/features/rides/presentation/scheduled_rides_screen.dart` — Fixed FAB loop, added schedule sheet
2. `mobile/lib/router/app_router.dart` — Added 5 new routes
3. `mobile/lib/features/hub/services_hub_screen.dart` — Added 5 new service tiles
4. `mobile/lib/features/venues/presentation/venue_list_screen.dart` — Result count, clear filters
5. `mobile/lib/features/rides/presentation/widgets/vehicle_selector.dart` — Vehicle descriptions
6. `mobile/lib/features/rides/presentation/rides_screen.dart` — Pass descriptions to selector
7. `mobile/lib/features/auth/presentation/profile_screen.dart` — Rewards & Perks section
8. `mobile/lib/features/stays/presentation/stays_screen.dart` — Result count in search
9. `mobile/lib/shell/partner_shell.dart` — Error feedback on toggle failure
10. `mobile/lib/features/food/presentation/food_order_history_screen.dart` — Reorder button
11. `mobile/lib/features/bookings/presentation/booking_screen.dart` — Cross-sell upsell after booking
12. `backend/src/PondyConnect.Api/Controllers/SubscriptionsController.cs` — Create-order endpoint
13. `backend/tests/PondyConnect.Architecture.Tests/DomainEntityTests.cs` — Fixed 2 Driver tests

---

## Known Limitations & Next Steps

1. **Notifications**: Currently aggregates from orders/rides APIs. A dedicated notification entity and backend endpoint would enable push notification history
2. **Dine-in**: QR code format assumes URL or JSON with venueId/vendorId/tableId. Real QR codes should be tested on physical tables
3. **Cross-sell**: Upsell sheet shows after booking confirmation. Could be extended to show after food order completion
4. **PY Prime**: Subscription management (cancel) currently redirects to Razorpay dashboard. A native cancel flow would improve UX
5. **Referral**: Apply referral code during onboarding is not yet wired into the auth flow — only the referral code display and sharing is implemented

---

## Regression Notes

- All previously fixed bugs remain fixed:
  - Flavor-specific token storage preserved
  - Admin role-aware routing preserved
  - Partner provider authentication watching preserved
  - Driver shell provider access preserved
  - Vendor wallet refresh on switch preserved
- No new analyzer errors introduced
- Backend build: 0 errors, 0 warnings
- Architecture tests: 289/289 pass
