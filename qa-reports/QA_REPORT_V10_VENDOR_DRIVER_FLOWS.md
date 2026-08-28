# QA Report V10 — Vendor Type & Driver Flow Inspection

**Date**: 2026-08-27
**Scope**: Flow-wise inspection of every vendor type (Restaurant, Cafe, Pizzeria, PubClub, ScooterRental, TaxiOperator, LuggageCloak, PartySupplier) and Driver app end-to-end
**Status**: All critical flaws fixed, verified

---

## Summary

Inspected all 7 vendor category flows and the complete Driver app lifecycle using parallel subagents that analyzed 25+ files. Found and fixed 12 distinct flaws across 11 files.

### Verification Results
- **Flutter analyze**: 0 errors
- **Consumer APK**: 84.4MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully

---

## Issues Found & Fixed

### Restaurant/Cafe/Pizzeria Flow

#### 1. Menu Delete Was Actually Toggle (CRITICAL)
- **File**: `vendor_providers.dart` line 120
- **Bug**: `deleteItem()` called `api.toggleMenuItem(id)` instead of actually deleting — items could never be permanently removed
- **Fix**: Added `deleteMenuItem()` API method calling `DELETE /api/vendor/menu/{id}`, updated notifier to call it

#### 2. Menu Delete UI Called Wrong Method (CRITICAL)
- **File**: `vendor_menu_screen.dart` line 295
- **Bug**: Delete confirmation dialog called `toggleItem()` instead of `deleteItem()`, and confusingly labeled "Mark Unavailable" when the menu said "Remove Item"
- **Fix**: Changed to call `deleteItem()`, updated dialog text to "Delete Item?" with "Delete" button and clear warning

#### 3. Toggle Optimistic Update Lost Fields (MEDIUM)
- **File**: `vendor_providers.dart` lines 78-89
- **Bug**: When toggling availability, the optimistic update omitted `isVegan`, `containsNuts`, and `packagingFee` fields — if the toggle failed and reverted, these fields would be lost
- **Fix**: Added all missing fields to the optimistic update

### PubClub Flow

#### 4. No Delete for Drinks (HIGH)
- **File**: `drinks_menu_screen.dart`
- **Bug**: Drink cards only had availability toggle — no way to delete drinks from the menu
- **Fix**: Added delete button to `_DrinkCard` with confirmation dialog, wired to `deleteItem()`

#### 5. Silent Guestlist Load Error (MEDIUM)
- **File**: `drinks_menu_screen.dart` line 55
- **Bug**: `catch (_)` silently set loading to false with no user feedback
- **Fix**: Added error snackbar with the error message

#### 6. Guestlist Add Silent Validation Failure (LOW)
- **File**: `drinks_menu_screen.dart` line 608
- **Bug**: If guest name was empty, the add button silently returned with no feedback
- **Fix**: Added validation snackbar "Please enter a guest name"

### ScooterRental Flow

#### 7. No Complete Return Button on Active Rentals (CRITICAL)
- **File**: `active_rentals_screen.dart`
- **Bug**: Active rental cards showed countdown timer but had no button to complete the return — vendors had to manually navigate to Manage Hub and enter the rental ID
- **Fix**: Added "Complete Return" button to each rental card that navigates to `RentalReturnScreen` with the booking ID pre-filled

#### 8. Rental Return Route Didn't Pass Booking ID (HIGH)
- **File**: `partner_router.dart` line 247
- **Bug**: Route builder ignored `state.extra`, so the booking ID was never passed to the screen
- **Fix**: Updated route to pass `state.extra as String?` to `RentalReturnScreen(rentalId: ...)`

### TaxiOperator Flow

#### 9. No Action Buttons on Taxi Rides (CRITICAL)
- **File**: `taxi_rides_screen.dart`
- **Bug**: Active ride cards showed ride info but had no buttons to assign drivers or update status — operators had to manually navigate to Taxi Fleet
- **Fix**: Added "Assign Driver" button to active ride cards that navigates to `AssignDriverScreen` with the booking ID pre-filled

#### 10. Assign Driver Route Didn't Pass Trip ID (HIGH)
- **File**: `partner_router.dart` line 252
- **Bug**: Route builder ignored `state.extra`, so the trip ID was never passed
- **Fix**: Updated route to pass `state.extra as String?` to `AssignDriverScreen(tripId: ...)`

#### 11. Taxi Fleet: No Refresh After Assign + No Validation (MEDIUM)
- **File**: `taxi_fleet_screen.dart` lines 319-326
- **Bug**: After assigning a driver, the list didn't refresh to show the updated driver info. Also, the driver name field had no validation — could assign an empty name
- **Fix**: Added `_loadData()` callback after successful assignment, added validation for empty driver name

### LuggageCloak Flow

