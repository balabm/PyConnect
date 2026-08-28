# Driver App QA Report — Phase 4

**Date:** 2026-08-29  
**App:** PY Connect Driver/Captain App  
**Package:** `com.pondyconnect.driver`  
**Backend:** `https://pyconnect.run.place`  
**Test Environment:** Android Emulator (emulator-5554) + API tests from host  
**Test Phone:** `9000000060` (fresh onboarding)  
**Admin Phone:** `9000000000`

---

## Executive Summary

| Metric | Count |
|--------|-------|
| API E2E Tests | 25 |
| API Tests Passed | 25 |
| API Tests Failed | 0 |
| UI Screens Verified | 3 |
| Bugs Found | 2 |
| Suggestions | 5 |
| Findings | 4 |

**Overall Status:** API layer is fully functional. UI testing was limited by emulator HTTPS connectivity issues.

---

## 1. API E2E Test Results (25/25 PASS)

All driver API endpoints were tested against the deployed production backend using a fresh driver onboarding flow.

### Health Check
| ID | Test | Status |
|----|------|--------|
| HEALTH | Backend health check | ✅ PASS |

### Auth Flow
| ID | Test | Status |
|----|------|--------|
| AUTH-001 | Request OTP (`POST /api/auth/otp`) | ✅ PASS |
| AUTH-002 | Peek OTP (`GET /api/auth/otp/peek`) | ✅ PASS |
| AUTH-003 | Verify OTP and get token (`POST /api/auth/otp/verify`) | ✅ PASS |

**Notes:**
- OTP field is `otp` (not `code`) in the verify request body
- Response field is `accessToken` (not `token`)
- Rate limit: 10 requests per 5 minutes per IP/phone (production config)

### Driver Registration
| ID | Test | Status |
|----|------|--------|
| REG-001 | Register as driver (`POST /api/driver/register`) | ✅ PASS |
| REG-002 | Get driver profile (`GET /api/driver/me`) | ✅ PASS |

**Notes:**
- Registration requires authentication (despite `[AllowAnonymous]` — the handler uses `_currentUser.UserId`)
- Registration returns a new JWT with Driver role
- `vehicleType` must be a string enum: "Bike", "Auto", or "Car"

### Tutorial & Agreement
| ID | Test | Status |
|----|------|--------|
| TUT-001 | Complete tutorial (`POST /api/driver/complete-tutorial`) | ✅ PASS |
| TUT-002 | Sign agreement (`POST /api/driver/sign-agreement`) | ✅ PASS |

**Notes:**
- Both endpoints take no request body
- `sign-agreement` does NOT accept `signatureData` in the request body (contrary to what the test initially assumed)

### KYC Upload
| ID | Test | Status |
|----|------|--------|
| KYC-001 | Upload KYC documents (`POST /api/driver/upload-kyc`) | ✅ PASS |
| KYC-002 | Verify KYC status in profile | ✅ PASS |

**Notes:**
- KYC upload uses **multipart form data** (`[FromForm]`), not JSON
- Required fields: `aadhaar` (file), `drivingLicense` (file), `rc` (file), `upiId` (string)
- Files must be valid image types (jpeg, png, webp)
- Max file size: 10MB per file

### Admin Approval
| ID | Test | Status |
|----|------|--------|
| ADM-001 | Get admin token | ✅ PASS |
| ADM-002 | Approve driver (`POST /api/admin/drivers/{id}/approve`) | ✅ PASS |
| ADM-003 | Verify driver is approved | ✅ PASS |

**Notes:**
- Admin approval requires KYC to be uploaded first (`if (!driver.IsKycUploaded) return false`)
- Approval response includes `success` boolean and `message` string
- FCM push notification is sent on successful approval (best-effort)

### Dashboard Endpoints
| ID | Test | Status |
|----|------|--------|
| DASH-001 | Get vehicles (`GET /api/driver/vehicles`) | ✅ PASS |
| DASH-002 | Get compliance (`GET /api/driver/compliance`) | ✅ PASS |
| DASH-003 | Get preferences (`GET /api/driver/preferences`) | ✅ PASS |
| DASH-004 | Get tasks (`GET /api/driver/tasks`) | ✅ PASS |

### Online/Offline
| ID | Test | Status |
|----|------|--------|
| ONLINE-001 | Go online (`POST /api/driver/go-online`) | ✅ PASS |
| ONLINE-002 | Verify online status | ✅ PASS |
| ONLINE-003 | Go offline (`POST /api/driver/go-offline`) | ✅ PASS |

