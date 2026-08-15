# PY CONNECT: MASTER PRODUCT REQUIREMENTS DOCUMENT (PRD) & TECHNICAL SPECIFICATION

**Platform Identity:** PY Connect

**Primary Accent Color:** Pondy Emerald (`#00D290`)

**Design Standard:** Default Light Mode (`#FFFFFF`), Optional High-Contrast OLED Dark Mode (`#000000`), Strict Material 3 Typography & Spacing.

---

## 1. System Foundation & Cross-Platform Architecture

### 1.1 Global Design System Tokens

* **Light Theme (Default):**
* `scaffoldBackgroundColor`: `#FFFFFF`
* `surfaceColor`: `#FFFFFF` with elevation shadow `Colors.black.withOpacity(0.04)`, `blurRadius: 12`
* `primaryColor`: `#00D290` (Pondy Emerald) — *used strictly for primary CTA buttons, active radio/checkbox states, and live tracking badges*
* `textPrimary`: `#111827` (Deep Charcoal)
* `textMuted`: `#6B7280` (Slate Grey)
* `dividerColor`: `#F3F4F6`


* **Dark Theme (OLED Black):**
* `scaffoldBackgroundColor`: `#000000`
* `surfaceColor`: `#121212` with 1px border `rgba(255, 255, 255, 0.08)`
* `primaryColor`: `#00D290`
* `textPrimary`: `#FFFFFF`
* `textMuted`: `#9CA3AF`


* **Component Rules:**
* All cards: `BorderRadius.circular(16)`.
* All bottom sheets: `BorderRadius.vertical(top: Radius.circular(24))`, `isScrollControlled: true`.
* **Zero Generic Grey/Teal Boxes:** Every image container must use `AppNetworkImage` wrapping `CachedNetworkImage` with a sweeping `Shimmer` placeholder and a high-resolution local asset fallback (never an empty icon placeholder).
* **SafeArea Protection:** Every screen header, floating back button, and bottom button bar must be wrapped in `SafeArea` to prevent status-bar and gesture-bar collisions.



### 1.2 Authentication, Token Persistence & Guest Checkout

* **Guest Mode Architecture:**
* Unauthenticated users can freely browse home, venues, food menus, stays, and rentals, and add items to carts.
* **Seamless Interception:** Tapping "Checkout", "Book", or "Request Ride" must NOT route to a full login page. It must open a `ModalBottomSheet` for Phone + OTP input.
* **Post-Auth Resume:** Upon successful OTP verification, the bottom sheet dismisses, session tokens are saved, and the pending checkout action executes automatically without losing cart data.


* **Token Persistence & Interceptors:**
* Store JWT and Refresh Tokens in `FlutterSecureStorage` (Mobile) and `SharedPreferences` / `localStorage` (Web).
* Dio/HTTP interceptor must automatically append `Authorization: Bearer <token>` to all outgoing requests.
* Handle `401 Unauthorized` via silent refresh token exchange; if refresh fails, gracefully open the login bottom sheet.
* Handle `403 Forbidden` with a contextual error toast (e.g., "Account pending verification") rather than raw HTTP error text.



### 1.3 Payment Gateway (Razorpay) Lifecycle

* **Lifecycle Rules:**
* Razorpay SDK must be instantiated globally or in `initState` with handlers for `EVENT_PAYMENT_SUCCESS`, `EVENT_PAYMENT_ERROR`, and `EVENT_EXTERNAL_WALLET`.
* Never call `_razorpay.open()` inside an async button press without checking initialization state.
* Read `RAZORPAY_KEY_ID` from environment variables (`--dart-define=RAZORPAY_KEY_ID=...`).


* **Backend Verification Loop:**
1. Client calls `POST /api/payments/create-order` $\rightarrow$ receives `razorpay_order_id`.
2. Client launches Razorpay checkout sheet.
3. On success, client sends `razorpay_payment_id`, `razorpay_order_id`, and `razorpay_signature` to `POST /api/payments/verify`.
4. Backend cryptographically validates HMAC SHA256 signature before transitioning order status to `Paid`.