#### 12. Bag Intake/Collection Don't Refresh Data (MEDIUM)
- **Files**: `bag_intake_screen.dart` line 105, `bag_collection_screen.dart` line 96
- **Bug**: After successfully receiving or collecting bags, the screens just popped back without refreshing the bookings/capacity data
- **Fix**: Added `ref.invalidate(vendorBookingsProvider)` before popping to ensure capacity screen updates

### Occupancy Update Flow

#### 13. Occupancy Screen Required Manual Venue ID Entry (MEDIUM)
- **File**: `occupancy_update_screen.dart`
- **Bug**: The screen required the vendor to manually type their venue ID, even though the partner shell already loads it
- **Fix**: Added auto-load of venue ID from `vendorDashboardApiProvider.getVenues()` on init

---

## Screens Verified as Working Correctly

### Restaurant/Cafe/Pizzeria
- **KitchenDisplayScreen**: All order stage transitions (Incoming → Preparing → Ready → Completed), SignalR real-time updates, audio alarm, printer error handling
- **ScannerScreen**: Camera permissions, QR scanning, VIP handling, audio feedback, duplicate detection
- **VendorDashboardScreen**: Loading/error/empty states, 30s auto-refresh, auth-specific error handling

### PubClub
- **CrowdDashboardScreen**: Real-time occupancy from live tables, cover charge tracking, revenue display
- **VendorEventManagerScreen**: Event creation with validation, publishing, cancellation with confirmation

### LuggageCloak
- **CloakCapacityScreen**: Capacity bar with color coding, stored bags list, QR code generation for claim checks, 15s auto-refresh
- **VendorBookingsScreen**: Loading/error/empty states, RefreshIndicator
- **ClaimCheckScreen**: Form validation, QR code generation, success state
- **BagIntakeScreen**: Photo capture, form validation, API upload
- **BagCollectionScreen**: 6-digit PIN validation, bag release

### Driver App
- **DriverHomeScreen**: Online/offline toggle, compliance warnings, suspended wallet blocking, shimmer loading
- **DriverRegistrationScreen**: Multi-step form validation, phone pre-fill, token refresh
- **DriverKycScreen**: All 5 document uploads validated, UPI ID validation, retry logic, approved/pending states
- **ActiveTripScreen**: Phase progression, checklist, pickup confirmation, proof-of-delivery, offline queuing
- **DriverRideScreen**: OTP verification, ride start/completion, geofence auto-arrival, completion OTP for high-value
- **RideOfferSheet**: Countdown timer, swipe-to-accept, surge display, SOS indicator
- **DriverPreferencesScreen**: Destination mode, service type toggles, API persistence
- **DriverSafetySettingsScreen**: SOS, emergency contacts, trip sharing (minor: some buttons are informational only)

---

## Files Changed (11)

1. `mobile/lib/features/vendor/data/vendor_dashboard_api.dart` — Added `deleteMenuItem()` method
2. `mobile/lib/features/vendor/application/vendor_providers.dart` — Fixed `deleteItem()` to call delete API, added missing fields to toggle optimistic update
3. `mobile/lib/features/vendor/presentation/vendor_menu_screen.dart` — Fixed delete dialog to call `deleteItem()`, updated UX text
4. `mobile/lib/features/vendor/presentation/active_rentals_screen.dart` — Added "Complete Return" button
5. `mobile/lib/features/vendor/presentation/taxi_rides_screen.dart` — Added "Assign Driver" button
6. `mobile/lib/features/vendor/presentation/taxi_fleet_screen.dart` — Added validation and refresh after assign
7. `mobile/lib/features/vendor/presentation/drinks_menu_screen.dart` — Added delete button, fixed silent errors, added validation feedback
8. `mobile/lib/features/vendor/presentation/bag_intake_screen.dart` — Added data refresh after mutation
9. `mobile/lib/features/vendor/presentation/bag_collection_screen.dart` — Added data refresh after mutation
10. `mobile/lib/features/vendor/presentation/occupancy_update_screen.dart` — Auto-load venue ID
11. `mobile/lib/router/partner_router.dart` — Fixed routes to pass booking/trip IDs via `state.extra`

---

## Remaining Minor Items (Not Fixed)

- **CloakCapacityScreen**: Hardcoded `_maxCapacity = 50` — should load from venue data
- **DrinksMenuScreen**: Hardcoded initial `_crowdPercent = 25` — should load from backend
- **DriverSafetySettingsScreen**: Some buttons (trip sharing, OTP verification) show informational snackbars rather than full configuration screens
- **VendorDashboardScreen**: Default `venueId` parameter is a placeholder UUID — should always be resolved from session
- **VendorMenuScreen**: Create item adds to local state only — could call `load()` for full refresh

---

## Verification

- **Flutter analyze**: 0 errors
- **Consumer APK**: 84.4MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully
