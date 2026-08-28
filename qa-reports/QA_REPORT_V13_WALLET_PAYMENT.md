# QA Report V13 — Wallet Payment Feature

**Date**: 2026-08-27
**Scope**: Add PY Wallet as a payment option in food checkout, fix payment method mapping bug
**Status**: Food wallet payment implemented and verified. Event/stays/transit pending future iteration.

---

## Summary

Implemented the highest-impact feature gap from V12: PY Wallet as a payment option in food checkout. Also discovered and fixed a critical payment method mapping bug where COD was being sent as UPI and Razorpay was being sent as Cash to the backend.

### Verification Results
- **Flutter analyze**: 0 errors
- **Backend build**: 0 errors
- **Backend architecture tests**: 289/289 pass
- **Consumer APK**: 84.5MB — built successfully

---

## Issues Found & Fixed

### 1. Payment Method Mapping Bug (CRITICAL)
- **File**: `food_screen.dart` line 601
- **Bug**: The payment method mapping was `paymentMethod == 1 ? 2 : 1` which mapped:
  - COD (1) → Upi (2) ❌ should be Cash (1)
  - Razorpay (0) → Cash (1) ❌ should be Upi (2)
- **Impact**: The backend was receiving wrong payment method values for every food order. COD orders were being treated as UPI and vice versa. This could cause issues with payment tracking, refunds, and financial reporting.
- **Fix**: Used a proper switch expression mapping:
  - COD (1) → Cash (1) ✅
  - Wallet (2) → Wallet (5) ✅
  - Razorpay (0) → Upi (2) ✅

### 2. Wallet Payment Option Added to Food Checkout (FEATURE)
- **Files**: `food_screen.dart`, `CreateFoodOrderHandler.cs`
- **Change**: 
  - **Frontend**: Added "PY Wallet" radio option in the cart summary sheet that:
    - Loads the user's wallet balance on screen open
    - Shows current balance as subtitle
    - Disables the option if balance is insufficient (shows "PY Wallet (Insufficient)")
    - Uses FilledButton "Confirm Order" (no Razorpay needed)
    - Treats wallet payment like COD — order is confirmed immediately
  - **Backend**: Updated `CreateFoodOrderHandler` to handle `PaymentMethod.Wallet`:
    - Loads the user's `UserWallet`
    - Validates sufficient `RealBalance`
    - Debits the wallet via `wallet.DebitReal(order.TotalAmount)`
    - Records a `UserWalletTransaction` with type `FoodOrderPayment`
    - Marks payment as captured (no Razorpay signature needed)

---

## How Wallet Payment Works

1. User opens food cart summary
2. Wallet balance is loaded from `GET /api/user/wallet`
3. If balance ≥ total, "PY Wallet" radio is enabled with balance shown
4. User selects wallet and taps "Confirm Order"
5. Frontend sends `paymentMethod: 5` (Wallet) to `POST /api/food/orders/checkout`
6. Backend handler checks `PaymentMethod.Wallet`:
   - Loads user wallet
   - Validates `wallet.RealBalance >= order.TotalAmount`
   - Calls `wallet.DebitReal(order.TotalAmount)`
   - Creates `UserWalletTransaction` (type: FoodOrderPayment, amount: -total)
   - Marks order payment as captured
7. Frontend shows success overlay and clears cart

---

## Remaining Payment Feature Gaps (Future Iterations)

The following were identified in V12 and are not yet implemented:

1. **Event ticket wallet payment**: Event checkout goes directly to Razorpay without a payment method selector. Adding wallet would require a bottom sheet with payment options.

2. **Stays booking payment UI**: `homestay_detail_screen.dart` calls the booking API directly without any payment flow. Needs a full payment screen.

3. **Transit/rental payment UI**: `transit_screen.dart` creates bookings without payment collection. Needs payment method selection.

4. **Promo code application**: No checkout flow has a promo code input field.

5. **Tip option**: No tip selector for food delivery or rides.

6. **Rides payment method validation**: The payment method selector exists but the selected value isn't validated against the backend.

---

## Files Changed (3)

1. `mobile/lib/features/food/presentation/food_screen.dart` — Wallet payment UI, fixed payment method mapping
2. `backend/src/PondyConnect.Application/Features/FoodDelivery/CreateFoodOrderHandler.cs` — Wallet payment backend handler

---

## Verification

- **Flutter analyze**: 0 errors
- **Backend build**: 0 errors, 0 warnings
- **Backend architecture tests**: 289/289 pass
- **Consumer APK**: 84.5MB — built successfully