---

## 2. Consumer Super-App Specification

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CONSUMER APP SHELL                              │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────┤
│  1. Vibe     │  2. Food &   │  3. Rides    │  4. Stays    │  5. Hub    │
│  (Explore)   │  Essentials  │  (Mobility)  │  (Hotels)    │  (Activity)│
└──────────────┴──────────────┴──────────────┴──────────────┴────────────┘

```

### 2.1 Tab 1: Vibe & Nightlife (Home Screen)

* **Header:** Dynamic greeting + Live location chip ("White Town, Pondicherry") + Notification bell + Cart badge.
* **Search & Category Bar:** Search input + Horizontal pill selectors (`All`, `Restobars`, `Cafes`, `Pizzerias`, `Beach Clubs`, `Colonial Dining`).
* **Curated Carousels:** High-res image cards for "Trending Tonight", "Live Music & DJ", and "Happy Hours" (replacing generic colored blocks).
* **Venue Card Components (Zomato-Style):**
* Top: 16:9 full-width photo with overlay chips (`● Open` in green, `★ Priority` in emerald).
* Bottom: Venue Name, Category, Distance (km), Dynamic Crowd Meter (`Chill • 15%`, `Lively • 60%`, `Packed • 95%`), Rating (`★ 4.5 (240)`).


* **Venue Detail Page:**
* `SliverAppBar` with 16:9 hero image gallery and gradient scrim for back button contrast.
* **Proactive Capacity Gate:** Real-time capacity bar. If `capacity >= 100%`, display a red banner `"Venue at Full Capacity"` and disable the booking CTA.
* Sections: Operating Hours, Amenities Grid (`WiFi`, `AC`, `Smoking Area`, `Dance Floor`), Dress Code notice, Food & Drink menu previews, and an interactive location map with "Get Directions".
* **Cover / Table Booking Sheet:** Guest count stepper, date & time slot selector, cover charge breakdown, and Razorpay checkout trigger.



### 2.2 Tab 2: Food & Quick Essentials

* **Categorization:** Segmented control toggling between **Food Delivery** (Restaurants, Cafes, Pizzerias) and **Quick Essentials** (24x7 Convenience, Water Cans, Pharmacy, Travel Essentials).
* **Restaurant / Store Card:** 16:9 cover photo, pure veg/non-veg badge, delivery time (`20-30 min`), pricing tier (`₹₹`), and discount tags.
* **Menu Interface:**
* Category jumping tab bar (e.g., *Starters, Wood-Fired Pizza, Beverages*).
* Item Cards: Title, Description, Price, Veg/Non-Veg icon, and a right-aligned 1:1 photo with an embedded `[ + ADD ]` button.
* Item Customization Sheet: Radio buttons for variants (e.g., Size: 10", 12") and checkboxes for add-ons (e.g., Extra Cheese).


* **Cart & Checkout Bottom Sheet (Swiggy-Style):**
* Itemized breakdown with quantity modifiers (`- 1 +`).
* Delivery address selector with "Change Address" trigger.
* Bill Details: Item Total + Delivery Partner Fee + Platform Fee (₹5) + Taxes & Charges = **Grand Total**.
* Payment Selector: Radio options for `UPI / Cards / Netbanking (Razorpay)` and `Cash on Delivery`.
* CTA Button: Slide-to-Pay or `[ Pay ₹XXX ]`.



### 2.3 Tab 3: Rides (Mobility)

* **Spatial Edge-to-Edge Map:**
* Map widget rendering CartoDB Positron (Light) or Dark Matter (Dark) vector tiles filling 100% of the screen behind transparent status bars.
* Live GPS user location puck with animated pulsing ring.
* Live nearby driver markers (Bike, Auto, Cab icons) updating in real-time.


* **Automatic Geocoding & Address Selection:**
* On screen load, fetch device GPS via `Geolocator` and reverse-geocode to set the exact street address in `Pickup` (e.g., *"12, Rue Romain Rolland"*).
* Search Autocomplete: Full-screen search overlay for Dropoff with recent locations, saved places (`Home`, `Work`, `Hotel`), and landmark pins.


* **Ride Options Sheet (Uber-Style):**
* Anchored, draggable bottom sheet containing:
* Route Stats: Distance (`2.1 km`) and ETA (`5 min`).
* Vehicle Selector Carousel:
* `Bike Taxi`: Fare, ETA, seat capacity (1).
* `Auto Rickshaw`: Fare, ETA, seat capacity (3).
* `Cab / Prime`: Fare, ETA, AC badge, seat capacity (4).


* Payment Method Toggle: `Cash` | `UPI` | `Card`.
* Primary CTA: Full-width button `[ Request <VehicleType> • ₹<Fare> ]`.


* **Active Ride Tracking Overlay:**
* Once assigned: Driver Name, Photo, Vehicle Number Plate, Rating, Call Driver button, and **4-Digit Start OTP**.
* Map renders dual-layer polyline route from Driver $\rightarrow$ Pickup $\rightarrow$ Dropoff.



### 2.4 Tab 4: Boutique Stays & Homestays

* **Search Header:** Check-In date, Check-Out date, Guest counter, and Location filter (*White Town, Heritage French Quarter, Auroville Road, Beach Road*).
* **Property Card:**
* 16:9 high-resolution photography carousel with page dots.
* Tags: `Heritage Villa`, `0% Booking Fee`, `Verified Host`.
* Title, Location, Guest capacity, and Price per night (`₹2,500/night`).


* **Property Detail Screen:**
* Full photo gallery, host information, house rules, check-in/out timings, and room amenities grid.
* "Complete Your Trip" Cross-Sell Toggle: Add-on scooter rental or luggage drop for bundled discount (`+ ₹300/day`).
* Booking Confirmation: Date range summary, total nights math, guest details, and payment flow.



### 2.5 Tab 5: Unified Activity Hub & Services Hub

* **Unified Activity Hub (`/activity`):**
* Top Category Chips: `[ All ]` `[ Food ]` `[ Rides ]` `[ Stays ]` `[ Rentals ]`.
* Chronological Feed displaying cards for all order types:
* *Food Card:* Restaurant name, item names + counts (never "0 items"), status pill (`Preparing`, `Out for Delivery`, `Delivered`), total amount, and `[ Track Order ]` or `[ Reorder ]` CTA.
* *Ride Card:* Vehicle type, pickup/dropoff addresses, trip status, driver name, fare, and `[ View Receipt ]` CTA.
* *Stay Card:* Villa name, check-in/out dates, guest count, booking reference ID, and `[ View Stay Pass / QR ]` CTA.
* *Rental Card:* Vehicle model, rental duration, return timer, and `[ View Rental QR ]` CTA.




* **Services / Profile Hub:**
* Saved Places (`Home`, `Work`, `Hotel`), Dietary Preferences selector (`No Preference`, `Vegetarian`, `Non-Veg`, `Vegan`), App Theme Toggle (`System`, `Light`, `Dark`), Emergency SOS Configuration, Help & Support Ticket portal, and Sign Out.



---

## 3. Captain (Driver) App Specification

```
┌────────────────────────────────────────────────────────────────────────┐
│                         CAPTAIN APP SHELL                              │
├────────────────────┬────────────────────┬──────────────────────────────┤
│  1. Tasks (Live)   │  2. Active Trip    │  3. Earnings & Profile       │
└────────────────────┴────────────────────┴──────────────────────────────┘

