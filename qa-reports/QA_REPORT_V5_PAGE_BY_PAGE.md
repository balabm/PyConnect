# QA Report V5 — Page-by-Page Findings

**Date:** 2026-08-26
**Tester:** Devin (automated + emulator UI)
**Environment:** emulator-5554 (Android), deployed backend (pyconnect.run.place)
**Builds:** Release APKs with `--dart-define=APP_FLAVOR=<flavor>`

---

## Summary

| App | Pages Tested | Findings | Bugs | Suggestions |
|-----|--------------|----------|------|-------------|
| Consumer | 15 screens | 13 OK, 2 issues | 1 minor | 3 |
| Driver | 6 screens | 5 OK, 1 issue | 1 minor | 2 |
| Partner | 8 screens | 8 OK | 0 | 2 |
| Admin | API-verified | All OK | 0 | 1 |
| **Total** | **29+ screens** | **26 OK, 3 issues** | **2 minor** | **8** |

---

## CONSUMER APP — Page-by-Page Findings

### Page 1: Login Screen
**Status:** OK
- Shows "PY Connect" branding
- "Welcome" greeting
- Phone input with +91 prefix
- "Get OTP" button
- "Continue as Guest" button (consumer-only, correct)
- No "Become a Captain" (driver-only, correctly hidden)
- No "Register your business" (partner-only, correctly hidden)

### Page 2: Home / Vibe Screen
**Status:** OK
- "Good morning!" greeting with location "White Town, Pondicherry"
- "Arriving in Pondy? Let's get you sorted." welcome message
- "Start the Day" / "Artisanal Breakfast" / "Beach Vibes" quick action cards
- Category filters: All, Restobars, Cafes, Pizzerias, Beach Clubs
- "Host a Party" card with DJ · Bartender · Catering · Sound System
- Venue card: "Drunken Daddy, open now, 0% busy" with rating 4.5 (240), distance 0.4 km
- Bottom navigation: Vibe (selected), Food, Transit, Stays, Activity, More

### Page 3: Venue Detail Screen
**Status:** OK
- "Share venue" button
- Priority badge, venue name "Drunken Daddy"
- Rating: 4.5 (240), Open status
- Crowd indicator: "0, Chill now, 0% capacity / 50"
- Address: "5, Rue Romain Rolland, White Town"
- Amenities: DJ, Dance Floor, Smoking Area, WiFi, Air Conditioning
- Dress code: "Smart casual. No flip-flops or beachwear after 7 PM."
- Menu Highlights: Cocktails, Beer Tower, Mocktails
- Location section with "Get Directions" button

### Page 4: Host a Party Screen
**Status:** OK
- "Host an Event" header
- "Create Your Event" description
- Equipment Rentals: "Speakers, lights, fog machines from local vendors"
- Ticket Sales: "Free RSVP or paid tickets with QR check-in"
- Guest Scanner: "Scan QR tickets at the door as the host"
- "Create Event" and "Browse Events" buttons

### Page 5: Create Event Screen
**Status:** ISSUE — Missing fields
- "Create Event" header
- Starts: Tap to select (date/time picker)
- Ends: Tap to select (date/time picker)
- Entry: Free RSVP / Paid Ticket toggle
- "Publish Event" button
- **Finding:** Missing fields for event title, location, capacity, and description. These are essential for creating a meaningful event.

### Page 6: Food Delivery Screen
**Status:** OK
- "Food Delivery" header with "Order History" button
- "Quick Essentials" section
- Category filters: All, Italian, Indian, Chinese, French, Cafe
- Vendor cards with rating, delivery time, fee, item count:
  - Baker Street Bistro (Bakery, 4.3, 15 min, ₹25, 5 items)
  - Brew & Bean (Cafe, 4.5, 10 min, ₹20, 5 items)

### Page 7: Food Menu Screen
**Status:** OK
- "Brew & Bean" header with Share and Order History buttons
- Category filters: All, Coffee, Snacks
- Menu items with ADD buttons:
  - Cold Coffee (₹120, Coffee)
  - Flat White (₹100, Coffee)
  - Iced Latte (₹130, Coffee)
  - Egg Puff (₹50, Snacks)
  - Veg Puff (₹40, Snacks)
- Cart bar appears when items added: "1, 1 Item, ₹120, Checkout"

### Page 8: Cart Summary / Checkout Screen
**Status:** OK
- "Cart Summary" with item count
- Delivery Address: "Current Location, Pondicherry" with Change button
- Payment Method: Razorpay (Online) / Cash on Delivery
- Item Total: ₹120
- Taxes (GST 5%): ₹6
- Platform Fee: ₹2 (with explanation: "This keeps the servers running without charging exorbitant merchant commissions")
- Delivery Fee: ₹20 (with note: "100% to driver, The full delivery fee goes directly to the captain. PY Connect takes zero cut")
- Grand Total: ₹148
- "Slide to Pay ₹148" button

### Page 9: Transit / Ride Screen
**Status:** OK
- 4 tabs: Ride, Pickups, Luggage, Rentals
- Map with "Tap map to set pickup" prompt
- Payment Method: Cash, UPI, Card
- "5 drivers nearby" with Live indicator

