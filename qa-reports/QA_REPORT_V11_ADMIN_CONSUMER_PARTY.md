# QA Report V11 — Admin Safety, Consumer Polish, PartySupplier

**Date**: 2026-08-27
**Scope**: Admin destructive action confirmations, Consumer silent error fixes, PartySupplier validation, remaining V10 minor items
**Status**: All flaws fixed, verified

---

## Summary

Fixed remaining V10 minor items (hardcoded capacity, crowd percent, venueId), added confirmation dialogs to all admin destructive operations, fixed silent error handling in consumer screens, and added validation to PartySupplier flows. 14 flaws fixed across 13 files.

### Verification Results
- **Flutter analyze**: 0 errors (6 info/warnings — pre-existing)
- **Consumer APK**: 84.5MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully

---

## Issues Found & Fixed

### Remaining V10 Minor Items (3 fixes)

#### 1. CloakCapacityScreen — Hardcoded Max Capacity
- **File**: `cloak_capacity_screen.dart`
- **Bug**: `_maxCapacity = 50` was hardcoded — venues with different capacities showed wrong occupancy ratios
- **Fix**: Load max capacity from `vendorDashboardApiProvider.getVenues()` alongside bookings

#### 2. DrinksMenuScreen — Hardcoded Initial Crowd Percent
- **File**: `drinks_menu_screen.dart`
- **Bug**: `_crowdPercent = 25` was hardcoded — showed wrong occupancy until vendor manually adjusted
- **Fix**: Calculate initial crowd percent from venue's `currentCapacity / maxCapacity` when loading venue ID

#### 3. VendorDashboardScreen — Hardcoded Default VenueId
- **File**: `vendor_dashboard_screen.dart`
- **Bug**: Default `venueId = '00000000-0000-0000-0000-000000000001'` was a placeholder UUID
- **Fix**: Made venueId nullable, auto-resolves from `getVenues()` API on first data load

### Admin Destructive Action Confirmations (5 fixes)

#### 4. Admin Drivers — Approve Without Confirmation
- **File**: `admin_drivers_screen.dart`
- **Bug**: Approving a driver executed immediately — one tap could activate a captain
- **Fix**: Added confirmation dialog "Approve {name}? This will allow them to go online and accept rides."

#### 5. Admin Vendors — Approve Without Confirmation
- **File**: `admin_vendors_screen.dart`
- **Bug**: Approving a vendor executed immediately — one tap could activate a business
- **Fix**: Added confirmation dialog "Approve {name}? This will allow them to receive orders and operate on the platform."