```

### 3.1 Background Location & Online/Offline Dispatch

* **Foreground Location Service:**
* Going **Online** prompts for location permissions (`Always Allow` / `Background`).
* Starts a foreground service with a persistent notification: *"PY Connect Captain: You are online and receiving requests."*
* Pings GPS coordinates to `POST /api/driver/location` every 5 seconds.


* **Offline State Guard:**
* When **Offline**, all dispatch listeners disconnect, task cards are hidden, and incoming requests are blocked.



### 3.2 Incoming Task Dispatch Overlay

* High-priority sound chime + continuous vibration.
* Full-screen modal showing:
* Service Badge: `Food Delivery` (Orange), `Ride Request` (Teal), `Quick Essential` (Blue).
* Pickup & Dropoff addresses with estimated distance.
* Earnings: **`YOU EARN: ₹<Amount> (100% of fare)`**.
* 30-Second Countdown Timer Circle.
* Action Buttons: `[ Reject ]` and `[ Accept Task ]`.



### 3.3 Active Trip State Machines (Zero Placeholders)

#### A. Ride Dispatch Lifecycle:

1. **State 1: `Accepted**` $\rightarrow$ Renders map with route to customer pickup. Displays Rider Name, Contact button, and `[ Arrived at Pickup ]` CTA.
2. **State 2: `ArrivedAtPickup**` $\rightarrow$ Notifies customer. Displays a numeric input pad: *"Enter Customer 4-Digit OTP"*.
3. **State 3: `InProgress**` (OTP Validated) $\rightarrow$ Renders turn-by-turn route to dropoff location. Displays `[ Complete Trip ]` CTA.
4. **State 4: `Completed**` $\rightarrow$ Displays Fare Collection Sheet (*"Collect ₹XX Cash"* or *"Paid Online via UPI"*). Driver confirms payment $\rightarrow$ Returns to Task pool.

#### B. Food / Essentials Delivery Lifecycle:

1. **State 1: `HeadingToStore**` $\rightarrow$ Route navigation to restaurant. Displays Restaurant Name, Address, and `[ Arrived at Restaurant ]` CTA.
2. **State 2: `AtStore**` $\rightarrow$ Displays Order ID and itemized checklist (e.g., `1x Margherita Pizza`, `1x Cold Coffee`). Driver verifies items and taps `[ Confirm Order Picked Up ]`.
3. **State 3: `OutForDelivery**` $\rightarrow$ Route navigation to customer delivery address. Displays Customer Name, Call/Chat buttons, and `[ Arrived at Customer ]` CTA.
4. **State 4: `Delivered**` $\rightarrow$ Driver confirms delivery completion and collects cash (if COD) $\rightarrow$ Payout summary displayed $\rightarrow$ Returns to Task pool.

### 3.4 Captain Onboarding & Safety Compliance

* **Multi-Step Registration:** Vehicle Type (Auto, Bike, Cab) + Plate Number + Driving License Number.
* **KYC Upload:** Camera capture of Driving License, Vehicle RC Book, Commercial Insurance, and Driver Selfie.
* **Mandatory Safety Tutorial:** 5-step swipeable onboarding cards covering traffic rules, zero harassment policy, cancellation guidelines, and earnings breakdown.
* **Digital Terms Signature:** In-app digital signature pad before account status switches to `Pending Verification`.

---

## 4. Partner (Merchant) Command Portal Specification

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PARTNER WEB & APP SHELL                         │
├───────────────┬───────────────┬───────────────┬───────────────┬────────┤
│ 1. Dashboard  │ 2. Operations │ 3. Catalog/   │ 4. QR Scanner │ 5. Hub │
│    & Stats    │    (KDS/Live) │    Fleet      │    (Passes)   │ & Acct │
└───────────────┴───────────────┴───────────────┴───────────────┴────────┘

```