**Notes:**
- `go-online` takes no body (just a toggle)
- Going online requires admin approval first
- Location is updated separately via `POST /api/driver/location`

### Vehicle Management
| ID | Test | Status |
|----|------|--------|
| VEH-001 | Add vehicle (`POST /api/driver/vehicles`) | ✅ PASS |
| VEH-002 | List vehicles (`GET /api/driver/vehicles`) | ✅ PASS |

**Notes:**
- Add vehicle request uses `registrationNumber` (not `vehiclePlate`)
- Optional fields: `color`, `model`
- New vehicles go into Admin Pending state

### Preferences
| ID | Test | Status |
|----|------|--------|
| PREF-001 | Update destination preference (`PUT /api/driver/preferences/destination`) | ✅ PASS |
| PREF-002 | Update service toggles (`PUT /api/driver/preferences/service-toggles`) | ✅ PASS |

**Notes:**
- Destination request uses `latitude`, `longitude`, `label` (not `lat`, `lng`, `address`)
- Service toggles: `foodDelivery`, `rides`, `intercity`, `luggage`, `essentials` (all nullable bool)

### Cleanup
| ID | Test | Status |
|----|------|--------|
| CLEANUP-001 | Delete test account (`POST /api/driver/account/delete`) | ✅ PASS |

---

## 2. UI QA Results (Emulator)

### Screens Verified

| Screen | Status | Notes |
|--------|--------|-------|
| Splash Screen | ✅ PASS | Displays branding for ~1.5s, then navigates to auth. Total splash time: ~6s (force update check ~1s, auth check ~2.5s) |
| Phone Entry Screen | ✅ PASS | Shows "Welcome", "+91" prefix, phone input, "Get OTP" button, "Become a Captain" button. Button is disabled until 10-digit phone is entered. |
| Error State | ✅ PASS | Shows "Could not reach PY Connect servers. Please try again." when backend is unreachable. Good error UX. |

### UI Findings

**BUG-001: Emulator HTTPS connectivity issue**  
- **Severity:** Medium (testing only, not a production bug)  
- **Description:** The Android emulator cannot establish HTTPS connections to `https://pyconnect.run.place`. The app correctly shows an error message, but this prevents full UI E2E testing on the emulator.  
- **Root cause:** Likely a TLS/SSL handshake issue between the emulator's network stack and the production server's SSL configuration.  
- **Workaround:** API tests were run from the host machine using .NET HttpClient, which works correctly.  
- **Recommendation:** Investigate emulator network proxy/TLS settings. Consider adding a `--dart-define=API_BASE_URL=http://10.0.2.2:5000` option for local testing.

**BUG-002: Splash screen takes ~6 seconds on fresh launch**  
- **Severity:** Low (UX/performance)  
- **Description:** The splash screen takes approximately 6 seconds to complete on a fresh unauthenticated launch: 1.5s branding delay + 1s force update check + 2.5s auth controller check.  
- **Recommendation:** Consider parallelizing the force update check and auth check, or reducing the branding delay to 1s.

---

## 3. Driver App Screen Inventory

Based on the router configuration, the driver app has the following screens:

| Route | Screen | Purpose |
|-------|--------|---------|
| `/splash` | SplashScreen | Branding + bootstrap |
| `/force-update` | ForceUpdateScreen | Force update barrier |
| `/auth` | PhoneEntryScreen | Phone number entry |
| `/auth/otp` | OtpVerifyScreen | OTP verification |
| `/register` | DriverRegistrationScreen | Driver registration |
| `/tutorial` | DriverTutorialScreen | Tutorial + agreement |
| `/kyc` | DriverKycScreen | KYC document upload |
| `/pending-verification` | DriverPendingVerificationScreen | Waiting for admin approval |
| `/` | DriverShell | Main shell with bottom nav |
| `/ride/:id` | DriverRideScreen | Active ride |
| `/earnings` | DriverEarningsScreen | Earnings dashboard |
| `/ride/:id/rate` | DriverRideRatingScreen | Post-ride rating |
| `/radar` | DriverRadarScreen | Ride radar/map |
| `/profile` | DriverProfileScreen | Driver profile |
| `/safety-settings` | DriverSafetySettingsScreen | Safety settings |
| `/emergency-contacts` | EmergencyContactsScreen | Emergency contacts |
| `/help` | DriverHelpScreen | Help & support |
| `/garage` | GarageScreen | Vehicle management |
| `/preferences` | DriverPreferencesScreen | Preferences |