### Page 10: Luggage Cloak Network Screen
**Status:** OK
- Description: "Drop bags with trusted partners near Rock Beach and transit hubs for hourly secure storage"
- 7 Cloak Points listed with phone numbers and ₹60/hr pricing:
  - Beach Road Bag Drop, Café Veloute Cloak, Le Clocher Bag Storage, Promenade Cloak Room, Promenade SafeDrop, QA Test Luggage, White Town Luggage Lounge

### Page 11: Scooter Rentals Screen
**Status:** OK
- "Hyper-local Mobility" with description about vetted scooter rental partners
- 3 Rental Partners with ₹140/hr pricing:
  - Promotion Scooter Rentals, QA Test Scooters, Royal Brothers White Town
- "Your Rentals" section with "No rentals yet" empty state

### Page 12: Stays Screen
**Status:** OK
- "Boutique Stays" header with "My Bookings" button
- Check-in/Check-out date pickers
- Guests selector
- Search button
- Location filter: "All areas"
- Stay listings with Verified badges:
  - Rock Beach Sea View Studio (₹3200/night, up to 3 guests)
  - La Maison Blanche (₹2500/night, up to 4 guests)

### Page 13: Activity Screen
**Status:** OK
- "Your Activity" header
- Filters: All, Stays, Food, Rides, Rentals
- "No Activity Yet" empty state with helpful message

### Page 14: More Services Screen
**Status:** OK
- All services listed:
  - My Bookings & Activity
  - Saved Places & Addresses
  - Dietary Preferences
  - App Theme (System, Light, Dark)
  - Safety & Emergency SOS
  - Help & Support
  - Quick Essentials
  - Genie Errand Service
  - Split Payment
  - Explore

### Page 15: Genie Errand Service Screen
**Status:** OK
- "Genie Engine" description: "Type anything you need. A captain will pick it up, buy it, or deliver it."
- "Auth-hold will be placed on your card" note
- "Post Errand" button
- "My Errands" with Refresh button

### Page 16: Split Payment Screen
**Status:** OK
- "Split the Cost" description: "Share a payment link with friends on WhatsApp. Everyone pays their share."
- "Each person pays an equal share" option
- "Create & Share" button
- "My Split Pools" with "No split pools yet" empty state

### Page 17: Safety & Emergency SOS Screen
**Status:** OK
- "Emergency Contacts" header
- Description: "These contacts will be notified with your live location when you trigger SOS during a ride."
- "No emergency contacts" empty state

### Page 18: Help & Support Screen
**Status:** OK
- Emergency section with SOS trigger
- Emergency Contacts button
- Send SOS / Report Issue
- Contact Support
- Quick Help: Scooter Rental Issues, My Activity, Raise a Ticket

### Page 19: Dietary Preferences (Bottom Sheet)
**Status:** OK
- Options: No Preference, Vegetarian, Non-Veg, Vegan
- Cancel / Save buttons

### Page 20: App Theme (Bottom Sheet)
**Status:** OK
- Options: System, Light, Dark
- Cancel / Save buttons

---

## DRIVER APP — Page-by-Page Findings

### Page 1: Login Screen
**Status:** OK
- "PY Connect" branding
- "Welcome" greeting
- Phone input with +91 prefix
- "Get OTP" button
- "Become a Captain" button (driver-only, correct)
- No "Continue as Guest" (correctly hidden)
- No "Register your business" (correctly hidden)

### Page 2: OTP Verification Screen
**Status:** OK
- OTP auto-fill works in release build
- "Auto-filling OTP (test mode)..." indicator visible
- Auto-submits after filling