### 4.1 Dynamic Category-Aware Navigation

The Partner portal dynamically adapts its navigation tabs and features based on the vendor's registered business category:

| Vendor Category | Tab 2 (Operations) | Tab 3 (Catalog/Assets) | Core Functional Modules |
| --- | --- | --- | --- |
| **Restaurant / Cafe / Pizzeria** | Kitchen Display (KDS) | Food Menu Manager | KDS Kanban, Menu stock toggles, Prep times |
| **Pub / Restobar / Club** | Table & Crowd Manager | Drinks & VIP Menu | Live Crowd Slider, Cover charge bookings, Guestlist |
| **Scooter / Bike Rental** | Active Rentals Queue | Fleet Management | Vehicle inventory, Hourly rates, Return timer |
| **Taxi / Fleet Operator** | Live Ride Dispatches | Taxi Fleet Grid | Driver duty status, Vehicle assignments |
| **Luggage Cloakroom** | Storage Intake Queue | Capacity Manager | Bag count slider, Visual capacity bar, QR claim check |

### 4.2 Module Specifications

#### A. Kitchen Display System (KDS)

* 3-Column Kanban Board: **Incoming** $\rightarrow$ **Preparing** $\rightarrow$ **Ready / Dispatched**.
* Order Cards: Order ID, Elapsed timer with color-coded urgency (Green $<10\text{ min}$, Amber $10\text{–}20\text{ min}$, Red $>20\text{ min}$), Customer Name, Item pills with quantities, Special cooking instructions.
* Interactions: Single-tap to advance order to next stage. Sound alert plays on new incoming orders. Auto-refreshes every 10 seconds.

