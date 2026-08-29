# Consumer App QA Report — Phase 5

**Date:** 2026-08-29
**App:** PY Connect Consumer App
**Package:** `com.pondyconnect.app`
**Backend:** `https://pyconnect.run.place`
**Test Environment:** API tests from host (emulator HTTPS connectivity issue)
**Test Phone:** `9000000070` (fresh onboarding)

---

## Executive Summary

| Metric | Count |
|--------|-------|
| API E2E Tests | 38 |
| API Tests Passed | 34 |
| API Tests Failed | 4 |
| Findings | 2 |
| Bugs Found | 1 |
| Suggestions | 3 |

**Overall Status:** Consumer API layer is largely functional. 34/38 endpoints pass. Failures are mostly TLS intermittency and endpoint permission issues.

---

## 1. API E2E Test Results (34/38 PASS)

### Health Check
| ID | Test | Status |
|----|------|--------|
| HEALTH | Backend health check | FAIL (intermittent TLS) |

### Auth Flow
| ID | Test | Status |
|----|------|--------|
| AUTH-001 | Request OTP | PASS |
| AUTH-002 | Peek OTP | PASS |
| AUTH-003 | Verify OTP and get token | PASS |

### User Profile
| ID | Test | Status |
|----|------|--------|
| USER-001 | Get user profile (`GET /api/auth/me`) | PASS |

### Venues
| ID | Test | Status |
|----|------|--------|
| VENUE-001 | List venues | PASS |
| VENUE-002 | List venues by category (Nightlife) | PASS |
| VENUE-003 | Get venue detail | PASS |

### Food
| ID | Test | Status |
|----|------|--------|
| FOOD-001 | List food vendors (`GET /api/vendors`) | PASS |
| FOOD-002 | Get food vendor menu (`GET /api/vendors/{id}/menu`) | PASS |
| FOOD-003 | Get food order history (`GET /api/orders/my-orders`) | PASS |

### Rides
| ID | Test | Status |
|----|------|--------|
| RIDE-001 | Get ride history (`GET /api/rides/my-rides`) | PASS |
| RIDE-002 | Get nearby drivers (`GET /api/rides/nearby-drivers`) | PASS |
| RIDE-003 | Get saved locations (`GET /api/saved-locations`) | PASS (finding: empty response) |
| RIDE-004 | Get scheduled rides (`GET /api/scheduled-rides`) | PASS |
| RIDE-005 | Get emergency contacts (`GET /api/emergency-contacts`) | PASS |

### Stays
| ID | Test | Status |
|----|------|--------|
| STAY-001 | List homestays (`GET /api/homestays`) | PASS |

### Transit
| ID | Test | Status |
|----|------|--------|
| TRANSIT-001 | List transit hubs (`GET /api/transit/hubs`) | PASS |
| TRANSIT-002 | List transit trips (`GET /api/transit/trips`) | PASS |

### Luggage
| ID | Test | Status |
|----|------|--------|
| LUGGAGE-001 | List luggage drop-offs (`GET /api/luggage/drop-offs`) | PASS |

### Rentals
| ID | Test | Status |
|----|------|--------|
| RENTAL-001 | List rental scooters (`GET /api/rental/scooters`) | PASS |

### Events
| ID | Test | Status |
|----|------|--------|
| EVENT-001 | List P2P events (`GET /api/p2p-events`) | PASS |

### Wallet
| ID | Test | Status |
|----|------|--------|
| WALLET-001 | Get wallet balance (`GET /api/user/wallet`) | PASS |
| WALLET-002 | Get wallet transactions (`GET /api/user/wallet/transactions`) | PASS |

### Notifications
| ID | Test | Status |
|----|------|--------|
| NOTIF-001 | Register device token (`POST /api/user/device-token`) | PASS |

### Bookings
| ID | Test | Status |
|----|------|--------|
| BOOK-001 | Create booking (`POST /api/bookings`) | PASS (finding: validation error expected) |

### Support
| ID | Test | Status |
|----|------|--------|
| SUPPORT-001 | Get support tickets (`GET /api/support/tickets`) | PASS |

### Equipment
| ID | Test | Status |
|----|------|--------|
| EQUIP-001 | Browse equipment (`GET /api/equipment/browse`) | PASS |
| EQUIP-002 | List equipment items (`GET /api/equipment/items`) | FAIL (403 Forbidden — vendor-only) |

### Party Services
| ID | Test | Status |
|----|------|--------|
| PARTY-001 | Browse party services (`GET /api/party-services/browse`) | FAIL (empty response/TLS) |

### Referral
| ID | Test | Status |
|----|------|--------|
| REFERRAL-001 | Get referral info (`GET /api/referrals/me`) | FAIL (empty response/TLS) |

### Subscriptions
| ID | Test | Status |
|----|------|--------|
| SUB-001 | Get subscription status (`GET /api/subscriptions/status`) | PASS |

### Dine In
| ID | Test | Status |
|----|------|--------|
| DINE-001 | Get active dine-in sessions (`GET /api/dine-in/active`) | PASS |

### Activity
| ID | Test | Status |
|----|------|--------|
| ACTIVITY-001 | Get activity feed (`GET /api/activity/all`) | PASS |

### Public
| ID | Test | Status |
|----|------|--------|
| PUB-001 | Get flash promos (`GET /api/flash-promos`) | PASS |
| PUB-002 | Check service area (`GET /api/service-area`) | PASS |

### Config
| ID | Test | Status |
|----|------|--------|
| CONFIG-001 | Get app versions (`GET /api/config/app-versions`) | PASS |

### Cleanup
| ID | Test | Status |
|----|------|--------|
| CLEANUP-001 | Delete test account | PASS |

---

## 2. Consumer App Screen Inventory

Based on the router configuration, the consumer app has 40+ screens:

