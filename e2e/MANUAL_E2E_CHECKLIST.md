# PondyConnect — Manual E2E Test Checklist

This checklist covers cross-device flows that Playwright cannot automate:
physical QR scanning, SignalR on emulators, and 4-instance simultaneous testing.

---

## 1. Environment Setup (4 Instances)

### 1.1 Backend
```powershell
cd backend\src\PondyConnect.Api
dotnet run --urls="http://localhost:5000"
```
- [ ] Backend starts on port 5000
- [ ] Swagger UI accessible at `http://localhost:5000/swagger`
- [ ] Database seeded (check venues appear in `/api/venues`)
- [ ] Redis connection — if Redis is empty string in appsettings, in-memory lock fallback works

### 1.2 Admin/Vendor PWA (Chrome — Desktop)
```powershell
cd e2e\scripts
.\build-web.ps1
# Serve the built web app
npx http-server ../mobile/build/web -p 8090 --cors
```
- [ ] Web app loads at `http://localhost:8090`
- [ ] Login as Vendor: phone `9000000001` (Fuoco Pizzeria)
- [ ] Vendor dashboard shows active orders and venue stats
- [ ] Availability toggle works (calls `PUT /api/vendor/venues/{id}/availability`)

### 1.3 Consumer App (Chrome — Second Window or Emulator)
- [ ] Open `http://localhost:8090` in a second Chrome window/incognito
- [ ] Login as Consumer: phone `9000000099` (Test Tourist)
- [ ] Vibe tab shows venue list (Drunken Daddy, Le Club, etc.)
- [ ] Food tab shows restaurant list (Fuoco Pizzeria, etc.)

### 1.4 Driver App (Android Emulator or Chrome)
- [ ] If Android emulator: `flutter run` with default config (uses `10.0.2.2:5000`)
- [ ] If Chrome: open `http://localhost:8090` in third window
- [ ] Login as Driver: phone `9000000050` (Suresh Kumar)
- [ ] Driver home screen shows "Online" toggle
- [ ] Location updates sent every 3-5 seconds

---

## 2. Master Scenario 1: Zero-Commission Late-Night Flow

### 2.1 Consumer Places Food Order
- [ ] Consumer app → Food tab → tap "Fuoco Pizzeria"
- [ ] Menu loads with late-night items (🌙 icon on Margherita, Shawarma, Wings)
- [ ] Add 1x Woodfired Margherita (₹450) + 1x Chicken Shawarma (₹180)
- [ ] Subtotal = ₹630
- [ ] Tap Checkout
- [ ] Order confirmation shows:
  - [ ] Subtotal: ₹630
  - [ ] Delivery Fee: ₹40 (or ₹0 if Pro member)
  - [ ] Late Night Driver Bonus: ₹30 (if between 11PM–3AM IST) or ₹0
  - [ ] Platform Fee: ₹0
  - [ ] Total: ₹630 + ₹40 + ₹30 + ₹0 = ₹700 (or ₹660 if not late night)

### 2.2 Vendor Accepts Order
- [ ] Vendor PWA → Dashboard → new order appears in "Active Orders"
- [ ] Order status: "Placed"
- [ ] Tap Accept → status changes to "Accepted"
- [ ] Tap "Start Preparing" → status changes to "Preparing"

### 2.3 Vendor Marks OutForDelivery → Driver Gets SignalR Offer
- [ ] Vendor taps "Send for Delivery" / status → "OutForDelivery"
- [ ] **WATCH**: Driver app should receive `FoodDeliveryOffer` event within 2 seconds
- [ ] Driver app shows food delivery task card with:
  - [ ] Restaurant name: "Fuoco Pizzeria"
  - [ ] Pickup address
  - [ ] Delivery address
  - [ ] Driver earnings: ₹40 + ₹30 = ₹70 (or ₹40 if not late night)

### 2.4 Settlement Verification
- [ ] Open `http://localhost:5000/swagger`
- [ ] GET `/api/orders/{orderId}` with consumer token
- [ ] Verify:
  - [ ] `vendorPayout` = `subTotal` (₹630) — 100% to vendor
  - [ ] `deliveryFee` + `lateNightDriverBonus` = driver payout — 100% to driver
  - [ ] `platformFee` = ₹0 — zero commission

---

## 3. Master Scenario 2: VIP Nightlife Flow

### 3.1 Consumer Books Venue Entry
- [ ] Consumer app → Vibe tab → search "Drunken Daddy"
- [ ] Tap Drunken Daddy venue card
- [ ] Select 4 seats
- [ ] Tap Book / Continue
- [ ] Booking confirmed → Pass Token displayed (actual passToken from API, not truncated bookingId)
- [ ] Note the pass token value

### 3.2 Capacity Overflow Test
- [ ] Consumer tries to book 55 seats at Drunken Daddy (maxCapacity: 50)
- [ ] **Expected**: Error message "Venue 'Drunken Daddy' is at full capacity."
- [ ] **Expected**: HTTP 409 Conflict from API
- [ ] UI shows error message (not a crash)

### 3.3 Vendor QR Scan — Valid Ticket
- [ ] Vendor PWA → Scanner screen (or open scanner on second device)
- [ ] Consumer shows pass token on their screen
- [ ] Vendor scans QR code
- [ ] **Expected**: Green overlay with "VALID" + "Nightlife - [User Name]"
- [ ] Success sound plays
- [ ] Venue checked-in count increments by 4