### Page 3: Dashboard / Tasks Screen
**Status:** ISSUE — SignalR connection warning
- "PY Connect Captain" header
- Online/Offline toggle switch
- "ONLINE" status with "Online — Ready for rides"
- "No tasks available" message
- **Finding:** "Could not connect to live dispatch. You may miss ride offers. Toggle offline/online to retry." — SignalR connection issue on emulator. This may be an emulator networking issue, but the error message is shown to the user which is concerning for production.
- "0" (today's earnings)
- "Hold for SOS" button
- Bottom navigation: Tasks (selected), Active Trip, Earnings, Radar

### Page 4: Earnings Screen
**Status:** OK
- "Earnings" header
- "No Earnings Yet" empty state
- "Complete tasks to see your daily summary here."
- "Start Browsing Tasks" button

### Page 5: Radar Screen
**Status:** OK
- "Demand Radar" header with Refresh button
- "No Surge Zones Right Now" with helpful description
- Refresh button

### Page 6: Active Trip Screen
**Status:** OK
- "No active trip" empty state
- "Accept a task from the Tasks tab to start a trip."

---

## PARTNER APP — Page-by-Page Findings

### Page 1: Login Screen
**Status:** OK
- "PY Connect" branding
- "Register your business" button (partner-only, correct)
- No "Continue as Guest" (correctly hidden)
- No "Become a Captain" (correctly hidden)

### Page 2: Dashboard Screen (PubClub category)
**Status:** OK
- "Drunken Daddy, Pub & Club" header with Sign out button
- "OPEN" status
- Crowd Dashboard: 0 guests, 0% busy, Quiet
- Checked In: 0, Cover Collected: ₹0
- Revenue Today: ₹0, Bookings Today: 0
- "No checked-in guests" empty state
- Bottom navigation: Dashboard, Events, Drinks & VIP, Scanner, Manage

### Page 3: Events Screen
**Status:** OK
- "Event Manager" header with Refresh button
- "No events yet" empty state
- "Create Event" button

### Page 4: Drinks & VIP Screen
**Status:** OK
- "Drinks Menu" header with Refresh button
- Live Crowd: 25%, Chill, with Empty/Full slider
- Guestlist: "No guests on the list yet" with "Add to Guestlist" and "Manual Door Entry" buttons
- Cover Charges info message
- Drinks Menu: "No drinks on the menu yet, Tap + to add your first drink"

### Page 5: Scanner Screen
**Status:** OK
- "Align QR code within the frame" camera scanner view

### Page 6: Manage Screen
**Status:** OK
- "Manage" header
- "Drunken Daddy, Active, · Pub" status
- Operations section:
  - Drinks Menu (Drinks & VIP packages)
  - Live Tables (Cover charge tracking)
  - Occupancy (Update live crowd %)
  - Scanner (Scan tickets & QR)
  - Wallet (Balance & payouts)
  - Marketing (Promotions & flash sales)

### Page 7: Wallet Screen
**Status:** OK
- "Wallet & Credits" header
- Available Balance: ₹0
- Priority Ping Credits: ₹0
- Total Earned / Total Spent
- Transaction History:
  - Priority Ping — Drunken Daddy (-₹499)
  - Initial credit grant (+₹499)

### Page 8: Marketing / Flash Promo Screen
**Status:** OK
- "Flash Promo" bottom sheet
- "Send an instant offer to nearby users"
- 4 promo options:
  - 1+1 on Drinks (Buy one get one free — next 30 min)
  - Free Entry for Women (Waive cover charge until 11 PM)
  - 20% Off Food (Flash discount on all food orders)
  - Happy Hour Extended (Extended to midnight — 50% off cocktails)
- Note: "Promotions auto-expire after the duration"

---

## ADMIN WEB APP — API-Verified Findings

### Dashboard Stats
**Status:** OK
- Available at `/api/admin/dashboard-stats`
- Returns dashboard statistics

### Drivers Management
**Status:** OK
- 10 drivers listed
- Can filter by approval status, online status, KYC uploaded
- Can approve drivers

### Vendors Management
**Status:** OK
- 30 vendors listed
- Can filter by approval status and category
- Can approve vendors

### SOS Alerts
**Status:** OK
- SOS data available

### Support Tickets
**Status:** OK
- 0 tickets (empty state)

### Users Management
**Status:** OK
- 10 users listed

### KYC Reviews
**Status:** OK
- 6 KYC drivers found
- Can approve/reject KYC

### Finance Summary
**Status:** OK
- GMV: 0, Commission Revenue: 0, Driver Payouts Due: 0

### System Health
**Status:** OK
- database=Healthy, signalr=Healthy, redis=Healthy

---

## Bugs Found

### BUG-001 (LOW): Create Event form missing fields
**Screen:** Consumer → Host a Party → Create Event
**Description:** The Create Event form only has Start/End times and Entry type (Free/Paid). Missing essential fields:
- Event title
- Location/venue
- Capacity
- Description
**Impact:** Users cannot create meaningful events without a title or location.
**Suggested fix:** Add title, location, capacity, and description fields to the form.

### BUG-002 (LOW): SignalR dispatch connection warning on driver dashboard
**Screen:** Driver → Dashboard
**Description:** "Could not connect to live dispatch. You may miss ride offers. Toggle offline/online to retry." appears on the driver dashboard.
**Impact:** May be an emulator networking issue, but the error message is shown to users which could cause confusion.
**Suggested fix:** Investigate SignalR connection reliability. Consider a more user-friendly message or auto-retry logic.

---

## Suggestions for Next Iteration

### Consumer App
1. **Add event title and location fields to Create Event form** — currently missing essential fields
2. **Add "Order History" screen test** — the button exists but wasn't tested with actual orders
3. **Test ride booking flow end-to-end** — set pickup, select vehicle, request ride, track driver

### Driver App
1. **Improve SignalR connection error handling** — auto-retry instead of showing a persistent warning
2. **Add driver profile screen** — no profile/settings screen was found in the bottom navigation

### Partner App
1. **Add analytics dashboard** — no analytics endpoint or screen found for partners
2. **Test drinks menu creation flow** — the "Tap + to add your first drink" button wasn't tested

### Admin Web App
1. **Fix Flutter web rendering in Playwright** — the admin web app doesn't render properly in automated testing tools due to Flutter's semantics placeholder. Consider adding a non-Flutter admin interface or improving web accessibility.

---

## Commits in This QA Cycle

| Commit | Description |
|--------|-------------|
| `b74f83b` | Fix GoOnline security bug — require admin approval and KYC |
| `6cc5fce` | Add QA Report V4 with screenshots |
