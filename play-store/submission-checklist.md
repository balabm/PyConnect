# PY Connect — Google Play Console Submission Checklist

## Pre-Submission

### All Apps
- [x] App bundles (.aab) built and signed
  - `app-consumer-release.aab` (67.6 MB) — com.pondyconnect.app
  - `app-driver-release.aab` (67.6 MB) — com.pondyconnect.driver
  - `app-partner-release.aab` (67.6 MB) — com.pondyconnect.partner
- [x] Signing key SHA1: 73:90:05:0D:72:19:3D:43:1E:BE:0D:41:BC:0D:36:AC:40:6A:0A:A3
- [x] targetSdk = 36 (Android 16) — compliant with Google Play 2026 mandate
- [x] minSdk = 24 (Android 7.0) — covers 98%+ of devices
- [x] Privacy Policy URL: https://pyconnect.run.place/privacy-policy
- [x] Privacy Policy document created (play-store/privacy-policy.md)
- [x] Data Safety form responses prepared (play-store/data-safety-form.md)
- [x] Store listings prepared (play-store/listings/*/store-listing.txt)

### Screenshots Required (per app)
- [ ] Phone screenshots (minimum 2, maximum 8) — 1080x1920 or 16:9 aspect ratio
- [ ] Recommended: Home screen, ride booking, order tracking, profile
- [ ] 7-inch tablet screenshots (optional)
- [ ] Feature graphic (1024x500 PNG) — optional but recommended

### App Icons
- [x] Adaptive launcher icon configured (mipmap/ic_launcher)
- [ ] High-res icon (512x512 PNG) for Play Console — needs to be exported

## Per-App Submission

### 1. PY Connect (Consumer) — com.pondyconnect.app
- [ ] Create new app in Play Console
- [ ] Set app name: "PY Connect"
- [ ] Category: Travel & Local
- [ ] Content rating: Everyone (fill out IARC questionnaire)
- [ ] Upload `app-consumer-release.aab`
- [ ] Add store listing from `play-store/listings/consumer/store-listing.txt`
- [ ] Add privacy policy URL
- [ ] Complete Data Safety form
- [ ] Select target audience
- [ ] Submit for review

### 2. PY Connect Captain (Driver) — com.pondyconnect.driver
- [ ] Create new app in Play Console
- [ ] Set app name: "PY Connect Captain"
- [ ] Category: Maps & Navigation
- [ ] Content rating: Everyone (fill out IARC questionnaire)
- [ ] Upload `app-driver-release.aab`
- [ ] Add store listing from `play-store/listings/driver/store-listing.txt`
- [ ] Add privacy policy URL
- [ ] Complete Data Safety form
- [ ] **Complete Background Location Declaration** (see below)
- [ ] Select target audience
- [ ] Submit for review

#### Background Location Declaration (Driver App Only)
- [ ] In Play Console > App Content > Background Location Access
- [ ] Fill out the justification form using `play-store/background-location-justification.md`
- [ ] Record a video demonstrating:
  1. Driver going ONLINE (starting background location)
  2. Persistent notification appearing
  3. App sent to background
  4. Location updates continuing (show in admin dashboard)
  5. Driver going OFFLINE (stopping background location)
  6. Notification disappearing
- [ ] Upload video to YouTube (unlisted) and provide URL in declaration
- [ ] Submit declaration for review

### 3. PY Connect Partner — com.pondyconnect.partner
- [ ] Create new app in Play Console
- [ ] Set app name: "PY Connect Partner"
- [ ] Category: Business
- [ ] Content rating: Everyone (fill out IARC questionnaire)
- [ ] Upload `app-partner-release.aab`
- [ ] Add store listing from `play-store/listings/partner/store-listing.txt`
- [ ] Add privacy policy URL
- [ ] Complete Data Safety form
- [ ] Select target audience
- [ ] Submit for review

## Post-Submission

- [ ] Monitor review status in Play Console
- [ ] Respond to any review feedback from Google
- [ ] Once approved, set up managed production rollout (start with 10%)
- [ ] Monitor crash reports and user feedback
- [ ] Plan staged rollout: 10% → 50% → 100% over 2 weeks

## App Signing

Google Play App Signing is recommended. When uploading the first .aab:
1. Play Console will ask to opt into App Signing
2. Google will re-sign the app with its own key for distribution
3. Your upload key (the one in key.properties) is used to authenticate uploads
4. Keep your upload key safe — it's required for all future updates

## Firebase Configuration

Each app package has its own Firebase project configuration:
- com.pondyconnect.app — Consumer FCM
- com.pondyconnect.driver — Driver FCM (ride offer notifications)
- com.pondyconnect.partner — Partner FCM (order notifications)

Verify that `google-services.json` is correctly configured for each flavor before submission.