### 3.4 Vendor QR Scan — Duplicate Rejection
- [ ] Vendor scans the same QR code again
- [ ] **Expected**: Red overlay with "Already used."
- [ ] Error sound plays

### 3.5 Vendor QR Scan — Invalid QR
- [ ] Vendor scans a random/non-PondyConnect QR code
- [ ] **Expected**: Red overlay with "Unknown ticket."
- [ ] Error sound plays

---

## 4. SignalR Real-Time Verification

### 4.1 Driver Location Updates
- [ ] Driver app online → location updates every 3-5s
- [ ] Backend logs show `UpdateLocation` hub invocations
- [ ] Admin dispatch screen (if open) shows driver markers moving

### 4.2 Ride Offer Dispatch (if testing rides)
- [ ] Consumer books a ride
- [ ] Driver app receives `RideOffer` event within 2 seconds
- [ ] Ride offer sheet appears with pickup/dropoff/fare
- [ ] Driver taps Accept → consumer sees "Driver Assigned" within 2 seconds

### 4.3 Food Delivery Dispatch
- [ ] Vendor marks order "OutForDelivery"
- [ ] Driver app receives `FoodDeliveryOffer` event within 2 seconds
- [ ] Food delivery task card appears with restaurant name and earnings

### 4.4 SignalR Reconnection
- [ ] Turn off Wi-Fi on driver emulator for 5 seconds
- [ ] Turn Wi-Fi back on
- [ ] SignalR auto-reconnects (`.withAutomaticReconnect()`)
- [ ] Driver starts receiving offers again within 10 seconds

---

## 5. Geofencing Test

### 5.1 In-Service-Area Booking
- [ ] Consumer at White Town (11.9356, 79.8301) — within 3km radius
- [ ] Book venue/ride/food → succeeds

### 5.2 Out-of-Service-Area Rejection
- [ ] Set consumer location to Chennai (13.0827, 80.2707) — outside 3km
- [ ] Attempt to book ride → **Expected**: 422 Unprocessable Entity
- [ ] Error message mentions "service area"

---

## 6. Timezone Verification

### 6.1 Late-Night Bonus Calculation
- [ ] Check `OrderPricingService.cs` — uses `orderTime.AddMinutes(330)` for IST conversion
- [ ] Place a food order at 11:30 PM IST (UTC 6:00 PM) → lateNightDriverBonus = ₹30
- [ ] Place a food order at 10:59 PM IST (UTC 5:29 PM) → lateNightDriverBonus = ₹0
- [ ] Place a food order at 2:59 AM IST (UTC 9:29 PM) → lateNightDriverBonus = ₹30
- [ ] Place a food order at 3:01 AM IST (UTC 9:31 PM) → lateNightDriverBonus = ₹0

---

## 7. Vendor Venue Availability Toggle

### 7.1 Toggle Off (Close Venue)
- [ ] Vendor PWA → Dashboard → toggle "Accepting Orders" switch to OFF
- [ ] **Expected**: API call `PUT /api/vendor/venues/{venueId}/availability`
- [ ] SnackBar shows "Orders paused — kitchen closed"
- [ ] Venue `IsActive` = false in database
- [ ] Consumer cannot see the venue in venue list (filtered by IsActive)

### 7.2 Toggle On (Reopen Venue)
- [ ] Vendor toggles back to ON
- [ ] **Expected**: API call succeeds, venue `IsActive` = true
- [ ] SnackBar shows "Now accepting orders"
- [ ] Consumer can see the venue again

---

## 8. Admin Dispatch Screen (Optional)

- [ ] Login as Admin (if admin auth is configured)
- [ ] Admin dispatch screen shows:
  - [ ] Live driver heatmap
  - [ ] Active orders pane
  - [ Venue status pane
  - [ ] Surge control
  - [ ] Panic queue (SOS tickets)
- [ ] SignalR AdminHub connection active
- [ ] Real-time updates when bookings/orders are created

---

## Test Results Summary

| Scenario | Step | Pass/Fail | Notes |
|----------|------|-----------|-------|
| 1. Late-Night Flow | 2.1 Consumer order | | |
| 1. Late-Night Flow | 2.2 Vendor accept | | |
| 1. Late-Night Flow | 2.3 Driver dispatch | | |
| 1. Late-Night Flow | 2.4 Settlement | | |
| 2. VIP Nightlife | 3.1 Booking | | |
| 2. VIP Nightlife | 3.2 Capacity overflow | | |
| 2. VIP Nightlife | 3.3 QR scan valid | | |
| 2. VIP Nightlife | 3.4 QR scan duplicate | | |
| 2. VIP Nightlife | 3.5 QR scan invalid | | |
| 3. SignalR | 4.1 Location updates | | |
| 3. SignalR | 4.3 Food dispatch | | |
| 3. SignalR | 4.4 Reconnection | | |
| 4. Geofencing | 5.1 In-area | | |
| 4. Geofencing | 5.2 Out-of-area | | |
| 5. Timezone | 6.1 Late-night bonus | | |
| 6. Venue Toggle | 7.1 Close venue | | |
| 6. Venue Toggle | 7.2 Reopen venue | | |