#### B. Menu & Drink Catalog Manager

* List view organized by category with item image thumbnails, names, prices, and descriptions.
* **Instant Availability Switch:** Toggle `In Stock` / `Sold Out` instantly syncing to consumer search.
* Item Form: Add/Edit modal with Name, Category, Price, Description, Veg/Non-Veg tag, and Image upload.

#### C. QR Scanner & Pass Validation

* Integrated camera scanner reading Consumer QR passes (Pub Entry, Homestay Check-In, Cloakroom Bag Drop, Scooter Handover).
* **Validation States:**
* *Success (Green Screen):* Audio chime + haptic success. Displays Customer Name, Booking ID, and Validated Service details.
* *Duplicate / Already Used (Red Screen):* Error buzzer. Displays timestamp of when the ticket was previously scanned.
* *Invalid / Network Error (Amber Screen):* Retry prompt.



#### D. Partner Self-Onboarding & Auth Guard

* **Registration Portal (`/register`):** Multi-step form capturing Business Name, Category, Address, FSSAI License Number, GSTIN, PAN, and Bank Account details (Account Number + IFSC) for automated payouts.
* **Status Guard:** Unapproved partners are routed to `/pending-approval` showing a clear status screen with support contact links, preventing redirect loops.

---

## 5. Admin SaaS Command Center ("God Mode" Web)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ADMIN CONTROL CENTER                            │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────┤
│ 1. Analytics │ 2. Merchant  │ 3. Captain   │ 4. Live Ops  │ 5. Finance │
│    & Metrics │    Approvals │    KYC Queue │    & SOS Map │    & Audit │
└──────────────┴──────────────┴──────────────┴──────────────┴────────────┘

```

* **Design Tokens:** Deep Charcoal Slate background (`#0B0F19`), Card surfaces (`#111827`) with `1px` borders (`rgba(255, 255, 255, 0.08)`), High-contrast typography (`#F9FAFB`), Top navbar consistent across all pages.
* **Approval & KYC Queue:**
* Data tables for Pending Drivers and Pending Merchants.
* Side-by-side document preview (License, RC, FSSAI, GSTIN) with 1-click `[ Approve ]` or `[ Reject with Reason ]` actions.


* **Live Operations & SOS Map:**
* Global Map rendering active rides, online drivers, and in-flight food deliveries.
* **Emergency SOS Banner:** If a user or driver triggers an SOS, an urgent flashing red banner displays real-time GPS coordinates, vehicle details, and emergency contact numbers.


* **Financials & Settlements:**
* Platform Gross Merchandise Value (GMV), Commission revenue, Driver payouts due, and Razorpay settlement logs.



---