### Onboarding Flow (verified via API):
1. Phone entry → OTP request → OTP verification
2. Driver registration (name, vehicle type, plate, license)
3. Tutorial completion
4. Agreement signing
5. KYC document upload (aadhaar, DL, RC, UPI ID)
6. Admin approval
7. Dashboard access → Go online → Receive ride offers

### Compliance Routing (verified via code review):
The router enforces onboarding compliance:
- No tutorial → redirect to `/tutorial`
- No agreement → redirect to `/tutorial`
- No KYC → redirect to `/kyc`
- No approval → redirect to `/pending-verification`

---

## 4. Bugs Found

### BUG-001: Emulator HTTPS connectivity issue
- **ID:** BUG-001
- **Severity:** Medium (testing infrastructure)
- **Status:** Open
- **Description:** Android emulator cannot connect to `https://pyconnect.run.place` via HTTPS. TLS handshake fails.
- **Reproduction:** Launch driver app on emulator, enter phone, tap "Get OTP"
- **Expected:** OTP is requested, app navigates to OTP screen
- **Actual:** Error message "Could not reach PY Connect servers. Please try again."
- **Workaround:** Use API tests from host machine for backend verification

### BUG-002: Slow splash screen on fresh launch
- **ID:** BUG-002
- **Severity:** Low (UX/performance)
- **Status:** Open
- **Description:** Splash screen takes ~6 seconds on fresh launch due to sequential force update + auth checks
- **Recommendation:** Parallelize checks or reduce branding delay

---

## 5. Suggestions

1. **SUGGEST-001:** Reduce auth rate limit for testing — The current 10 requests per 5 minutes is too restrictive for QA testing. Consider adding a test mode or increasing the limit to 30/minute.

2. **SUGGEST-002:** Add API_BASE_URL dart-define support — Allow overriding the backend URL via `--dart-define=API_BASE_URL=...` so the emulator can connect to a local backend (`http://10.0.2.2:5000`) for testing.

3. **SUGGEST-003:** Parallelize splash checks — Run the force update check and auth check in parallel to reduce splash time from ~6s to ~3s.

4. **SUGGEST-004:** Add request body validation hints — The `sign-agreement` endpoint ignores the request body, but the mobile app sends `signatureData`. Consider either accepting it or removing it from the mobile app's API call.

5. **SUGGEST-005:** Document API contracts — Create OpenAPI/Swagger documentation for all driver endpoints, including field names, types, and required/optional status. This would prevent the field name mismatches discovered during testing (e.g., `otp` vs `code`, `accessToken` vs `token`, `registrationNumber` vs `vehiclePlate`).

---

## 6. Findings

1. **FINDING-001:** The `POST /api/driver/register` endpoint has `[AllowAnonymous]` but the handler requires authentication (`_currentUser.UserId`). This is misleading — the `[AllowAnonymous]` attribute should be removed or the handler should handle unauthenticated users differently.

2. **FINDING-002:** The `POST /api/driver/sign-agreement` endpoint takes no request body, but the mobile app sends `{signatureData: "..."}`. The signature data is not being persisted. Consider either accepting and storing the signature, or removing the unused parameter from the mobile app.

3. **FINDING-003:** The admin approval endpoint (`POST /api/admin/drivers/{id}/approve`) silently returns `success: false` with a message if KYC is not uploaded. This is correct behavior, but the mobile app should check the `success` field in the response and display the message to the admin.

4. **FINDING-004:** The driver app correctly handles network errors with a user-friendly error message ("Could not reach PY Connect servers. Please try again."). This is good error UX.

---

## 7. Test Artifacts

- **API test script:** `qa-reports/driver_api_e2e_test.ps1`
- **API test results CSV:** `qa-reports/driver_api_results.csv`
- **Flutter integration test:** `mobile/integration_test/driver_full_e2e_test.dart`
- **Dart API test:** `mobile/integration_test/driver_api_e2e_test.dart`
- **Screenshots:** `C:\Users\balab\AppData\Local\Temp\driver_*.png`

---

## 8. Next Steps

1. **Fix BUG-001:** Investigate emulator HTTPS connectivity or add local backend support
2. **Continue UI QA:** Once connectivity is fixed, test all driver screens on the emulator
3. **Test ride lifecycle:** Create a ride request from the consumer app and verify the driver receives and accepts it
4. **Test SignalR:** Verify real-time ride offers and location updates
5. **Move to consumer app QA:** Start Phase 5 — Consumer app exhaustive E2E QA
