# PY Connect Captain — Background Location Justification for Google Play

## App Details
- **App Name**: PY Connect Captain
- **Package Name**: com.pondyconnect.driver
- **Category**: Maps & Navigation

## Background Location Use Case

### Which use case best describes your app's background location access?
**Ride-hailing and taxi services**: The app uses background location to match drivers with nearby ride requests and to share the driver's live location with riders during active rides.

## Detailed Justification

### 1. What feature(s) in your app use background location?
The PY Connect Captain app uses background location for two critical features:

**A. Ride Dispatch Matching**
When a driver marks themselves as ONLINE, the app continuously sends their GPS location to the backend dispatch system. This allows the system to:
- Find the nearest available drivers for incoming ride requests
- Calculate accurate pickup distances and ETAs for riders
- Send ride offers to drivers based on proximity

**B. Rider Safety and Pickup Navigation**
During an active ride, the driver's live location is shared with the rider so they can:
- Track the driver's approach to the pickup point
- See real-time ETA updates
- Share their live location with trusted contacts for safety

### 2. How does the user benefit from this feature?
- **Drivers** receive ride offers without needing to keep the app in the foreground, allowing them to use navigation apps or take calls while waiting for rides
- **Riders** can see their driver approaching in real-time, reducing anxiety and wait times
- **Safety** is enhanced through live location sharing during active rides

### 3. Is the background location access initiated by the user?
Yes. The driver must explicitly tap the "ONLINE" toggle in the app to start background location tracking. When the driver taps "OFFLINE", all background location tracking stops immediately. The user has full control over when background location is active.

### 4. Could this feature be achieved without background location?
No. The core functionality of a ride-hailing driver app requires continuous location updates:
- Without background location, drivers would miss ride offers when their screen is off or when using another app (like Google Maps for navigation)
- Without live driver location, riders cannot track their driver's approach, which is a safety-critical feature
- The dispatch system requires real-time driver positions to make efficient match decisions

### 5. How do you minimize background location use?
- Background location is ONLY active when the driver has explicitly toggled ONLINE
- When the driver goes OFFLINE, background location stops completely
- Location updates are sent every 5 seconds (not continuous high-frequency polling)
- The app uses a foreground service with a persistent notification ("Tracking location for active rides") so the driver is always aware that location tracking is active
- The driver can revoke location permission at any time through Android Settings

### 6. What permissions does your app request?
- `ACCESS_FINE_LOCATION` — for accurate GPS positioning
- `ACCESS_COARSE_LOCATION` — fallback for approximate location
- `ACCESS_BACKGROUND_LOCATION` — for location tracking while the app is in the background
- `FOREGROUND_SERVICE` — to run the location tracking service
- `FOREGROUND_SERVICE_LOCATION` — Android 14+ foreground service type declaration

### 7. Foreground Service Details
- **Service Name**: LocationTrackingService
- **Foreground Service Type**: `location`
- **Notification**: Persistent notification with title "PondyConnect Captain" and content "Tracking location for active rides"
- **Notification Channel**: "Location Tracking" (IMPORTANCE_LOW)
- **Behavior**: START_STICKY (restarts if killed by the system)

## Permissions Declaration for Play Console

### Foreground Service Type
`FOREGROUND_SERVICE_TYPE_LOCATION`

### Background Location Declaration
- **Purpose**: Ride-hailing/driver dispatch
- **User-initiated**: Yes (driver toggles ONLINE/OFFLINE)
- **Frequency**: Every 5 seconds while online
- **Notification**: Always visible while active
- **Opt-out**: Driver can go OFFLINE at any time

## Video Demonstration
A video demonstrating the background location feature will be submitted showing:
1. Driver tapping the ONLINE toggle (initiating background location)
2. The persistent notification appearing
3. The app being sent to the background
4. Location updates continuing (verified via backend dashboard)
5. Driver tapping OFFLINE (stopping background location)
6. The notification disappearing