## 6. End-to-End Flow & Logic Guardrails

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 CORE LOGICAL GUARDRAILS                                         │
├────────────────────────────────┬────────────────────────────────────────────────────────────────┤
│ Issue / Scenario               │ Enforced System Behavior                                       │
├────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ 1. Guest User at Checkout      │ DO NOT redirect to login page. Open slide-up Phone/OTP sheet.  │
│                                │ Auto-resume payment upon verification without cart loss.       │
├────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ 2. Venue Capacity >= 100%      │ Proactively disable "Book" button. Render "Full Capacity"      │
│                                │ banner. Never allow user to reach payment and get 400 error.   │
├────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ 3. Driver Goes Offline         │ Kill background location service. Remove from dispatch pool.   │
│                                │ Hide task cards and disable "Accept" buttons in Driver UI.     │
├────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ 4. Ride Start Verification     │ Driver CANNOT start trip without entering the correct 4-digit   │
│                                │ OTP displayed on the Consumer's active ride screen.            │
├────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ 5. Activity Hub Aggregation    │ GET /api/activity/all must return unified, chronologically     │
│                                │ sorted records for Stays, Food, Rides, and Rentals.            │
├────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ 6. Token Expiry (401 / 403)    │ Silent refresh token exchange via Dio interceptor. Attach      │
│                                │ Bearer token to all endpoints. Graceful re-auth on failure.    │
├────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ 7. Razorpay Initialization     │ Instantiate SDK in initState with public key fallback. Never   │
│                                │ open checkout on an uninitialized instance.                    │
└────────────────────────────────┴────────────────────────────────────────────────────────────────┘

```

---

## 7. Master Production Delivery Checklist

### Phase 1: Foundation, Auth & Theme

* [ ] Set `ThemeMode.light` as the default theme across all three applications.
* [ ] Verify Light Theme uses `#FFFFFF` scaffold, `#111827` text, and `#00D290` accent.
* [ ] Implement guest checkout bottom-sheet login without full-page navigation.
* [ ] Verify JWT token persistence across browser refreshes (Web) and app restarts (Mobile).
* [ ] Fix Partner login redirect loop by implementing the `/pending-approval` route guard.

### Phase 2: Consumer Super-App

* [ ] Clean up Home/Vibe tab: Remove all solid-color blocks and implement image carousels.
* [ ] Wrap all venue cards and stay cards with `AppNetworkImage` and skeleton shimmers.
* [ ] Implement proactive capacity check on Venue details (disable booking if $\ge 100\%$).
* [ ] Implement edge-to-edge spatial map on Ride screen with automatic GPS reverse-geocoding.
* [ ] Connect Unified Activity Hub to backend endpoints (`/api/stays`, `/api/food`, `/api/rides`, `/api/rentals`) with full itemized details.

### Phase 3: Captain (Driver) App

* [ ] Connect Online/Offline toggle to foreground service with persistent notification.
* [ ] Implement 5-second periodic GPS pings to `POST /api/driver/location`.
* [ ] Replace demo snackbars with the real `ActiveTripScreen` state machine.
* [ ] Implement 4-digit OTP validation step before starting rides.
* [ ] Implement complete 4-phase food delivery workflow (*Heading to Store $\rightarrow$ At Store Checklist $\rightarrow$ Out for Delivery $\rightarrow$ Delivered*).

### Phase 4: Partner & Admin SaaS Portals

* [ ] Verify category-aware navigation dynamically adjusts tabs (KDS, Drinks, Fleet, Capacity).
* [ ] Implement real-time audio chimes and Kanban transitions on KDS.
* [ ] Implement instant stock availability switches on Menu items.
* [ ] Connect QR Scanner to `POST /api/vendor/validate-ticket` with success/error audio & haptics.
* [ ] Standardize Admin Web to deep charcoal slate theme (`#0B0F19`) with document approval tables.

### Phase 5: Payments & Security

* [ ] Initialize Razorpay SDK in screen `initState` with null-safe key fallback.
* [ ] Verify backend HMAC SHA256 signature verification endpoint (`POST /api/payments/verify`).
* [ ] Verify end-to-end checkout loop for Food, Cover Charges, Stays, and Rides.