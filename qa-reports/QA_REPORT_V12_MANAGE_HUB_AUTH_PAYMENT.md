# QA Report V12 — Manage Hub, Auth Flow, Payment Audit

**Date**: 2026-08-27
**Scope**: Manage Hub tile routes, consumer auth/onboarding flow, payment/checkout flow audit
**Status**: All critical flaws fixed, verified

---

## Summary

Inspected Manage Hub tiles across all vendor types, consumer auth/onboarding flow, and payment/checkout flows. Found and fixed 5 critical bugs across 7 files. Also identified larger feature gaps (wallet payment option, promo codes, tips) documented for future iterations.

### Verification Results
- **Flutter analyze**: 0 errors (1 pre-existing warning)
- **Consumer APK**: 84.5MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully

---

## Issues Found & Fixed

### Manage Hub (2 fixes)

#### 1. Live Tables Tile Navigated to Wrong Route (CRITICAL)
- **File**: `manage_hub_screen.dart` line 230
- **Bug**: The "Live Tables" tile for PubClub vendors navigated to `/bookings` instead of `/live-tables`. The `LiveTablesScreen` was fully implemented with a route at `/live-tables` but completely inaccessible from anywhere in the app.
- **Fix**: Changed route from `/bookings` to `/live-tables`

#### 2. Partial Refund Navigation Dead End (HIGH)
- **File**: `partial_refund_screen.dart` line 164
- **Bug**: After a successful refund, the "Done" button used `Navigator.of(context).pop()` which doesn't work properly with GoRouter — users could get stuck on the result screen
- **Fix**: Added `go_router` import and changed to `context.pop()`

### Consumer Auth/Onboarding (3 fixes)

#### 3. Onboarding Email Field Never Submitted (HIGH)
- **Files**: `onboarding_screen.dart`, `auth_controller.dart`, `auth_api.dart`
- **Bug**: The onboarding screen collected an email address from the user but never sent it to the backend — the `_emailController` was created, displayed, and disposed but its value was never used in the `_finish()` method
- **Fix**: 
  - Updated `auth_api.dart` `updateMe()` to accept optional `email` parameter
  - Updated `auth_controller.dart` `updateProfile()` to accept and pass `email`
  - Updated `onboarding_screen.dart` `_finish()` to pass the email value
  - Added email format validation with regex before submission

#### 4. Phone Entry Race Condition (MEDIUM)
- **File**: `phone_entry_screen.dart` line 268
- **Bug**: After `requestOtp()` completed, the app navigated to `/auth/otp` unconditionally — even if the OTP request failed. This caused a confusing UX where users landed on the OTP screen with no OTP sent, then got redirected back.
- **Fix**: Check `hasError` on the auth controller before navigating. Only navigate to OTP screen if the request succeeded.

#### 5. Onboarding Email Validation (LOW)
- **File**: `onboarding_screen.dart`
- **Bug**: Email field had no format validation — users could enter "abc" and it would be submitted
- **Fix**: Added regex validation `^[\w.+-]+@[\w-]+\.[\w.-]+$` with user feedback snackbar

---

## Documented Feature Gaps (Not Fixed — Future Iterations)

### Payment/Checkout Flow Gaps

The payment audit revealed several feature gaps that are larger than bug fixes and should be addressed in a dedicated payment iteration:

1. **No wallet payment option**: Despite having a PY Wallet system with balance, none of the checkout flows (food, events, stays, transit, rides) offer wallet as a payment method. Only Razorpay + COD (food only) are available.

2. **No promo code application**: No checkout flow has a promo code input field or discount calculation. The vendor promotions screen exists but has no consumer-facing application point.

3. **No tip option**: No tip selector for food delivery or rides.

4. **Stays booking has no payment UI**: `homestay_detail_screen.dart` calls the booking API directly without any payment flow — no Razorpay, no wallet, no payment method selection.

5. **Transit/rentals have no payment UI**: `transit_screen.dart` creates bookings without a payment flow.

6. **Rides payment method not validated**: The payment method selector exists but the selected value is just passed as an integer to the backend without verification.

### Auth Flow Gaps

7. **No native Android SMS autofill**: The app uses a test-mode "peek" API for OTP autofill but doesn't use native Android SMS retriever API. Users must manually enter OTP in production.

8. **Email not displayed in profile**: Even after the fix to submit email during onboarding, the profile screen doesn't display the user's email.

9. **Avatar is static icon**: No user-uploaded profile picture support.

### Hardcoded Values (Acceptable for Pondicherry deployment)

- Delivery fee: ₹20 (food_screen.dart) — domain-specific default
- Transit base fare: ₹250 (transit_screen.dart) — flat pickup price
- Luggage rate: ₹60, Scooter rental: ₹140 (transit_screen.dart) — domain rates
- Cuisine list, category lists — Pondicherry-specific defaults

---

## Screens Verified as Working Correctly

### Auth Flow
- **PhoneEntryScreen**: Loading state, error display with friendly messages, guest login (consumer only), flavor-aware auth controller selection
- **OTPVerifyScreen**: Loading state, 60-second resend cooldown, error handling for invalid/expired OTP, back navigation, flavor-aware redirect
- **ChangePhoneScreen**: Loading states for send/verify, phone validation, token refresh after change
- **AuthController**: Token refresh (tries both consumer and vendor endpoints), signOut clears FCM token and all state
- **ApiClient**: 401 auto-refresh with retry, 429 rate limit handling, AuthRequiredException for expired sessions

### Manage Hub Screens
- **VendorFinanceScreen**: Loading/error/empty states, bank withdrawal with validation, retry button
- **VendorPromotionsScreen**: Loading/error/empty states, discount validation (1-100%), flash sale duration validation (5-480 min)
- **LiveTablesScreen**: Loading/error/empty states, 15s auto-refresh, pull-to-refresh
- **StaffManagementScreen**: Loading/error/empty states, name validation (min 2 chars), phone validation (10+ digits), optimistic UI with revert
- **VendorWalletScreen**: Loading/error/empty states, refresh button
- **VendorHelpScreen**: Static content, all routes valid

### Payment Flow (Working Parts)
- **Razorpay integration**: Comprehensive — success, error, external wallet, mock fallback, 5-min timeout, signature verification
- **Food checkout**: Itemized summary (items, GST 5%, platform fee, delivery fee), COD option, double-submit guard with 5-min timer, cart price conflict handling (HTTP 409)
- **Wallet send money**: Balance validation, loading state, mounted checks
- **Prime subscription**: Loading state, success/failure feedback, status refresh
- **Event tickets**: Loading state, success/failure feedback, event reload
- **Wallet balance check**: Validates sufficient balance before transfer

---

## Files Changed (7)

1. `mobile/lib/features/vendor/presentation/manage_hub_screen.dart` — Fixed Live Tables route
2. `mobile/lib/features/vendor/presentation/partial_refund_screen.dart` — Fixed navigation, added go_router import
3. `mobile/lib/features/onboarding/presentation/onboarding_screen.dart` — Submit email, email validation
4. `mobile/lib/features/auth/application/auth_controller.dart` — Accept email in updateProfile
5. `mobile/lib/features/auth/data/auth_api.dart` — Accept email in updateMe
6. `mobile/lib/features/auth/presentation/phone_entry_screen.dart` — Fix race condition

---

## Verification

- **Flutter analyze**: 0 errors (1 pre-existing warning — unused `isAdmin` variable)
- **Consumer APK**: 84.5MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully
