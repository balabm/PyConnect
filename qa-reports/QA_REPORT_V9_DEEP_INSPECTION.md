# QA Report V9 — Deep Inspection & Flaw Fixes

**Date**: 2026-08-27
**Scope**: Deep inspection of error handling, form validation, loading/empty/error states across all apps
**Status**: All critical flaws found and fixed, verified

---

## Summary

This iteration performed a deep code inspection using parallel subagents that analyzed 20+ files across all apps for:
1. Error handling gaps in API calls
2. Missing loading/empty/error states
3. Form validation and input issues

Found and fixed 10 distinct flaws across 8 files.

### Verification Results
- **Flutter analyze**: 0 errors (189 info/warnings — all pre-existing)
- **Backend architecture tests**: 289/289 pass
- **Consumer APK**: 84.4MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully

---

## Issues Found & Fixed

### 1. Driver Ride Screen — `catch (_)` Referencing Undefined `$e` (CRITICAL)
- **File**: `driver_ride_screen.dart`
- **Bug**: 4 catch blocks used `catch (_)` (which discards the error) but then referenced `$e` in snackbar messages — this would throw an undefined variable error at runtime
- **Lines affected**: 220, 366, 420, 605
- **Fix**: Changed `catch (_)` to `catch (e)` so the error variable is properly bound
- **Severity**: Critical (runtime crash on error)

### 2. Fleet Management — Silent Error Swallowing
- **File**: `fleet_management_screen.dart` line 63
- **Bug**: `catch (_) {}` completely swallowed errors with no logging or user feedback
- **Fix**: Changed to `catch (e) { debugPrint('Failed to load fleet: $e'); }`
- **Severity**: Medium (silent failure, no debugging info)

### 3. Split Payment — Silent Error on Pool Loading
- **File**: `split_payment_screen.dart` line 60
- **Bug**: `catch (_)` silently set loading to false but showed no error message
- **Fix**: Added error snackbar with the error message
- **Severity**: Medium (user sees empty list with no explanation)

### 4. Vendor Promotions — No Discount Range Validation
- **File**: `vendor_promotions_screen.dart`
- **Bug**: Discount percentage field accepted any number including negative values and values > 100%
- **Fix**: Added validation: discount must be between 1 and 100
- **Severity**: High (could create invalid promotions with negative or >100% discounts)

### 5. Vendor Flash Promotions — No Duration Range Validation
- **File**: `vendor_promotions_screen.dart`
- **Bug**: Duration field accepted any number including negative values
- **Fix**: Added validation: duration must be between 5 and 480 minutes (8 hours max)
- **Severity**: High (could create invalid flash sales)

### 6. Emergency Contacts — No Phone Number Validation
- **File**: `emergency_contacts_screen.dart` line 253
- **Bug**: Phone number field had no validation — accepted any input including empty or non-numeric
- **Fix**: Added validation for 10-digit phone number and non-empty name with user-facing error messages
- **Severity**: High (invalid emergency contacts could fail when needed)

### 7. Driver Earnings — Missing Withdrawal Validation Feedback
- **File**: `driver_earnings_screen.dart` line 932
- **Bug**: Withdrawal button was disabled when amount was invalid, but no text explained why
- **Fix**: Added helper text showing "Minimum withdrawal is ₹100" or "Amount exceeds available balance"
- **Severity**: Medium (user doesn't know why button is disabled)

### 8. Scheduled Rides — Past Time Validation
- **File**: `scheduled_rides_screen.dart` line 182
- **Bug**: Date picker prevented past dates but user could select today with a time that already passed
- **Fix**: Added validation requiring scheduled time to be at least 30 minutes from now, with user-facing error message
- **Severity**: High (could schedule rides in the past)

### 9. Referral Screen — Missing Apply Code UI
- **File**: `referral_screen.dart`
- **Bug**: Backend API `POST /api/referrals/apply` existed but the UI had no way to apply a referral code — only showed the user's own code for sharing
- **Fix**: Added "Apply Code" section with text input, apply button, loading state, and success/error feedback. Refreshes referral info on success.
- **Severity**: Medium (unimplemented feature)

### 10. Scheduled Rides — Build Context Async Warning
- **File**: `scheduled_rides_screen.dart` line 184
- **Bug**: `ScaffoldMessenger.of(ctx)` called after `await` without checking `ctx.mounted`
- **Fix**: Added `if (!ctx.mounted) return;` before the ScaffoldMessenger call
- **Severity**: Low (analyzer warning)

---

## Issues Identified But Not Fixed (Lower Priority)

The subagents identified additional patterns that are acceptable but could be improved:

### RefreshIndicator Callbacks Without Try/Catch (17 screens)
- **Pattern**: `onRefresh: () => ref.refresh(provider.future)` — if the API fails, the spinner stops but no error snackbar is shown
- **Impact**: Low — the underlying AsyncValue will transition to error state and the screen's `.when()` handler will show the error
- **Recommendation**: Add try/catch with error snackbar for explicit user feedback during pull-to-refresh

### `.valueOrNull ?? defaultValue` Pattern (6 locations)
- **Pattern**: Used in admin live ops and venue detail to get supplementary data (map markers, etc.)
- **Impact**: Low — these are non-critical supplementary displays where empty is an acceptable fallback
- **Recommendation**: Consider using `.when()` for more explicit state handling

### Vendor Registration Form Validation
- **Pattern**: Uses custom validation getters instead of Flutter's Form.validate()
- **Impact**: Low — validation works correctly but doesn't use declarative validators
- **Recommendation**: Refactor to use Form validators in a future iteration

---

## Files Changed

### Modified Files (8)
1. `mobile/lib/features/driver/presentation/driver_ride_screen.dart` — Fixed 4 `catch (_)` → `catch (e)` 
2. `mobile/lib/features/vendor/presentation/fleet_management_screen.dart` — Added debug logging
3. `mobile/lib/features/split_payments/presentation/split_payment_screen.dart` — Added error snackbar
4. `mobile/lib/features/vendor/presentation/vendor_promotions_screen.dart` — Added discount/duration validation
5. `mobile/lib/features/rides/presentation/emergency_contacts_screen.dart` — Added phone validation
6. `mobile/lib/features/driver/presentation/driver_earnings_screen.dart` — Added validation feedback text
7. `mobile/lib/features/rides/presentation/scheduled_rides_screen.dart` — Added past time validation + mounted check
8. `mobile/lib/features/referral/presentation/referral_screen.dart` — Added apply code section

---

## Verification

- **Flutter analyze**: 0 errors, 189 info/warnings (all pre-existing)
- **Backend architecture tests**: 289/289 pass
- **Consumer APK**: 84.4MB — built successfully
- **Driver APK**: 84.4MB — built successfully
- **Partner APK**: 84.4MB — built successfully