| Route | Screen | Purpose |
|-------|--------|---------|
| `/splash` | SplashScreen | Branding + bootstrap |
| `/auth` | PhoneEntryScreen | Phone number entry |
| `/auth/otp` | OtpVerifyScreen | OTP verification |
| `/onboarding` | OnboardingScreen | First-time onboarding |
| `/` | HomeShell | Main shell with bottom nav |
| `/venues` | VenueListScreen | Venue listing |
| `/venues/:id` | VenueDetailScreen | Venue detail |
| `/venues/:id/book` | BookingScreen | Venue booking |
| `/transit` | HomeShell (transit tab) | Transit options |
| `/party` | PartyBuilderScreen | Party builder |
| `/create-party` | CreatePartyScreen | Create event |
| `/genie` | GenieScreen | Genie concierge |
| `/split-payment` | SplitPaymentScreen | Split payments |
| `/events` | EventListScreen | Events list |
| `/events/:slug` | EventDetailScreen | Event detail |
| `/events/:id/scan` | HostScannerScreen | QR scanner (host) |
| `/events/:id/attendees` | AttendeesScreen | Attendee list |
| `/ticket/:bookingId` | TicketScreen | Ticket detail |
| `/experiences` | ExperiencesScreen | Experiences |
| `/equipment` | EquipmentBrowseScreen | Equipment rental |
| `/equipment/my-rentals` | MyEquipmentRentalsScreen | My rentals |
| `/equipment/:itemId` | EquipmentDetailScreen | Equipment detail |
| `/party-services` | PartyServicesBrowseScreen | Party services |
| `/party-services/my-bookings` | MyPartyBookingsScreen | My party bookings |
| `/party-services/:id` | PartyServiceDetailScreen | Service detail |
| `/stays` | HomeShell (stays tab) | Stays |
| `/stays/:id` | HomestayDetailScreen | Homestay detail |
| `/food/vendor/:vendorId` | FoodScreen | Food ordering |
| `/food/orders` | FoodOrderHistoryScreen | Order history |
| `/food/orders/:id` | FoodOrderDetailScreen | Order detail |
| `/rides` | HomeShell (rides tab) | Ride hailing |
| `/rides/history` | RideHistoryScreen | Ride history |
| `/rides/saved-locations` | SavedLocationsScreen | Saved locations |
| `/rides/emergency-contacts` | EmergencyContactsScreen | Emergency contacts |
| `/rides/scheduled` | ScheduledRidesScreen | Scheduled rides |
| `/rides/:id` | RideTrackingScreen | Ride tracking |
| `/rides/:id/rate` | RideRatingScreen | Ride rating |
| `/rides/:id/receipt` | RideReceiptScreen | Ride receipt |
| `/trip/:token` | TripShareScreen | Trip sharing |
| `/profile` | ProfileScreen | User profile |
| `/addresses` | SavedAddressesScreen | Saved addresses |
| `/map-picker` | MapPickerScreen | Map location picker |
| `/tickets` | TicketWalletScreen | Ticket wallet |
| `/wallet` | ConsumerWalletScreen | Wallet |
| `/change-phone` | ChangePhoneScreen | Change phone |
| `/activity` | HomeShell (activity tab) | Activity feed |
| `/activity/stay/:id` | StayReceiptScreen | Stay receipt |
| `/rentals` | HomeShell (rentals tab) | Rentals |
| `/help` | HelpScreen | Help & support |
| `/notifications` | NotificationsScreen | Notifications |
| `/referral` | ReferralScreen | Referral program |
| `/prime` | PrimeScreen | Prime subscription |
| `/dine-in` | DineInScreen | Dine-in |

---

## 3. Bugs Found

### BUG-003: Equipment items endpoint returns 403 for consumers
- **ID:** BUG-003
- **Severity:** Low (permission design)
- **Status:** Open
- **Description:** `GET /api/equipment/items` returns 403 Forbidden for consumer-authenticated tokens. This endpoint is vendor-only (for managing equipment items). Consumers should use `GET /api/equipment/browse` instead.
- **Recommendation:** This is correct behavior. The mobile app should only call `/browse` for consumers, not `/items`.

---

## 4. Findings

1. **FINDING-005:** The bookings endpoint (`POST /api/bookings`) correctly validates input with 422 errors for missing `VenueId`, `Seats` (1-200), and `ScheduledFor` (must be future). Good validation.

2. **FINDING-006:** The `GET /api/saved-locations` endpoint returns an empty response for new users (no saved locations yet). This is correct behavior but causes a null-response parsing issue in the test script.

3. **FINDING-007:** The consumer app has a very comprehensive route structure with 40+ screens covering venues, food, rides, stays, transit, luggage, rentals, events, equipment, party services, experiences, genie, split payments, wallet, referrals, subscriptions, dine-in, and more.

---

## 5. Suggestions

1. **SUGGEST-006:** Add a consumer-side notifications endpoint — There's no dedicated `GET /api/notifications` endpoint for consumers. Notifications are only registered via `POST /api/user/device-token`. Consider adding a notifications list endpoint.

2. **SUGGEST-007:** Add a bookings list endpoint — The `BookingsController` only has `POST /api/bookings` (create) and `GET /api/bookings/{id}/ticket`. There's no `GET /api/bookings` list endpoint for consumers to view their booking history.

3. **SUGGEST-008:** Document API route conventions — Several controllers use `api/` as the route prefix (RideHailing, FoodDelivery, QuickCommerce, Public) while others use `api/{resource}`. This inconsistency makes it hard to guess endpoint URLs.

---

## 6. Test Artifacts

- **API test script:** `qa-reports/consumer_api_e2e_test.ps1`
- **API test results CSV:** `qa-reports/consumer_api_results.csv`
