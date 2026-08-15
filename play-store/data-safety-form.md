# PY Connect — Data Safety Form Responses

## Data Collected

### 1. Location
- **Approximate Location**: Yes
- **Precise Location**: Yes
- **Is collection optional?**: Yes (user can deny permission)
- **Purpose**: App functionality (ride matching, navigation, tracking)
- **Background collection**: Yes (driver app only, when online)
- **Use case**: Ride-hailing and taxi services

### 2. Personal Information
- **Name**: Yes
- **Phone Number**: Yes
- **Email Address**: Yes (optional)
- **Is collection optional?**: Email is optional; name and phone required
- **Purpose**: Account creation, authentication, communication

### 3. Photos and Videos
- **Profile Photo**: Yes (drivers and partners, optional)
- **KYC Documents**: Yes (drivers: license, RC, insurance, selfie; partners: FSSAI, GSTIN, PAN)
- **Is collection optional?**: Required for driver/partner verification
- **Purpose**: Identity verification, KYC compliance

### 4. Financial Information
- **Payment Method**: Yes (via Razorpay — we do not store card/UPI details)
- **Bank Account Number**: Yes (drivers and partners for payouts)
- **Is collection optional?**: Required for payouts
- **Purpose**: Payments and payouts

### 5. App Activity
- **App Interactions**: Yes (orders, rides, bookings)
- **Search History**: Yes (within app)
- **Is collection optional?**: No
- **Purpose**: App functionality, personalization

### 6. App Info and Performance
- **Crash Logs**: Yes (via Firebase Crashlytics if enabled)
- **Diagnostics**: Yes
- **Is collection optional?**: Yes
- **Purpose**: Analytics, app improvement

### 7. Device or Other IDs
- **Device Token (FCM)**: Yes
- **Is collection optional?**: Yes (can disable notifications)
- **Purpose**: Push notifications

## Data Sharing
- **Shared with**: Razorpay (payments), AWS (hosting), Firebase (notifications)
- **Purpose**: Payment processing, cloud infrastructure, push notifications
- **Data shared**: Payment info (Razorpay), device token (Firebase), all data (AWS hosting)

## Security Practices
- **Data encrypted in transit**: Yes (HTTPS/TLS)
- **Data encrypted at rest**: Yes (AWS RDS encryption, S3 bucket encryption)
- **Data deletion request**: Yes (via support@pyconnect.run.place)
- **Compliance**: Digital Personal Data Protection Act, 2023 (India)

## Data Deletion
Users can request data deletion by emailing support@pyconnect.run.place. Account data and associated records will be deleted within 30 days, except where retention is required by law (e.g., KYC documents, transaction records for tax compliance).
