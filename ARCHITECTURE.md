# PondyConnect — Architecture & Design Document

> **PondyConnect** is a full-stack tourist super-app for Pondicherry, India, built on a .NET 8 clean-architecture backend with a Flutter mobile frontend. It covers nightlife/dining venues, food delivery, quick commerce, ride-hailing, transit, luggage cloak, scooter rentals, boutique stays, experiences, vendor B2B tools, admin dispatch, support, and payments.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Backend Architecture](#2-backend-architecture)
3. [Feature Catalog](#3-feature-catalog)
4. [Frontend Architecture](#4-frontend-architecture)
5. [Data Model](#5-data-model)
6. [API Surface](#6-api-surface)
7. [Infrastructure & Configuration](#7-infrastructure--configuration)
8. [Testing](#8-testing)
9. [Current State Assessment](#9-current-state-assessment)
10. [Work Completed (Sessions 1-5)](#10-work-completed-sessions-1-5)
11. [CI/CD & Deployment](#11-cicd--deployment)

---

## 1. Project Overview

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend API | ASP.NET Core 8, Minimal API + MVC controllers |
| Backend Architecture | Clean Architecture (4 layers) |
| ORM | Entity Framework Core 8 |
| Database | SQLite (dev) / PostgreSQL (prod) |
| Caching | Redis (optional) / In-memory |
| Real-time | SignalR (3 hubs) |
| Mediator | MediatR with CQRS pattern |
| Validation | FluentValidation |
| Payments | Razorpay / Noop dev gateway |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Auth | JWT Bearer tokens |
| SMS/OTP | Console sender (dev) |
| Routing | OSRM (server + client) |
| WhatsApp | Cloud API webhook |
| Frontend | Flutter 3.x (Dart) |
| State Management | Riverpod 2.x |
| Navigation | GoRouter 17.x |
| HTTP Client | Dio 5.x |
| Real-time Client | signalr_netcore |
| Maps | flutter_map 7.x + OSM |
| Secure Storage | flutter_secure_storage |
| Scanner | mobile_scanner 5.x |
| E2E Tests | Playwright |
| CI/CD | GitHub Actions (5 workflows) |
| Container | Docker, Docker Compose |
| Reverse Proxy | Nginx (WebSocket forwarding, TLS, rate limiting) |

### Repository Structure

```
PY_Engine/
├── .github/workflows/    # CI/CD workflows (5 files)
├── backend/
│   ├── src/
│   │   ├── PondyConnect.Domain/
│   │   ├── PondyConnect.Application/
│   │   ├── PondyConnect.Infrastructure/
│   │   └── PondyConnect.Api/
│   └── tests/
│       ├── PondyConnect.Architecture.Tests/  # 288 unit tests
│       └── PondyConnect.Api.Tests/           # Integration tests
├── mobile/
│   ├── lib/
│   │   ├── core/          # Design system, network, providers, theme, storage
│   │   ├── features/      # 18 feature modules
│   │   ├── router/        # GoRouter configuration
│   │   ├── shell/         # HomeShell, PartnerShell, DriverShell
│   │   └── app.dart       # MaterialApp.router root
│   └── pubspec.yaml
├── deploy/                # Nginx config, deployment assets
├── e2e/                   # Playwright E2E tests
└── play-store/            # Play Store listing materials
```

---

## 2. Backend Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────┐
│              PondyConnect.Api                     │
│  Controllers · Hubs · Middleware · Rate Limiting  │
├─────────────────────────────────────────────────┤
│          PondyConnect.Application                  │
│  MediatR CQRS · DTOs · Services · Behaviors        │
├─────────────────────────────────────────────────┤
│         PondyConnect.Infrastructure                │
│  EF Core DbContext · Services · Caching · Locking  │
├─────────────────────────────────────────────────┤
│           PondyConnect.Domain                      │
│  Entities · Enums · Value Objects · Interfaces     │
└─────────────────────────────────────────────────┘
```

**Dependency rule**: Domain has zero dependencies. Application depends on Domain. Infrastructure depends on Application + Domain. API depends on all three.

### Domain Layer (`PondyConnect.Domain`)

| Component | Count | Details |
|-----------|-------|---------|
| Entities | 33 | User, Vendor, Venue, TransitHub, TransitTrip, LuggageDropOff, ScooterRental, Payment, ServiceBooking, BookingItem, VenueAvailability, SubscriptionPlan, UserSubscription, VendorPromotion, BundleBooking, BundleItem, FoodOrder, FoodOrderItem, MenuItem, Product, ProductOrder, ProductOrderItem, Driver, RideRequest, WaitlistEntry, UserWallet, PaymentSettlement, DriverLedgerEntry, DispatchTask, Homestay, RoomAvailability, SupportTicket, TicketMessage, AppEventLog, RideEvent, EmergencyContact, SosAlert, SavedLocation, ScheduledRide |
| Enums | 30 | BookingStatus, CancelReason, CancelledBy, DispatchTaskStatus, DispatchTaskType, FoodOrderStatus, KycVerificationStatus, LedgerTransactionType, LuggageStatus, MessageSenderRole, PaymentMethod, PaymentProvider, PaymentStatus, ProductCategory, ProductOrderStatus, RentalStatus, RideEventType, RideStatus, SaaSTier, ServiceType, SettlementStatus, SosStatus, SubscriptionEnums, SupportTicketStatus, TicketPriority, TransitHubKind, TransitStatus, UserRole, VehicleType, VendorCategory, VenueCategory |
| Value Objects | 1 | GeoLocation (latitude, longitude) |
| Base Entity | 1 | BaseEntity (Id, CreatedAt, UpdatedAt) with MarkUpdated() |
| Interfaces | 1 | IRepository<T> (generic repository contract) |

### Application Layer (`PondyConnect.Application`)

**CQRS Pattern**: Every feature uses MediatR commands and queries. Commands mutate state; queries return DTOs.

**Pipeline Behaviors**:
- `ValidationBehaviour<TRequest, TResponse>` — FluentValidation before handler
- `LoggingBehaviour<TRequest, TResponse>` — Request/response logging

**Feature Folders** (19):

| Folder | Files | Purpose |
|--------|-------|---------|
| Admin | 2 | Admin handlers, driver approval |
| Auth | 6 | OTP request/verify, get-me, Aadhaar verification |
| Bookings | 7 | Create/cancel/complete booking, long weekend pass, booking engine service |
| FoodDelivery | 4 | Create order, menu items, order queries, pricing service |
| GeoFence | 2 | Service area query, validator |
| Homestays | 3 | Book homestay, search, stay bundling service |
| Luggage | 2 | Luggage commands, handlers |
| Notifications | 2 | INotificationService, mock implementation |
| Payments | 2 | Payment commands, handlers |
| QuickCommerce | 2 | Product cart service, handlers |
| Rental | 2 | Rental commands, handlers |
| RideHailing | 11 | Ride handlers, pricing, surge calculator, dispatch, driver wallet, payout, KYC |
| Settlement | 1 | Settlement calculation service |
| Support | 5 | LLM service, message receiver, user context, critical ticket broadcaster |
| Telemetry | 3 | Telemetry service, batch processor |
| Transit | 2 | Transit commands, handlers |
| Vendor | 12 | Vendor auth, handlers, queries, promotions, flash promos, priority ping, ticket validation, venue management |
| Venues | 3 | Venue filter query, get-by-id query, DTOs |
| Wallet | 1 | Promo credit service |

**Common Interfaces** (8):
- `IApplicationDbContext` — Persistence contract (33 DbSets)
- `IAvailabilityCache` — Venue availability cache
- `IDistributedLock` — Distributed locking (Redis/in-memory)
- `IJwtTokenFactory` — JWT token creation
- `IOtpService` — OTP generation/verification
- `IPaymentGateway` — Payment capture/refund
- `IRoutingService` — OSRM routing
- `IUserResolver` — Current user from JWT claims

**Registered Services**:
- `IBookingEngineService` → `BookingEngineService`
- `ISettlementCalculationService` → `SettlementCalculationService`
- `ILlmService` → `MockLlmService`
- `UserContextService`, `MessageReceiverService`
- `ChannelTelemetryService` (singleton)
- `SurgeCalculator`

### Infrastructure Layer (`PondyConnect.Infrastructure`)

**EF Core DbContext** (`ApplicationDbContext`):
- 33 DbSets matching domain entities
- `OnModelCreating` applies all configurations from assembly (22 configuration files)
- `SaveChangesAsync` override auto-updates `UpdatedAt` on modified entities
- `BeginTransactionAsync` — Serializable isolation level (PostgreSQL/SQLite only)
- `IsTransactionSupported` — false for in-memory provider

**Entity Configurations** (22):
AppEventLog, BundleBooking, BundleItem, DispatchTask, DriverLedger, FoodDelivery, Homestay, Mobility (Transit+Luggage+Rental), PaymentSettlement, QuickCommerce, RideHailing, RoomAvailability, ServiceBooking, SubscriptionPlan, SupportTicket, User, UserSubscription, UserWallet, Vendor, VendorPromotion, Venue, WaitlistEntry

**Services** (9):
| Service | Implementation | Purpose |
|---------|---------------|---------|
| `IOtpService` | `OtpService` | OTP generation + verification |
| `ISmsSender` | `ConsoleSmsSender` | SMS delivery (console in dev) |
| `IUserResolver` | `UserResolver` | JWT claim → user ID |
| `IJwtTokenFactory` | `JwtTokenFactory` | JWT token creation |
| `IPaymentGateway` | `RazorpayGateway` / `NoopPaymentGateway` | Payment capture/refund |
| `IRoutingService` | `OsrmRoutingService` | OSRM distance/duration/route |
| `INotificationService` | `FirebaseNotificationService` / `MockNotificationService` | FCM push |
| `RedisCacheService` | — | Redis cache wrapper |
| `WhatsAppHttpClient` | — | WhatsApp Cloud API |

**DataInitializer**: Seeds demo data on startup — users, vendors, venues (with image URLs + ratings), transit hubs, transit trips, menu items, products, homestays, drivers, emergency contacts, subscription plans, promotions.

**Distributed Locking**: `IDistributedLock` → `RedisDistributedLock` (prod) or `InMemoryDistributedLock` (dev). Used for concurrent booking capacity checks.

**Caching**: `IAvailabilityCache` → `AvailabilityCache` (backed by Redis or in-memory). Used for venue availability.

### API Layer (`PondyConnect.Api`)

**Controllers** (22):
AdminController, AuthController, BookingsController, DeviceTokenController, DriverController, FoodDeliveryController, HomestaysController, LuggageController, PaymentsController, PublicController, QuickCommerceController, RentalController, RideHailingController, SupportController, TelemetryController, TransitController, VendorAuthController, VendorController, VendorsController, VenuesController, WaitlistController, WhatsAppWebhookController

**SignalR Hubs** (3):
| Hub | Path | Purpose |
|-----|------|---------|
| `RideHub` | `/hubs/ride` | Rider-facing real-time ride updates |
| `DriverHub` | `/hubs/driver` | Driver-facing ride offers + location updates |
| `AdminHub` | `/hubs/admin` | Admin dispatch monitoring |

**Middleware**: `ExceptionHandlingMiddleware` — global exception handler

**Rate Limiting**:
| Policy | Limit | Window | Target |
|--------|-------|--------|--------|
| `AuthPolicy` | 5 | 60s | Auth/OTP endpoints |
| `OrderPolicy` | 10 | 60s | Order creation endpoints |

**Hosted Services** (3):
- `FlashPromoExpiryWorker` — Background worker that expires flash promotions
- `ScheduledPayoutWorker` — Scheduled driver payout processing
- `TelemetryBatchProcessor` — Batches telemetry events

**API Services** (4):
- `DispatchEngine` — Driver dispatch logic
- `RideDispatchService` — Ride assignment + SignalR notifications
- `DriverLocationStore` — In-memory driver location tracking
- `CriticalTicketBroadcaster` — Support ticket escalation to admin hub

**Security**: JWT Bearer authentication with issuer/audience/signing-key validation, 30s clock skew. Auth guard on booking endpoints.

**Health Checks**: `/health` endpoint checking database + SignalR + Redis (if configured).

**Geo-fence**: `ServiceAreaValidator` — validates coordinates within 3km radius of Pondicherry center (11.9356, 79.8301).

**Swagger**: Enabled in development with JWT Bearer security definition.

---

## 3. Feature Catalog

### 3.1 Authentication

**Backend**:
- **Entities**: `User` (Id, PhoneNumber, Name, AadhaarNumber, AadhaarVerified, Role, CreatedAt)
- **Enums**: `UserRole` (Tourist, Driver, Vendor, Admin)
- **Handlers**: `RequestOtpCommandHandler`, `VerifyOtpCommandHandler`, `GetMeQuery`, `VerifyAadhaarCommand`
- **Controller**: `AuthController` — `POST /api/auth/otp`, `POST /api/auth/otp/verify`, `GET /api/auth/me`, `POST /api/auth/aadhaar`
- **Services**: `OtpService` (6-digit OTP, 5-min expiry), `JwtTokenFactory` (60-min access tokens)
- **Rate limiting**: AuthPolicy (5 req/60s)

**Frontend**:
- **Screens**: `PhoneEntryScreen`, `OtpVerifyScreen`, `ProfileScreen`
- **Data**: `AuthApi` (requestOtp, verifyOtp, getMe, verifyAadhaar)
- **State**: `authControllerProvider` (FutureProvider), `authTokenProvider` (StateProvider)
- **Storage**: `TokenStorage` using flutter_secure_storage
- **Routing**: Auth guard redirects unauthenticated users from `/venues/:id/book`

**Current State**: **Production-ready** — Full OTP flow, JWT, Aadhaar verification, profile screen.

---

### 3.2 Venues (Nightlife & Dining)

**Backend**:
- **Entity**: `Venue` (Name, Category, Address, GeoLocation, IsOpen, Occupancy, Capacity, ImageUrl, Rating, ReviewCount, IsPriorityPingActive, IsActive, OpensAt, ClosesAt)
- **Enums**: `VenueCategory` (Bar=1, Club=2, Pub=3, Restaurant=4, Bakery=5, Cafe=6, Pizzeria=7, Experience=8)
- **DTOs**: `VenueFilterResponse` (Id, Name, Category, Address, IsOpen, Occupancy, Capacity, ImageUrl, Rating, ReviewCount), `VenueDetailResponse` (+ IsPriorityPingActive, OpensAt, ClosesAt, Description)
- **Handlers**: `VenueFilterQueryHandler` (filter by category, pagination), `GetVenueByIdQueryHandler`
- **Controller**: `VenuesController` — `GET /api/venues?category=&page=&pageSize=`, `GET /api/venues/{id}`
- **Seed data**: 8 nightlife/dining venues with Unsplash image URLs and ratings

**Frontend**:
- **Screens**: `VenueListScreen` (filter chips, search, image cards), `VenueDetailScreen` (hero image, rating stars, vibe gauge, priority ping badge), `BookingScreen` (booking form + success state with pass token)
- **Data**: `VenueApi` → `Venue` model (imageUrl, rating, reviewCount, isPriorityPingActive)
- **State**: `venueListProvider` (FutureProvider.family by category), `venueDetailProvider` (FutureProvider.family by id)
- **Design system**: AppCard with image header, StatusBadge (Open/Closed/Priority Ping), RatingStars, Vibe gauge (occupancy-based color), ShimmerList, EmptyState, ErrorState, SectionHeader

**Current State**: **Production-ready** — Full list/detail/booking flow with enriched UI, image cards, ratings, priority ping badges, vibe gauge.

---

### 3.3 Bookings

**Backend**:
- **Entities**: `ServiceBooking` (UserId, VenueId, ServiceType, Status, Seats, ScheduledFor, PassToken, Notes, CancelReason, CancelledBy), `BookingItem`, `VenueAvailability`, `BundleBooking`, `BundleItem`
- **Enums**: `BookingStatus` (Pending, Confirmed, CheckedIn, Completed, Cancelled, Expired), `ServiceType` (Transit, Nightlife, Luggage, Rental, Experience, Homestay), `CancelReason`, `CancelledBy`
- **Handlers**: `CreateBookingCommandHandler`, `CancelBookingCommand`, `CompleteBookingCommand`, `CreateLongWeekendPassCommand`
- **Services**: `BookingEngineService` — capacity check, transaction-safe booking, pass token generation, bundle creation
- **Controller**: `BookingsController` — `POST /api/bookings`, `POST /api/bookings/{id}/cancel`, `POST /api/bookings/{id}/complete`, `POST /api/bookings/long-weekend-pass`
- **Controller**: `WaitlistController` — `POST /api/waitlist/join`, `GET /api/waitlist/{venueId}`

**Frontend**:
- **Screens**: `BookingScreen` (venue booking form with date/guests/notes → success state with pass token card)
- **Data**: `BookingApi` (create, cancel, complete, createLongWeekendPass)
- **Design system**: Success state with gradient pass token card, StatusBadge, AppBottomSheet

**Current State**: **Production-ready** — Full booking lifecycle with capacity checks, pass tokens, cancellation, long weekend passes, waitlist.

---

### 3.4 Transit (Intercity Pickup)

**Backend**:
- **Entities**: `TransitHub` (Name, Kind, City, Latitude, Longitude), `TransitTrip` (UserId, HubId, HubName, ArrivalFrom, ArrivalMode, ArrivalTime, DropoffAddress, Status, Fare, PaymentStatus)
- **Enums**: `TransitHubKind` (Airport, BusStand, RailwayStation), `TransitStatus` (Requested, Assigned, EnRoute, Arrived, Completed, Cancelled)
- **Handlers**: `TransitCommands` (CreateTrip, CancelTrip), `TransitHandlers`
- **Controller**: `TransitController` — `GET /api/transit/hubs`, `POST /api/transit/trips`, `GET /api/transit/trips`, `POST /api/transit/trips/{id}/cancel`

**Frontend**:
- **Screen**: `TransitScreen` with `_TripsPickupTab` — hub selection, trip creation form, existing trips with `_TripCard` (status badges: Pending/Assigned/InProgress/Completed/Cancelled, transport mode icons, fare display)
- **Data**: `TransitApi` → `TransitTrip` model (status, paymentStatus fields)
- **State**: `transitHubsProvider`, `userTripsProvider` (FutureProvider)

**Current State**: **Production-ready** — Full trip lifecycle with status badges, hub selection, fare display.

---

### 3.5 Luggage Cloak

**Backend**:
- **Entity**: `LuggageDropOff` (UserId, VendorId, VendorName, BagCount, HourlyRatePerBag, Status, DropOffTime, PickupDeadline, TotalAmount, PaymentStatus, CancelledAt)
- **Enums**: `LuggageStatus` (Reserved, Dropped, Collected, Cancelled)
- **Handlers**: `LuggageCommands` (CreateDropOff, CancelDropOff, GetDropOffById), `LuggageHandlers`
- **Controller**: `LuggageController` — `GET /api/luggage/vendors`, `POST /api/luggage/drop-offs`, `GET /api/luggage/drop-offs/{id}`, `POST /api/luggage/drop-offs/{id}/cancel`
- **Pricing**: ₹60 per bag per hour

**Frontend**:
- **Screen**: `_LuggageCloakTab` in `TransitScreen` — vendor list (AppCard with phone, rate badge), booking sheet (bag count, duration, total), existing bookings with lifecycle cards (StatusBadge: Reserved/Dropped/Collected/Cancelled), cancel button for Reserved bookings
- **Data**: `LuggageApi` (listVendors, createDropOff, getDropOff, cancelDropOff)
- **State**: `luggageCloakVendorsProvider`, `userLuggageDropOffsProvider`

**Current State**: **Production-ready** — Full lifecycle: vendor list → booking → drop-off → collection/cancellation with status badges.

---

### 3.6 Mobility / Scooter Rental

**Backend**:
- **Entity**: `ScooterRental` (UserId, VendorId, VendorName, VehicleName, RentalStart, RentalEnd, RatePerHour, Status, TotalAmount, PaymentStatus, CancelledAt)
- **Enums**: `RentalStatus` (Reserved, Active, Returned, Cancelled)
- **Handlers**: `RentalCommands` (CreateRental, CancelRental), `RentalHandlers`
- **Controller**: `RentalController` — `GET /api/rentals`, `POST /api/rentals`, `POST /api/rentals/{id}/cancel`
- **Pricing**: ₹140 per hour

**Frontend**:
- **Screen**: `_MobilityTab` in `TransitScreen` — dynamic vendor list from `scooterRentalVendorsProvider` (vendor cards with ₹140/hr badge), booking sheet (start time, duration, total), existing rentals with `_RentalCard` (status badges: Reserved/Active/Completed/Cancelled)
- **Data**: `RentalApi` (listVendors, createRental, listUserRentals, cancelRental)
- **State**: `scooterRentalVendorsProvider`, `userRentalsProvider`

**Current State**: **Production-ready** — Full rental lifecycle with dynamic vendor list, status badges, booking sheet.

---

### 3.7 Food Delivery

**Backend**:
- **Entities**: `FoodOrder` (VendorId, UserId, Status, Items, DeliveryAddress, DeliveryLatitude, DeliveryLongitude, SubTotal, DeliveryFee, PlatformFee, TotalAmount, PlacedAt), `FoodOrderItem`, `MenuItem` (VendorId, Name, Description, Price, Category, IsAvailable, IsVeg)
- **Enums**: `FoodOrderStatus` (Placed, Accepted, Preparing, OutForDelivery, Delivered, Cancelled)
- **Handlers**: `CreateFoodOrderHandler`, `MenuItemHandlers` (create/update/toggle), `FoodOrderQueries` (list by user, get by id)
- **Services**: `OrderPricingService` — subtotal, delivery fee, platform fee calculation
- **Controller**: `FoodDeliveryController` — `GET /api/food/vendors`, `GET /api/food/vendors/{id}/menu`, `POST /api/food/orders`, `GET /api/food/orders`, `GET /api/food/orders/{id}`, `POST /api/food/menu-items` (vendor), `PUT /api/food/menu-items/{id}` (vendor), `POST /api/food/menu-items/{id}/toggle` (vendor)

**Frontend**:
- **Screens**: `RestaurantListScreen` (vendor cards), `FoodScreen` (menu, cart, checkout), `FoodOrderHistoryScreen`, `FoodOrderDetailScreen`
- **Data**: `FoodDeliveryApi` (listVendors, getMenu, createOrder, listOrders, getOrder)
- **State**: Provider-based

**Current State**: **Production-ready** — Full order flow with pricing, menu management for vendors, order history. UI migrated to theme-aware colors.

---

### 3.8 Quick Commerce (Essentials)

**Backend**:
- **Entities**: `Product` (Name, Description, Category, Price, IsLateNightEssential, IsActive, ImageUrl), `ProductOrder` (UserId, Items, DeliveryAddress, SubTotal, DeliveryFee, PlatformFee, TotalAmount, Status), `ProductOrderItem`
- **Enums**: `ProductCategory` (HydrationRecovery, SmokingAccessories, BeachEssentials, Snacks, Misc), `ProductOrderStatus` (Placed, Dispatched, Delivered, Cancelled)
- **Handlers**: `QuickCommerceHandlers` (list products, create order, get suggestions), `ProductCartService`
- **Services**: `FlashPromoExpiryWorker` (background promo expiry)
- **Controller**: `QuickCommerceController` — `GET /api/products`, `GET /api/products/suggestions`, `POST /api/products/orders`, `GET /api/products/orders`, `GET /api/products/orders/{id}`
- **Controller**: `PublicController` — `GET /api/public/flash-promos`

**Frontend**:
- **Screens**: `EssentialsScreen` (product grid with search, category filter chips, late-night filter, flash promo banner with countdown, cart bar, checkout, bundle suggestions, order result sheet), `EssentialsStoreView` (store browsing), `EssentialsOrderHistoryScreen`
- **Data**: `QuickCommerceApi` (listProducts, createOrder, getSuggestions, listOrders), `PublicApi` (listFlashPromos)
- **State**: `essentialsListProvider`, `flashPromosProvider`, `bundleSuggestionsProvider` (FutureProvider.family)
- **Design system**: ShimmerList, EmptyState, ErrorState (migrated from custom widgets). Enriched `_OrderResultSheet` with success icon. Product cards, flash promo banner, cart bar still use custom widgets.

**Current State**: **Production-ready** — Full product browsing, cart, checkout, flash promos, bundle suggestions, order history. Design system fully adopted with theme-aware colors.

---

### 3.9 Ride Hailing

**Backend**:
- **Entities**: `RideRequest` (UserId, DriverId, PickupAddress, DropAddress, PickupGeo, DropGeo, Status, VehicleType, Fare, DistanceKm, DurationMin, SurgeMultiplier, PaymentMethod, PaymentStatus, RideEvents, Rating), `Driver` (UserId, VehicleType, LicensePlate, IsOnline, IsApproved, KycStatus, CurrentLocation), `RideEvent` (RideId, EventType, Timestamp), `SavedLocation` (UserId, Label, Address, Latitude, Longitude), `ScheduledRide` (UserId, Pickup, Drop, ScheduledFor, Status), `EmergencyContact` (UserId, Name, PhoneNumber), `SosAlert` (UserId, RideId, Status, Lat, Lng)
- **Enums**: `RideStatus` (Requested, Accepted, EnRoute, Completed, Cancelled, Searching, DriverAssigned, ArrivedAtPickup, DriverCancelled, NoDriversAvailable), `RideEventType` (Requested, Accepted, Arrived, Started, Completed, Cancelled, LocationUpdate), `VehicleType` (Bike, Auto, Car), `KycVerificationStatus` (Pending, Approved, Rejected)
- **Handlers**: `RideHailingHandlers` (request ride, cancel, get active, history, rate, receipt, save location, scheduled rides, emergency contacts, SOS), `RideHailingExtendedHandlers`, `GetDriverByUserIdQuery`, `DriverWalletQuery`, `DispatchTaskQuery`, `UploadKycCommand`
- **Services**: `RidePricingService` (base fare + distance + surge), `SurgeCalculator` (time/demand-based), `DispatchEngine` (nearest driver selection), `RideDispatchService` (assignment + SignalR notification), `DriverPayoutService`, `ScheduledPayoutWorker`
- **Controller**: `RideHailingController` — `POST /api/rides`, `POST /api/rides/{id}/cancel`, `GET /api/rides/active`, `GET /api/rides/history`, `GET /api/rides/{id}`, `POST /api/rides/{id}/rate`, `GET /api/rides/{id}/receipt`, `POST /api/rides/saved-locations`, `GET /api/rides/saved-locations`, `DELETE /api/rides/saved-locations/{id}`, `POST /api/rides/scheduled`, `GET /api/rides/scheduled`, `POST /api/rides/sos`, `GET /api/rides/emergency-contacts`, `POST /api/rides/emergency-contacts`, `GET /api/rides/{id}/share/{token}` (trip share)
- **Controller**: `DriverController` — `POST /api/driver/register`, `POST /api/driver/kyc`, `GET /api/driver/profile`, `POST /api/driver/go-online`, `POST /api/driver/location`, `GET /api/driver/rides/active`, `POST /api/driver/rides/{id}/accept`, `POST /api/driver/rides/{id}/arrive`, `POST /api/driver/rides/{id}/start`, `POST /api/driver/rides/{id}/complete`, `GET /api/driver/earnings`, `GET /api/driver/wallet`, `GET /api/driver/dispatch/tasks`
- **SignalR**: `RideHub` (rider updates), `DriverHub` (driver offers + location), `DriverLocationStore` (in-memory location tracking)

**Frontend**:
- **Screens**: `RideHailingScreen` (map, pickup/drop, vehicle selection, fare estimate, request ride), `RideTrackingScreen` (real-time tracking, driver info, status updates), `RideHistoryScreen`, `RideRatingScreen`, `RideReceiptScreen`, `SavedLocationsScreen`, `ScheduledRidesScreen`, `EmergencyContactsScreen`, `TripShareScreen`
- **Data**: `RideHailingApi` (requestRide, cancelRide, getActiveRide, getHistory, rateRide, getReceipt, saveLocation, listSavedLocations, deleteSavedLocation, scheduleRide, listScheduledRides, createSos, listEmergencyContacts, addEmergencyContact, getTripShare)
- **State**: `rideHubProvider` (SignalR client), `ridesApiProvider`
- **Widgets**: `rides_screen.dart` (22KB), `ride_tracking_screen.dart` (28KB) — largest screens in the app

**Current State**: **Production-ready** — Full ride lifecycle with real-time tracking, surge pricing, driver dispatch, KYC, wallet, earnings, scheduled rides, SOS, trip share, ratings, receipts. UI migrated to theme-aware semantic colors (AppTheme.success/danger/warning/info).

---

### 3.10 Driver App

**Backend**:
- **Entities**: `Driver`, `RideRequest`, `DispatchTask` (DriverId, Type, Status, Payload), `DriverLedgerEntry` (DriverId, Type, Amount, Description), `PaymentSettlement` (DriverId, RideId, Amount, Status)
- **Enums**: `DispatchTaskStatus` (Pending, Accepted, Completed, Cancelled), `DispatchTaskType` (Ride, FoodDelivery, EssentialsDrop), `LedgerTransactionType` (Credit, Debit), `SettlementStatus` (Pending, Processed, Failed)
- **Handlers**: `DispatchTaskService`, `DriverPayoutService`, `DriverWalletQuery`, `ScheduledPayoutWorker`
- **Controller**: `DriverController` (see Ride Hailing section)
- **SignalR**: `DriverHub` — ride offers, location updates

**Frontend**:
- **Screens**: `DriverHomeScreen` (online toggle, ride queue), `DriverRideScreen` (active ride management), `RideOfferSheet` (incoming ride offer), `DriverEarningsScreen` (earnings summary, ledger entries, wallet)
- **Data**: `DriverApi` (register, goOnline, updateLocation, acceptRide, arriveAtPickup, startRide, completeRide, getEarnings, getWallet)
- **State**: `driverHubProvider` (SignalR client)

**Current State**: **Production-ready** — Full driver flow: registration, KYC, online/offline toggle, ride offers via SignalR, active ride management, earnings, wallet, ledger. UI migrated to theme-aware colors.

---

### 3.11 Stays (Boutique Homestays)

**Backend**:
- **Entities**: `Homestay` (Name, Description, LocationArea, Latitude, Longitude, NightlyRate, MaxGuests, HasWifi, IsVerified, IsActive), `RoomAvailability` (HomestayId, Date, AvailableRooms)
- **Handlers**: `SearchHomestaysQuery` (date + guest search), `BookHomestayCommand` (with add-ons: scooter pickup, luggage cloak)
- **Services**: `StayBundlingService` — suggests add-ons (scooter, luggage) with discounts
- **Controller**: `HomestaysController` — `GET /api/homestays`, `GET /api/homestays/search`, `GET /api/homestays/{id}`, `POST /api/homestays/book`

**Frontend**:
- **Screens**: `StaysScreen` (search bar with check-in/check-out/guests, homestay list), `HomestayDetailScreen` (hero image, amenities, complete-trip add-on card, price breakdown, booking confirmation with pass token)
- **Data**: `StaysApi` → `Homestay` model, `BookHomestayRequest`, `BookHomestayResponse` (bookingId, totalAmount, passToken, status, suggestedAddOns)
- **State**: `homestayListProvider`, `homestaySearchProvider` (FutureProvider.family), `homestayDetailProvider`, `selectedGuestsProvider`, `addOnToggleProvider`
- **Widgets**: `HomestayCard` (hero image, verified badge, 0% booking fee badge, wifi icon, nightly rate, location, max guests)
- **Design system**: ShimmerList, EmptyState, ErrorState migrated. Modern booking confirmation bottom sheet with pass token card.

**Current State**: **Production-ready** — Full search → detail → booking flow with add-on bundles, pass token, room availability, verified badges.

---

### 3.12 Experiences

**Backend**:
- Uses `Venue` entity with `VenueCategory.Experience` (category=8)
- **Handlers**: `VenueFilterQueryHandler` (filter by category=8)
- **Controller**: `VenuesController` — `GET /api/venues?category=8`
- **Booking**: Uses `BookingEngineService` via `BookingsController`

**Frontend**:
- **Screen**: `ExperiencesScreen` — bookable experiences list (AppCard with image, RatingStars, StatusBadge Open/Closed), booking sheet (date picker, guests, per-person pricing), safety guidance section with colored `_SafetyCard` widgets (Beach Safety, Scooter Parking, Emergency Contacts)
- **Data**: Uses `Venue` model + `BookingApi`
- **State**: `experiencesProvider` (FutureProvider filtering venues by Experience category)
- **Design system**: SectionHeader, ShimmerList, EmptyState, ErrorState, AppCard, RatingStars, StatusBadge — fully migrated.

**Current State**: **Production-ready** — Experience booking with enriched UI, safety guidance cards, design system fully adopted.

---

### 3.13 Vendor B2B

**Backend**:
- **Entities**: `Vendor` (BusinessName, Category, PhoneNumber, IsApproved, PriorityPingActive, PriorityPingExpiresAt, UserId), `VendorPromotion` (VendorId, Title, Description, DiscountPercentage, ExpiryTime, IsActive)
- **Enums**: `VendorCategory` (LuggageCloak, ScooterRental, TaxiOperator, PubClub, Restaurant, Cafe, Pizzeria)
- **Handlers**: `VendorAuthHandlers` (register, login), `VendorHandlers` (profile, menu items, orders), `VendorVenueHandlers` (venue management), `FlashPromoHandlers` (create/list promos), `ActivatePriorityPingCommand`, `ValidateTicketCommand` (QR pass validation)
- **Services**: `FlashPromoExpiryWorker` (background promo expiry)
- **Controllers**: `VendorAuthController` — `POST /api/vendor/auth/register`, `POST /api/vendor/auth/login`; `VendorController` — `GET /api/vendor/profile`, `POST /api/vendor/priority-ping/activate`, `POST /api/vendor/tickets/validate`, `POST /api/vendor/promotions`, `GET /api/vendor/promotions`; `VendorsController` — `GET /api/vendors` (public list by category)

**Frontend**:
- **Screens**: `VendorDashboardScreen` (dashboard with stats, priority ping toggle, ticket validation, promotions), vendor widgets
- **Data**: `VendorApi` (register, login, getProfile, listByCategory, activatePriorityPing, validateTicket, createPromo, listPromos)
- **Scanner**: `ScannerScreen` with `mobile_scanner` for QR pass validation

**Current State**: **Production-ready** — Vendor auth, dashboard, priority ping activation, flash promos, ticket validation. Scanner integration. Category-specific screens for all 7 vendor types (drinks menu, fleet management, active rentals, taxi fleet, taxi rides, cloak capacity). Dark theme with AppTheme semantic colors.

---

### 3.14 Admin

**Backend**:
- **Handlers**: `AdminHandlers` (dashboard stats, driver approval), `ApproveDriverCommand`
- **Controller**: `AdminController` — `GET /api/admin/dashboard`, `POST /api/admin/drivers/{id}/approve`
- **SignalR**: `AdminHub` — dispatch monitoring, critical ticket alerts

**Frontend**:
- **Screen**: `AdminDispatchScreen` (dispatch overview, driver approval, active rides), admin widgets (5 widget files)
- **Data**: `AdminApi` (getDashboard, approveDriver, getDispatchTasks)
- **State**: Provider-based

**Current State**: **Production-ready** — Admin dashboard with driver approval, dispatch monitoring, live rides, SOS alerts, support tickets, logs, user management. Dark SaaS theme with AdminColors palette. Functional SOS phone button.

---

### 3.15 Support

**Backend**:
- **Entities**: `SupportTicket` (UserId, Subject, Status, Priority, Messages), `TicketMessage` (TicketId, SenderRole, Content, SentAt)
- **Enums**: `SupportTicketStatus` (Open, InProgress, Resolved, Escalated), `TicketPriority` (Low, Medium, High, Critical), `MessageSenderRole` (User, Agent, Llm)
- **Handlers**: `MessageReceiverService` (processes incoming messages), `UserContextService` (user context for LLM)
- **Services**: `ILlmService` → `MockLlmService` (mock AI triage), `ICriticalTicketBroadcaster` → `CriticalTicketBroadcaster` (escalates to AdminHub)
- **Controller**: `SupportController` — `POST /api/support/tickets`, `GET /api/support/tickets`, `GET /api/support/tickets/{id}`, `POST /api/support/tickets/{id}/messages`, `POST /api/support/sos`

**Frontend**:
- **Screen**: `SosBottomSheet` (SOS trigger from FAB)
- **Data**: `SupportApi` (createTicket, listTickets, getTicket, sendMessage, createSos)

**Current State**: **Functional** — Support ticket system with LLM triage (mock), critical ticket escalation, SOS. SOS bottom sheet with theme-aware colors and category selection.

---

### 3.16 Payments

**Backend**:
- **Entities**: `Payment` (UserId, Amount, Provider, Status, OrderId, RazorpayOrderId, RazorpayPaymentId), `PaymentSettlement` (DriverId, RideId, Amount, Status), `UserWallet` (UserId, Balance, Currency), `DriverLedgerEntry` (DriverId, Type, Amount, Description)
- **Enums**: `PaymentProvider` (None, Razorpay, Stripe, UpiIntent), `PaymentMethod` (Unknown, Cash, Upi, Card, NetBanking, Wallet), `PaymentStatus` (Unpaid, Captured, Refunded, Failed), `SettlementStatus` (Pending, Processed, Failed), `LedgerTransactionType` (Credit, Debit)
- **Handlers**: `PaymentHandlers` (create payment, capture, refund, settlement), `SettlementCalculationService`, `DriverPayoutService`, `PromoCreditService`
- **Services**: `IPaymentGateway` → `RazorpayGateway` (if keys present) or `NoopPaymentGateway` (dev), `ScheduledPayoutWorker` (background payout processing)
- **Controller**: `PaymentsController` — `POST /api/payments`, `POST /api/payments/{id}/capture`, `POST /api/payments/{id}/refund`, `GET /api/payments/{id}`

**Frontend**:
- No dedicated payment screen — payments are embedded in booking/order flows
- Payment status tracked in all order models (TransitTrip, LuggageDropOff, ScooterRental, FoodOrder, ProductOrder, ServiceBooking)

**Current State**: **Functional** — Payment gateway abstraction with Razorpay/Noop, settlement calculation, driver payouts, wallet, promo credits. No standalone payment UI.

---

### 3.17 Notifications

**Backend**:
- **Interfaces**: `INotificationService` (SendAsync)
- **Services**: `FirebaseNotificationService` (FCM, if configured), `MockNotificationService` (dev fallback)
- **Controller**: `DeviceTokenController` — `POST /api/device-token` (register FCM token)
- **WhatsApp**: `WhatsAppWebhookController` — `GET /api/whatsapp/webhook` (verification), `POST /api/whatsapp/webhook` (message webhook), `WhatsAppHttpClient`

**Frontend**:
- **Providers**: `fcmInitializationProvider` — initializes Firebase Messaging, handles foreground messages (shows SnackBar), deep linking
- **Data**: `NotificationApi` (registerDeviceToken)
- **App.dart**: Listens to `fcmInitializationProvider`, shows SnackBar for foreground notifications

**Current State**: **Functional** — FCM push notifications with device token registration, foreground message handling, deep linking. WhatsApp webhook integration present.

---

### 3.18 Telemetry

**Backend**:
- **Entities**: `AppEventLog` (EventType, UserId, Payload, Timestamp)
- **Interfaces**: `ITelemetryService`
- **Services**: `ChannelTelemetryService` (singleton, in-memory channel), `TelemetryBatchProcessor` (background batch flush to DB)
- **Controller**: `TelemetryController` — `POST /api/telemetry/events`

**Frontend**:
- **Data**: `TelemetryApi` (logEvent)
- **State**: Provider-based

**Current State**: **Functional** — Event logging with batch processing. Minimal UI footprint (background only).

---

## 4. Frontend Architecture

### App Shell

`HomeShell` — Root scaffold with:
- **8-tab bottom navigation**: Vibe (Venues), Food, Shop (Essentials), Ride, Transit, Explore (Experiences), Stays, Profile
- **SOS FAB** — Floating action button (centerDocked) triggering `SosBottomSheet`
- **IndexedStack** — Keeps all 8 screens alive for instant tab switching
- **ContextualHome** — Feature cards on Vibe tab (Pub Entry, Live Crowd, AC Cafes, etc.)

### Three Apps

The mobile project produces exactly 3 Android apps (no redundant `vendor` flavor):

| App | Entry Point | Application ID | Flavor | Purpose |
|-----|------------|----------------|--------|---------|
| Consumer | `lib/main.dart` | `com.pondyconnect.app` | `consumer` | Ride-hailing, food, venues, transit, stays, experiences |
| Driver/Captain | `lib/main_driver.dart` | `com.pondyconnect.driver` | `driver` | Ride acceptance, navigation, earnings, wallet, KYC |
| Partner | `lib/main_partner.dart` | `com.pondyconnect.partner` | `partner` | Category-aware vendor management |

A 4th web-only entry point `lib/main_admin.dart` builds the Admin web app (not an Android app).

### Partner App Category Adaptation

The Partner app adapts its navigation tabs based on the vendor's `VendorCategory`:

| Category | Tab 1 | Tab 2 | Tab 3 | Tab 4 | Tab 5 |
|----------|-------|-------|-------|-------|-------|
| Restaurant/Cafe/Pizzeria | Dashboard | KDS | Menu | Scanner | Manage |
| PubClub | Dashboard | KDS | Drinks Menu | Scanner | Manage |
| ScooterRental | Dashboard | Fleet | Rentals | Scanner | Manage |
| TaxiOperator | Dashboard | Fleet | Rides | Scanner | Manage |
| LuggageCloak | Dashboard | Capacity | Bookings | Scanner | Manage |

Category-specific screens: `drinks_menu_screen.dart`, `fleet_management_screen.dart`, `active_rentals_screen.dart`, `taxi_fleet_screen.dart`, `taxi_rides_screen.dart`, `cloak_capacity_screen.dart`.

### Routing (GoRouter)

```
/auth                 → PhoneEntryScreen
/auth/otp             → OtpVerifyScreen
/                     → HomeShell (with nested routes)
  /venues             → VenueListScreen (category, filter query params)
  /venues/:id         → VenueDetailScreen
  /venues/:id/book    → BookingScreen (auth required)
  /transit            → TransitScreen
  /experiences        → ExperiencesScreen
  /stays              → StaysScreen
  /stays/:id          → HomestayDetailScreen
  /food               → RestaurantListScreen
  /food/vendor/:id    → FoodScreen
  /food/orders        → FoodOrderHistoryScreen
  /food/orders/:id    → FoodOrderDetailScreen
  /essentials         → EssentialsScreen
  /essentials/store   → EssentialsStoreView
  /essentials/orders  → EssentialsOrderHistoryScreen
  /rides              → RideHailingScreen
  /rides/history      → RideHistoryScreen
  /rides/saved-locations → SavedLocationsScreen
  /rides/emergency-contacts → EmergencyContactsScreen
  /rides/scheduled    → ScheduledRidesScreen
  /rides/driver/earnings → DriverEarningsScreen
  /rides/:id          → RideTrackingScreen
  /rides/:id/rate     → RideRatingScreen
  /rides/:id/receipt  → RideReceiptScreen
  /trip/:token        → TripShareScreen
  /profile            → ProfileScreen
  /admin              → AdminDispatchScreen
```

**Auth Guard**: Redirects to `/auth` if unauthenticated user tries to book. Stores pending redirect for post-login return.

**Deep Linking**: FCM deep links consumed on app launch — if pending deep link exists and user is authenticated, navigates to deep link route.

### State Management (Riverpod)

| Provider Type | Usage |
|--------------|-------|
| `Provider` | API clients, services (ApiClient, VenueApi, etc.) |
| `StateProvider` | Auth token, selected guests, add-on toggle, pending redirects |
| `FutureProvider` | Async data loading (venue list, trip list, etc.) |
| `FutureProvider.family` | Parameterized async (venue detail by ID, homestay search by params) |
| `StreamProvider` | Real-time data (SignalR streams) |
| `ChangeNotifierProvider` | Auth refresh listenable for GoRouter |

**Core Providers** (`providers.dart`):
- `apiClientProvider` — Dio-based ApiClient with auth interceptor + onUnauthorized callback
- `authTokenProvider` — StateProvider<String?> for JWT
- 13 API providers (auth, venue, transit, luggage, rental, vendor, booking, food, essentials, rides, stays, support, public)
- `rideHubProvider`, `driverHubProvider` — SignalR clients
- `geocodingProvider`, `routingProvider` — OSM/OSRM services

### Design System

10 reusable widgets in `lib/core/design/`:

| Widget | File | Purpose |
|--------|------|---------|
| `AppCard` | `app_card.dart` | Card with optional image header, gradient overlay, badge, onTap |
| `StatusBadge` | `status_badge.dart` | Colored pill badge (success/warning/danger/info variants) |
| `RatingStars` | `rating_stars.dart` | Star rating display with review count |
| `ShimmerList` | `shimmer_list.dart` | Loading placeholder list (configurable count, with/without image) |
| `EmptyState` | `empty_state.dart` | Icon + title + subtitle centered empty state |
| `ErrorState` | `error_state.dart` | Icon + message + retry button error state |
| `AppBottomSheet` | `app_bottom_sheet.dart` | Styled bottom sheet wrapper |
| `SectionHeader` | `section_header.dart` | Icon + title section divider |
| `PriceTag` | `price_tag.dart` | Price display with currency symbol |
| `design.dart` | `design.dart` | Barrel export for all design widgets |

### Theme

`AppTheme.light` — Custom light theme with:
- **Primary colors**: Lagoon (teal), Night (dark blue), Sand (warm beige)
- **Accent colors**: Success green, warning amber, danger red
- **Typography**: Material 3 text themes with custom weights
- **Card shapes**: Rounded corners (16px radius)
- **Bottom nav**: NavigationBar with 8 destinations

### Theme System

**AppTheme** — Custom light/dark theme with semantic colors:

| Color | Hex | Usage |
|-------|-----|-------|
| Lagoon (primary) | `0xFF0D9488` | Teal primary, buttons, accents |
| Lagoon Light | `0xFF14B8A6` | Hover/active states |
| Lagoon Dark | `0xFF0F766E` | Pressed states |
| Coral | `0xFFF97316` | Orange accent, highlights |
| Night | `0xFF1E293B` | Dark slate text |
| Sand | `0xFFF8FAFC` | Warm beige background |
| Gold | `0xFFE9C46A` | Star ratings, premium badges |
| Sky | `0xFF4895EF` | Info indicators |
| Success | `0xFF22C55E` | Success states, online indicators |
| Danger | `0xFFEF4444` | Error states, SOS, delete actions |
| Warning | `0xFFF59E0B` | Warning states, amber badges |
| Info | `0xFF3B82F6` | Info states, blue indicators |
| Dark Background | `0xFF0F172A` | Partner app scaffold |
| Dark Surface | `0xFF1E293B` | Partner app cards/surfaces |

**AdminColors** — Dark SaaS palette for the Admin web app:

| Color | Hex | Usage |
|-------|-----|-------|
| Background | `0xFF0B0F19` | Admin scaffold |
| Surface | `0xFF111827` | Cards, panels |
| Surface Hover | `0xFF1F2937` | Hover states |
| Text Primary | `0xFFF9FAFB` | Primary text |
| Text Muted | `0xFF9CA3AF` | Secondary text |
| Accent | `0xFF0D9488` | Primary actions |
| Accent Light | `0xFF14B8A6` | Active states |
| Danger | `0xFFEF4444` | Error/destructive |
| Success | `0xFF22C55E` | Success |
| Warning | `0xFFF59E0B` | Warning |
| Info | `0xFF3B82F6` | Info |

All 330+ hardcoded `Colors.grey`, `Colors.red`, `Colors.green`, `Colors.amber`, `Colors.blue` usages have been replaced with theme-aware semantic colors (`AppTheme.*`, `AdminColors.*`, or `Theme.of(context).colorScheme.*`).

### Network Layer

| Component | Purpose |
|-----------|---------|
| `ApiClient` | Dio wrapper with JWT auth interceptor, auto-refresh, onUnauthorized |
| `OsmGeocodingService` | Nominatim address search + reverse geocoding |
| `OsrmRoutingService` | OSRM route, distance, duration |
| `SignalRClient` | SignalR connection wrapper (ride/driver hubs) |
| `TokenStorage` | flutter_secure_storage for JWT |

### Dependencies (pubspec.yaml)

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_riverpod | ^2.6.1 | State management |
| go_router | ^17.4.0 | Navigation |
| dio | ^5.11.0 | HTTP client |
| flutter_secure_storage | ^11.0.0 | JWT storage |
| mobile_scanner | ^5.0.0 | QR scanner |
| audioplayers | ^6.0.0 | Sound playback |
| signalr_netcore | ^1.4.4 | SignalR client |
| firebase_core | ^3.6.0 | Firebase init |
| firebase_messaging | ^15.1.0 | FCM push notifications |
| flutter_map | ^7.0.2 | OSM map |
| latlong2 | ^0.9.1 | Geo coordinates |
| url_launcher | ^6.3.1 | External links |
| cached_network_image | ^3.4.1 | Image caching |

---

## 5. Data Model

### Entity Summary (33 entities)

| Entity | Key Fields | Relationships |
|--------|-----------|---------------|
| User | PhoneNumber, Name, AadhaarNumber, Role | Has many: Bookings, Rides, Orders, Wallet, Tickets |
| Vendor | BusinessName, Category, PhoneNumber, IsApproved, PriorityPingActive | Has many: MenuItems, Products, Promotions, Venues |
| Venue | Name, Category, Address, GeoLocation, ImageUrl, Rating, IsPriorityPingActive | Belongs to: Vendor (optional). Has many: ServiceBookings, WaitlistEntries, VenueAvailability |
| TransitHub | Name, Kind, City, GeoLocation | Has many: TransitTrips |
| TransitTrip | UserId, HubId, ArrivalFrom, ArrivalMode, ArrivalTime, Status, Fare | Belongs to: User, TransitHub |
| LuggageDropOff | UserId, VendorId, BagCount, HourlyRatePerBag, Status | Belongs to: User, Vendor |
| ScooterRental | UserId, VendorId, VehicleName, RatePerHour, Status | Belongs to: User, Vendor |
| ServiceBooking | UserId, VenueId, ServiceType, Status, Seats, PassToken | Belongs to: User, Venue. Has many: BookingItems |
| BookingItem | BookingId, Name, Price | Belongs to: ServiceBooking |
| VenueAvailability | VenueId, Date, AvailableSlots | Belongs to: Venue |
| Payment | UserId, Amount, Provider, Status, OrderId | Belongs to: User |
| PaymentSettlement | DriverId, RideId, Amount, Status | Belongs to: Driver, RideRequest |
| UserWallet | UserId, Balance, Currency | Belongs to: User |
| DriverLedgerEntry | DriverId, Type, Amount, Description | Belongs to: Driver |
| Driver | UserId, VehicleType, LicensePlate, IsOnline, IsApproved, KycStatus | Belongs to: User. Has many: RideRequests, DispatchTasks, LedgerEntries |
| RideRequest | UserId, DriverId, Status, VehicleType, Fare, SurgeMultiplier, Rating | Belongs to: User, Driver. Has many: RideEvents |
| RideEvent | RideId, EventType, Timestamp | Belongs to: RideRequest |
| SavedLocation | UserId, Label, Address, GeoLocation | Belongs to: User |
| ScheduledRide | UserId, Pickup, Drop, ScheduledFor, Status | Belongs to: User |
| EmergencyContact | UserId, Name, PhoneNumber | Belongs to: User |
| SosAlert | UserId, RideId, Status, Lat, Lng | Belongs to: User, RideRequest (optional) |
| DispatchTask | DriverId, Type, Status, Payload | Belongs to: Driver |
| FoodOrder | VendorId, UserId, Status, Items, TotalAmount, DeliveryAddress | Belongs to: User, Vendor. Has many: FoodOrderItems |
| FoodOrderItem | OrderId, MenuItemId, Name, Price, Quantity | Belongs to: FoodOrder, MenuItem |
| MenuItem | VendorId, Name, Description, Price, Category, IsVeg, IsAvailable | Belongs to: Vendor |
| Product | Name, Category, Price, IsLateNightEssential, ImageUrl | Has many: ProductOrderItems |
| ProductOrder | UserId, Status, TotalAmount, DeliveryAddress | Belongs to: User. Has many: ProductOrderItems |
| ProductOrderItem | OrderId, ProductId, Name, Price, Quantity | Belongs to: ProductOrder, Product |
| Homestay | Name, Description, LocationArea, NightlyRate, MaxGuests, HasWifi, IsVerified | Has many: RoomAvailability |
| RoomAvailability | HomestayId, Date, AvailableRooms | Belongs to: Homestay |
| BundleBooking | UserId, TotalAmount, Status | Has many: BundleItems |
| BundleItem | BundleBookingId, ServiceType, Reference, Name, Price | Belongs to: BundleBooking |
| SupportTicket | UserId, Subject, Status, Priority | Belongs to: User. Has many: TicketMessages |
| TicketMessage | TicketId, SenderRole, Content, SentAt | Belongs to: SupportTicket |
| VendorPromotion | VendorId, Title, DiscountPercentage, ExpiryTime, IsActive | Belongs to: Vendor |
| SubscriptionPlan | Name, Tier, Price, Features | Has many: UserSubscriptions |
| UserSubscription | UserId, PlanId, StartDate, EndDate, Status | Belongs to: User, SubscriptionPlan |
| AppEventLog | EventType, UserId, Payload, Timestamp | Standalone |
| WaitlistEntry | VenueId, UserId, Position, Status | Belongs to: Venue, User |

### Enum Catalog (30 enums)

| Enum | Values |
|------|--------|
| BookingStatus | Pending, Confirmed, CheckedIn, Completed, Cancelled, Expired |
| CancelReason | UserRequest, VenueClosed, NoShow, Overbooking |
| CancelledBy | User, Venue |
| DispatchTaskStatus | Pending, Accepted, Completed, Cancelled |
| DispatchTaskType | Ride, FoodDelivery, EssentialsDrop |
| FoodOrderStatus | Placed, Accepted, Preparing, OutForDelivery, Delivered, Cancelled |
| KycVerificationStatus | Pending, Approved, Rejected |
| LedgerTransactionType | Credit, Debit |
| LuggageStatus | Reserved, Dropped, Collected, Cancelled |
| MessageSenderRole | User, Agent, Llm |
| PaymentMethod | Unknown, Cash, Upi, Card, NetBanking, Wallet |
| PaymentProvider | None, Razorpay, Stripe, UpiIntent |
| PaymentStatus | Unpaid, Captured, Refunded, Failed |
| ProductCategory | HydrationRecovery, SmokingAccessories, BeachEssentials, Snacks, Misc |
| ProductOrderStatus | Placed, Dispatched, Delivered, Cancelled |
| RentalStatus | Reserved, Active, Returned, Cancelled |
| RideEventType | Requested, Accepted, Arrived, Started, Completed, Cancelled, LocationUpdate |
| RideStatus | Requested, Accepted, EnRoute, Completed, Cancelled, Searching, DriverAssigned, ArrivedAtPickup, DriverCancelled, NoDriversAvailable |
| SaaSTier | Free, Pro |
| ServiceType | Transit, Nightlife, Luggage, Rental, Experience, Homestay |
| SettlementStatus | Pending, Processed, Failed |
| SosStatus | Active, Resolved |
| SubscriptionEnums | (multiple: plan tier, billing cycle, subscription status) |
| SupportTicketStatus | Open, InProgress, Resolved, Escalated |
| TicketPriority | Low, Medium, High, Critical |
| TransitHubKind | Airport, BusStand, RailwayStation |
| TransitStatus | Requested, Assigned, EnRoute, Arrived, Completed, Cancelled |
| UserRole | Tourist, Driver, Vendor, Admin |
| VehicleType | Bike, Auto, Car |
| VendorCategory | LuggageCloak, ScooterRental, TaxiOperator, PubClub, Restaurant, Cafe, Pizzeria |
| VenueCategory | Bar, Club, Pub, Restaurant, Bakery, Cafe, Pizzeria, Experience |

---

## 6. API Surface

### Controllers & Endpoints

| Controller | Base Route | Endpoints |
|-----------|-----------|-----------|
| AuthController | `/api/auth` | `POST /otp`, `POST /otp/verify`, `GET /me`, `POST /aadhaar` |
| VenuesController | `/api/venues` | `GET /` (filter by category), `GET /{id}` |
| BookingsController | `/api/bookings` | `POST /`, `POST /{id}/cancel`, `POST /{id}/complete`, `POST /long-weekend-pass` |
| WaitlistController | `/api/waitlist` | `POST /join`, `GET /{venueId}` |
| TransitController | `/api/transit` | `GET /hubs`, `POST /trips`, `GET /trips`, `POST /trips/{id}/cancel` |
| LuggageController | `/api/luggage` | `GET /vendors`, `POST /drop-offs`, `GET /drop-offs/{id}`, `POST /drop-offs/{id}/cancel` |
| RentalController | `/api/rentals` | `GET /`, `POST /`, `POST /{id}/cancel` |
| FoodDeliveryController | `/api/food` | `GET /vendors`, `GET /vendors/{id}/menu`, `POST /orders`, `GET /orders`, `GET /orders/{id}`, `POST /menu-items` (vendor), `PUT /menu-items/{id}` (vendor), `POST /menu-items/{id}/toggle` (vendor) |
| QuickCommerceController | `/api/products` | `GET /`, `GET /suggestions`, `POST /orders`, `GET /orders`, `GET /orders/{id}` |
| PublicController | `/api/public` | `GET /flash-promos` |
| RideHailingController | `/api/rides` | `POST /`, `POST /{id}/cancel`, `GET /active`, `GET /history`, `GET /{id}`, `POST /{id}/rate`, `GET /{id}/receipt`, `POST /saved-locations`, `GET /saved-locations`, `DELETE /saved-locations/{id}`, `POST /scheduled`, `GET /scheduled`, `POST /sos`, `GET /emergency-contacts`, `POST /emergency-contacts`, `GET /{id}/share/{token}` |
| DriverController | `/api/driver` | `POST /register`, `POST /kyc`, `GET /profile`, `POST /go-online`, `POST /location`, `GET /rides/active`, `POST /rides/{id}/accept`, `POST /rides/{id}/arrive`, `POST /rides/{id}/start`, `POST /rides/{id}/complete`, `GET /earnings`, `GET /wallet`, `GET /dispatch/tasks` |
| HomestaysController | `/api/homestays` | `GET /`, `GET /search`, `GET /{id}`, `POST /book` |
| PaymentsController | `/api/payments` | `POST /`, `POST /{id}/capture`, `POST /{id}/refund`, `GET /{id}` |
| SupportController | `/api/support` | `POST /tickets`, `GET /tickets`, `GET /tickets/{id}`, `POST /tickets/{id}/messages`, `POST /sos` |
| VendorAuthController | `/api/vendor/auth` | `POST /register`, `POST /login` |
| VendorController | `/api/vendor` | `GET /profile`, `POST /priority-ping/activate`, `POST /tickets/validate`, `POST /promotions`, `GET /promotions` |
| VendorsController | `/api/vendors` | `GET /` (public, by category) |
| AdminController | `/api/admin` | `GET /dashboard`, `POST /drivers/{id}/approve` |
| TelemetryController | `/api/telemetry` | `POST /events` |
| DeviceTokenController | `/api/device-token` | `POST /` (register FCM token) |
| WhatsAppWebhookController | `/api/whatsapp/webhook` | `GET /` (verification), `POST /` (message webhook) |

### SignalR Hubs

| Hub | Path | Client → Server | Server → Client |
|-----|------|-----------------|-----------------|
| RideHub | `/hubs/ride` | — | RideStatusUpdate, DriverAssigned, RideCompleted |
| DriverHub | `/hubs/driver` | UpdateLocation, AcceptRide | NewRideOffer, RideCancelled |
| AdminHub | `/hubs/admin` | — | CriticalTicketAlert, DispatchUpdate |

### Rate Limiting

| Policy | Limit | Window | Applied To |
|--------|-------|--------|-----------|
| AuthPolicy | 5 requests | 60s | Auth/OTP endpoints |
| OrderPolicy | 10 requests | 60s | Order creation endpoints |

### Authentication

- **Scheme**: JWT Bearer
- **Token lifetime**: 60 minutes
- **Validation**: Issuer, Audience, IssuerSigningKey, Lifetime (30s clock skew)
- **Auth required**: Booking endpoints (`/venues/:id/book`)
- **Vendor auth**: Separate JWT via VendorAuthController

---

## 7. Infrastructure & Configuration

### Database

| Aspect | Dev | Production |
|--------|-----|-----------|
| Provider | SQLite | PostgreSQL |
| Connection | `Data Source=pondyconnect.db` | `Host=localhost;Port=5432;Database=pondyconnect` |
| Migrations | Auto-applied on startup | Auto-applied on startup |
| Transactions | Supported (Serializable) | Supported (Serializable) |
| Seed data | DataInitializer | DataInitializer |

**Configuration**: `Database:Provider` in appsettings.json switches between SQLite/PostgreSQL.

### Caching

| Mode | When | Implementation |
|------|------|---------------|
| Redis | Connection string present | `StackExchangeRedisCache` + `RedisDistributedLock` |
| In-memory | No Redis configured | `DistributedMemoryCache` + `InMemoryDistributedLock` |

**Usage**: Venue availability cache, distributed locking for concurrent bookings.

### Real-time (SignalR)

3 hubs mapped in `Program.cs`:
- `/hubs/ride` — Rider-facing ride status updates
- `/hubs/driver` — Driver-facing ride offers + location updates
- `/hubs/admin` — Admin dispatch monitoring + critical ticket alerts

**Frontend clients**: `SignalRClient` wrapper using `signalr_netcore` package, connects with JWT auth.

### Payments

| Mode | When | Implementation |
|------|------|---------------|
| Razorpay | KeyId + KeySecret configured | `RazorpayGateway` (HttpClient) |
| Noop | Keys empty (dev) | `NoopPaymentGateway` (simulated capture) |

**Configuration**: `Razorpay:KeyId`, `Razorpay:KeySecret`, `Razorpay:WebhookSecret` in appsettings.json.

### Notifications (FCM)

| Mode | When | Implementation |
|------|------|---------------|
| Firebase | IsEnabled=true + ServiceAccountPath set | `FirebaseNotificationService` |
| Mock | Dev/fallback | `MockNotificationService` |

**Configuration**: `Firebase:IsEnabled`, `Firebase:ServiceAccountPath` in appsettings.json.

### SMS/OTP

| Mode | When | Implementation |
|------|------|---------------|
| Console | Always (dev) | `ConsoleSmsSender` (logs to console) |

**Configuration**: `Sms:Provider` in appsettings.json.

### Routing (OSRM)

- **Server**: `OsrmRoutingService` — distance validation, route geometry. Configured via `Osrm:BaseUrl`.
- **Client**: `OsrmRoutingService` (Flutter) — route polyline, distance, duration for ride fare calculation.

### WhatsApp Cloud API

- `WhatsAppHttpClient` — Graph API v18.0 client
- `WhatsAppWebhookController` — webhook verification + message handling
- **Configuration**: `WhatsApp:WebhookVerifyToken`, `WhatsApp:AppSecret`, `WhatsApp:PhoneNumberId`, `WhatsApp:AccessToken`

### Background Services

| Service | Type | Purpose |
|---------|------|---------|
| `FlashPromoExpiryWorker` | IHostedService | Expires flash promotions past their expiry time |
| `ScheduledPayoutWorker` | IHostedService | Processes scheduled driver payouts |
| `TelemetryBatchProcessor` | IHostedService | Batches and flushes telemetry events to DB |

### Geo-fence

`ServiceAreaValidator` — validates that coordinates are within 3km radius of Pondicherry center (11.9356, 79.8301). Used in ride-hailing and delivery endpoints.

**Configuration**: `ServiceArea:CenterLatitude`, `ServiceArea:CenterLongitude`, `ServiceArea:RadiusKm`.

### Health Checks

`/health` endpoint reports:
- Database connectivity
- SignalR hub health
- Redis connectivity (if configured)

---

## 8. Testing

### Backend Unit Tests (`PondyConnect.Architecture.Tests`)

| Test File | Coverage |
|-----------|----------|
| `DomainEntityTests.cs` (60KB) | All 33 domain entities — creation, validation, state transitions |
| `BookingEngineTests.cs` | Booking engine — capacity checks, concurrent bookings, pass tokens |
| `CreateBookingCommandHandlerTests.cs` | Create booking command handler — edge cases, validation |
| `DataInitializerTests.cs` | Seed data integrity |
| `DriverWalletTests.cs` | Driver wallet — credits, debits, balance, settlement |
| `HomestayBundlingTests.cs` | Stay bundling — add-on suggestions, pricing |
| `SosPricingTests.cs` | SOS pricing calculation |
| `SupportTriageTests.cs` | Support ticket triage — LLM classification, escalation |
| `VendorB2bDomainTests.cs` | Vendor B2B domain — priority ping, promotions |
| `VendorB2bFlowTests.cs` | Vendor B2B end-to-end flow |
| `ApplicationServiceTests.cs` (15KB) | Application service registration and resolution |
| `ArchitectureTests.cs` | Architecture rules — layer dependency validation |

### Backend Integration Tests (`PondyConnect.Api.Tests`)

| Test File | Coverage |
|-----------|----------|
| `IntegrationTests.cs` (84KB) | Full API integration — all controllers, auth flow, booking, rides, food, essentials, transit, luggage, rentals, stays, vendor, admin, support, payments |
| `CustomWebApplicationFactory.cs` | Test server factory with in-memory DB, test auth |

### E2E Tests (Playwright)

| Spec File | Coverage |
|-----------|----------|
| `auth.spec.ts` | OTP login flow |
| `venues.spec.ts` | Venue list, detail, booking |
| `food.spec.ts` | Restaurant list, menu, order |
| `rides.spec.ts` | Ride request, tracking |
| `transit.spec.ts` | Transit hubs, trip booking |
| `stays.spec.ts` | Homestay search, booking |
| `essentials.spec.ts` | Product browsing, cart, checkout |

---

## 9. Current State Assessment

### Feature Maturity Matrix

| Feature | Backend | Frontend | Design System | Overall |
|---------|---------|----------|--------------|---------|
| Authentication | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Venues | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Bookings | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Transit | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Luggage Cloak | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Scooter Rental | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Ride Hailing | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Driver App | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Stays | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Experiences | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Food Delivery | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Quick Commerce | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Vendor B2B | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Admin | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Support | ✅ Complete | ✅ Complete | ✅ Migrated | **Production-ready** |
| Payments | ✅ Complete | N/A (embedded) | N/A | **Production-ready** |
| Notifications | ✅ Complete | ✅ Complete | N/A | **Production-ready** |
| Telemetry | ✅ Complete | ✅ Complete | N/A | **Production-ready** |

### Design System Adoption Status

| Screen | Design System Widgets Used | Status |
|--------|--------------------------|--------|
| Venue List | AppCard, StatusBadge, RatingStars, ShimmerList, EmptyState, ErrorState, SectionHeader | ✅ Full |
| Venue Detail | RatingStars, StatusBadge, SectionHeader | ✅ Full |
| Booking Screen | StatusBadge, AppBottomSheet | ✅ Full |
| Transit Screen | AppCard, StatusBadge, SectionHeader, ShimmerList, EmptyState, ErrorState | ✅ Full |
| Experiences | AppCard, StatusBadge, RatingStars, ShimmerList, EmptyState, ErrorState, SectionHeader | ✅ Full |
| Stays List | ShimmerList, EmptyState, ErrorState | ✅ Full |
| Stays Detail | ErrorState | ✅ Full |
| Essentials | ShimmerList, EmptyState, ErrorState | ✅ Full |
| Food | AppCard, StatusBadge, ShimmerList, EmptyState, ErrorState | ✅ Full |
| Rides | AppCard, StatusBadge, ShimmerList, EmptyState, ErrorState | ✅ Full |
| Driver | AppCard, StatusBadge, ShimmerList, EmptyState, ErrorState | ✅ Full |
| Vendor | AppCard, StatusBadge, ShimmerList, EmptyState, ErrorState | ✅ Full |
| Admin | AdminColors palette, StatusBadge, ShimmerList, EmptyState, ErrorState | ✅ Full |

### Known SQLite Workarounds

The dev database uses SQLite which has limitations:
- **Enum filtering**: Handled via integer comparisons instead of enum casts
- **DateTimeOffset ordering**: SQLite stores DateTimeOffset as string; comparisons use Unix epoch
- **No JSON columns**: Complex objects stored as separate entities or serialized strings

### Recent Enhancements (Phases 1-8)

| Phase | Description | Status |
|-------|-------------|--------|
| 1A | Design system widgets (10 reusable components) | ✅ Complete |
| 1B | Navigation fixes (Pub Entry, Live Crowd, AC Cafes routes) | ✅ Complete |
| 1C | Luggage cloak backend (cancel, get-by-id) + Flutter UI redesign | ✅ Complete |
| 1D | Pub entry flow (nightlife filter, booking success with pass token) | ✅ Complete |
| 2A | Backend venue image URLs + ratings fields | ✅ Complete |
| 2C-E | Venue list + detail + booking screen full redesign | ✅ Complete |
| 3 | Transit/Mobility redesign (trip status badges, rental vendor list, rental cards) | ✅ Complete |
| 4A | Experiences screen redesign (design system, image cards, safety cards) | ✅ Complete |
| 4B | Stays screen polish (shimmer, empty/error states, booking confirmation) | ✅ Complete |
| 4C | Essentials screen polish (design system shimmer/empty/error, order result) | ✅ Complete |
| 5 | Backend security hardening (100+ fixes: IDOR, ownership, race conditions, validation) | ✅ Complete |
| 6 | 3-app consolidation (removed vendor flavor, category-aware partner app) | ✅ Complete |
| 7 | Mobile UI remediation (330+ fixes: semantic colors, theme-aware, dark mode) | ✅ Complete |
| 8 | Git initialization, CI/CD setup (5 workflows, 12 secrets), web app deployment | ✅ Complete |

### Build Status

| Target | Command | Result |
|--------|---------|--------|
| Backend build | `dotnet build` | 0 warnings, 0 errors |
| Architecture tests | `dotnet test --filter Architecture` | 288/288 pass |
| Flutter analyze | `flutter analyze` | 0 errors (30 info/warnings) |
| Consumer APK | `flutter build apk --flavor consumer --release` | 76.4 MB ✅ |
| Driver APK | `flutter build apk --flavor driver --release` | 76.4 MB ✅ |
| Partner APK | `flutter build apk --flavor partner --release` | 76.4 MB ✅ |
| Admin web | `flutter build web --target lib/main_admin.dart` | Deployed ✅ |
| Partner web | `flutter build web --target lib/main_partner.dart` | Deployed ✅ |

---

## 10. Work Completed (Sessions 1-5)

### 10.1 Backend Security Hardening (100+ fixes)

- Ride lifecycle ownership validation (start/complete/cancel require JWT-derived user ID)
- Admin-only ride reassignment
- User-scoped luggage, rental, and transit list queries
- Nearby-driver authorization and coordinate/radius validation
- Real SOS event queries replacing mock data
- File-based surge-state persistence across restarts
- SOS trigger and resolution logging
- OTP success/failure logging
- Payment initiation logging
- Guid.Empty validation across 10+ domain entities
- UserSubscription.Cancel idempotency
- One-active-ride-per-consumer constraint
- Priority ping credit double-spend race condition fixed
- IDOR vulnerabilities fixed in support tickets, ride details, KYC access
- Vendor self-registration now creates User account
- Admin cannot change own role or deactivate self
- OTP peek endpoint blocked in production via IsDevelopment() check
- HSTS enabled in production
- Forwarded headers middleware for Nginx reverse proxy
- CORS localhost entries removed from docker-compose.prod.yml
- AllowedHosts restricted from * to pyconnect.run.place;localhost

### 10.2 3-App Consolidation

- Removed redundant `vendor` Android flavor (was duplicate of `partner`)
- Deleted `main_vendor.dart` (identical to `main_partner.dart`)
- Removed `vendor` signingConfig and productFlavor from build.gradle.kts
- Partner app adapts to vendor category (7 categories)
- Category-specific screens: drinks_menu, fleet_management, active_rentals, taxi_fleet, taxi_rides, cloak_capacity
- Web deployment path changed from /var/www/vendor/ to /var/www/partner/

### 10.3 Mobile UI Remediation (330+ fixes across 67+ files)

- Added semantic colors to AppTheme: success, danger, warning, info
- Added dark theme constants: darkBackground, darkSurface
- AdminColors class for admin web dark SaaS theme
- Consumer app: 28 files fixed
- Driver app: 6 files fixed
- Partner app: 18 files fixed
- Admin app: 15 files fixed
- Eliminated all hardcoded Colors.grey (was 329+ instances, now 0)
- Replaced Colors.red/green/amber/blue with AppTheme.danger/success/warning/info
- Fixed invisible text (dark-on-dark) in admin pagination, partner menu, partner promotions
- Fixed admin SOS phone button (was no-op, now launches tel: URI)
- All SnackBars now have backgroundColor
- All loading indicators now have visible colors

### 10.4 Git & CI/CD Configuration

- Git repository initialized with main as default branch
- Comprehensive root .gitignore (secrets, build artifacts, dev test scripts)
- Zero secrets tracked (verified)
- 618 files committed to https://github.com/balabm/PyConnect.git
- 5 CI/CD workflows:
  - ci-backend.yml: Build + 288 architecture tests on PR/push
  - ci-mobile.yml: Flutter analyze on PR/push
  - deploy-backend.yml: Docker build → Docker Hub → EC2 deploy → health check
  - deploy-web.yml: Flutter web build → SCP to EC2 → Nginx reload
  - deploy-mobile.yml: Signed APK + AAB builds on tag push (v*)
- 12 GitHub secrets configured

### 10.5 Deployment Status

| Component | Status | Details |
|-----------|--------|---------|
| Web Admin | ✅ Deployed & Verified | https://pyconnect.run.place/ (200 OK) |
| Web Partner | ✅ Deployed & Verified | https://pyconnect.run.place/partner/ (200 OK) |
| Backend | ⏳ Pending Deployment | 90+ local fixes not yet on EC2 |
| Mobile APKs | ✅ Built Locally | 76.4 MB each (debug-signed, not on Play Store) |
| Git Repo | ✅ Pushed | https://github.com/balabm/PyConnect.git |
| GitHub Secrets | ✅ 12/12 Configured | All deployment secrets set |

---

## 11. CI/CD & Deployment

### GitHub Actions Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Backend CI | `ci-backend.yml` | PR + push to main | Build + 288 architecture tests |
| Mobile CI | `ci-mobile.yml` | PR + push to main | Flutter static analysis |
| Deploy Backend | `deploy-backend.yml` | Push to main (backend paths) | Docker build → Docker Hub → EC2 → health check |
| Deploy Web | `deploy-web.yml` | Push to main (mobile paths) | Flutter web build → SCP to EC2 → Nginx reload |
| Deploy Mobile | `deploy-mobile.yml` | Tag push `v*` | Signed APK + AAB builds → GitHub artifacts |

### GitHub Secrets (12)

| Secret | Used By | Description |
|--------|---------|-------------|
| DOCKERHUB_USERNAME | deploy-backend | Docker Hub username |
| DOCKERHUB_TOKEN | deploy-backend | Docker Hub access token |
| EC2_HOST | deploy-backend, deploy-web | EC2 public IP |
| EC2_USER | deploy-backend, deploy-web | SSH user |
| EC2_SSH_KEY | deploy-backend, deploy-web | PEM private key |
| KEYSTORE_BASE64 | deploy-mobile | Base64-encoded .jks keystore |
| KEY_STORE_PASSWORD | deploy-mobile | Keystore store password |
| KEY_PASSWORD | deploy-mobile | Key password |
| KEY_ALIAS | deploy-mobile | Key alias |
| GOOGLE_SERVICES_JSON | deploy-mobile | Firebase config |
| API_BASE_URL | deploy-web, deploy-mobile | https://pyconnect.run.place |
| RAZORPAY_KEY_ID | deploy-mobile | Razorpay key ID |

### Nginx Configuration

Version-controlled at `deploy/nginx.conf`:
- HTTP → HTTPS redirect
- TLS with Let's Encrypt certificates
- Reverse proxy to backend (127.0.0.1:5000)
- WebSocket upgrade for /hubs/ride, /hubs/driver, /hubs/admin
- Forwarded headers (X-Forwarded-For, X-Forwarded-Proto)
- Rate limiting at proxy level
- Static file serving for /var/www/admin/ and /var/www/partner/
- Security headers (HSTS, X-Frame-Options, X-Content-Type-Options)

---

*Document generated from codebase analysis. Last updated: August 2026. Updated with all session work (security, UI, CI/CD, deployment).*