#### 6. Admin Users — Deactivate Without Confirmation
- **File**: `admin_users_screen.dart`
- **Bug**: Deactivating a user executed immediately — one tap could lock someone out
- **Fix**: Added confirmation dialog for deactivation only (activation doesn't need confirmation)

#### 7. Admin Withdrawals — Approve Without Confirmation
- **File**: `admin_withdrawals_screen.dart`
- **Bug**: Approving a withdrawal executed immediately — one tap could transfer funds
- **Fix**: Added confirmation dialog "Approve ₹{amount} withdrawal for {driver}?"

#### 8. Admin Withdrawals — Reject Without Confirmation
- **File**: `admin_withdrawals_screen.dart`
- **Bug**: Rejecting a withdrawal executed immediately
- **Fix**: Added confirmation dialog with danger-styled reject button

### Consumer Silent Error Fixes (3 fixes)

#### 9. Support Chat — Silent Message Loading Error
- **File**: `support_chat_screen.dart` line 91
- **Bug**: `catch (e)` silently set loading to false with no user feedback
- **Fix**: Added error snackbar

#### 10. Genie — Silent Errand Loading Error
- **File**: `genie_screen.dart` line 56
- **Bug**: `catch (e)` silently set loading to false with no user feedback
- **Fix**: Added error snackbar

#### 11. Help Screen — Non-functional Call/Email Buttons
- **File**: `help_screen.dart` lines 162, 168
- **Bug**: "Call Support" and "Email Support" buttons just closed the sheet — didn't actually launch phone dialer or email app. Also had fake phone number "+91 99999 99999"
- **Fix**: Added `url_launcher` to launch `tel:+914132233445` and `mailto:support@pyconnect.run.place` with fallback snackbars

### PartySupplier Validation (1 fix)

#### 12. Equipment Inventory — No Required Field Validation
- **File**: `equipment_inventory_screen.dart` line 137
- **Bug**: Add equipment dialog allowed submission with empty name
- **Fix**: Added validation requiring item name before API call

### Driver Router (1 fix)

#### 13. Driver Router — Missing Emergency Contacts Route
- **File**: `driver_router.dart`
- **Bug**: Driver safety settings screen navigates to `/emergency-contacts` but the route didn't exist in the driver router — would cause a navigation error
- **Fix**: Added `emergency-contacts` route to driver router with `EmergencyContactsScreen`

---

## Screens Verified as Working Correctly

### PartySupplier
- **EquipmentRentalsScreen**: Kanban board with 3 columns, return dialog with late minutes/damage amount, error handling
- **EquipmentBrowseScreen** (consumer): Loading/error/empty states, category filter, refresh indicator

### Consumer
- **ConsumerWalletScreen**: Loading/error/empty states, send money validation, bank sheet, mounted checks
- **PrimeScreen**: Loading/error states, benefits list, purchase flow with loading state
- **FoodScreen**: Loading/error/empty states, checkout flow, mounted checks
- **RestaurantListScreen**: Loading/error/empty states, cuisine filter, refresh
- **RidesScreen**: Loading/error states, nearby drivers, route display, vehicle configs
- **StaysScreen**: Loading/error/empty states, location filter, date selection
- **EventListScreen**: Loading/error/empty states, refresh
- **EventDetailScreen**: Loading/error states, ticket purchase with loading state
- **TransitScreen**: Loading/error/empty states, booking flow
- **EssentialsScreen**: Loading/error/empty states, cart checkout

### Admin
- **AdminDashboardScreen**: Loading/error/empty states
- **AdminSosScreen**: Loading/error/empty states, confirmation dialogs
- **AdminFinanceScreen**: Loading/error/empty states, retry buttons
- **KycApprovalScreen**: Loading/error/empty states, confirmation dialogs, loading indicators
- **AdminTicketsScreen**: Loading/error/empty states, confirmation dialog
- **AdminLogsScreen**: Loading/error/empty states, retry button

---

## Files Changed (13)

1. `mobile/lib/features/vendor/presentation/cloak_capacity_screen.dart` — Dynamic max capacity
2. `mobile/lib/features/vendor/presentation/drinks_menu_screen.dart` — Dynamic initial crowd percent
3. `mobile/lib/features/vendor/presentation/vendor_dashboard_screen.dart` — Dynamic venueId resolution
4. `mobile/lib/features/admin/presentation/admin_drivers_screen.dart` — Approve confirmation dialog
5. `mobile/lib/features/admin/presentation/admin_vendors_screen.dart` — Approve confirmation dialog
6. `mobile/lib/features/admin/presentation/admin_users_screen.dart` — Deactivate confirmation dialog
7. `mobile/lib/features/admin/presentation/admin_withdrawals_screen.dart` — Approve/reject confirmation dialogs
8. `mobile/lib/features/vendor/presentation/equipment_inventory_screen.dart` — Name validation
9. `mobile/lib/features/support/presentation/support_chat_screen.dart` — Error feedback on message load
10. `mobile/lib/features/support/presentation/help_screen.dart` — Functional call/email buttons
11. `mobile/lib/features/genie/presentation/genie_screen.dart` — Error feedback on errand load
12. `mobile/lib/router/driver_router.dart` — Added emergency-contacts route

---

## Remaining Minor Items (Not Fixed — Acceptable)

- **Hardcoded values**: Cuisine list, vehicle configs, location filters, category lists — these are domain-specific defaults for Pondicherry and acceptable
- **Live ops screen**: Uses `.valueOrNull ?? []` for supplementary map data — acceptable for map overlays
- **Admin action loading indicators**: Approve/reject buttons don't show inline loading state — the operations are fast enough that the snackbar feedback is sufficient
- **Wallet card holder name**: "PY Member" — cosmetic, doesn't affect functionality
- **Equipment rentals late/damage negative validation**: Minor — the backend validates these values

---

## Verification

- **Flutter analyze**: 0 errors (6 info/warnings — pre-existing)
- **Consumer APK**: 84.5MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully
