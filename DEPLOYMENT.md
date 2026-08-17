# PY Connect — Production Deployment Guide

Step-by-step checklist for deploying PY Connect to production.

---

## Current Deployment Status (2026-08-15)

| Component | Status | Details |
|-----------|--------|---------|
| Git Repository | ✅ Initialized & Pushed | https://github.com/balabm/PyConnect.git (618 files) |
| GitHub Secrets | ✅ 12/12 Configured | All deployment secrets set |
| Web Admin | ✅ Deployed & Verified | https://pyconnect.run.place/ (200 OK) |
| Web Partner | ✅ Deployed & Verified | https://pyconnect.run.place/partner/ (200 OK) |
| Backend | ⏳ Pending Deployment | 90+ local fixes not yet on EC2 |
| Mobile APKs | ✅ Built Locally | 76.4 MB each (debug-signed, not on Play Store) |
| Nginx | ✅ Running on EC2 | Reverse proxy + WebSocket + TLS |
| CI/CD | ✅ 5 Workflows Configured | ci-backend, ci-mobile, deploy-backend, deploy-web, deploy-mobile |

### Next Steps for Full Production
1. Deploy backend fixes to EC2 (trigger `deploy-backend.yml` or push backend changes to `main`)
2. Rotate all secrets (JWT key, DB password, SMS key, Razorpay keys) — see Phase 1 below
3. Upload signed APKs to Play Store (trigger `deploy-mobile.yml` with a `v*` tag)
4. Configure branch protection on GitHub (require Backend CI + Mobile CI)

## Prerequisites

- AWS EC2 instance (Ubuntu 22.04+) with SSH access
- Docker and Docker Compose installed on EC2
- Domain name (`pyconnect.run.place`) pointing to EC2 public IP
- SSL certificates via Let's Encrypt/certbot
- GitHub repo secrets configured (see CI/CD section below)

---

## Phase 1: Rotate Secrets (CRITICAL)

All secrets were exposed in the local `.env` during development. Before deploying, rotate EVERY secret:

### 1.1 JWT Signing Key
```bash
# Generate a cryptographically secure key (min 32 chars)
openssl rand -base64 48
# Set as JWT_KEY in production environment
```

### 1.2 Database Password
- Go to AWS RDS console → Modify instance → Change master password
- Update the connection string in your production env vars

### 1.3 Fast2SMS API Key
- Log into Fast2SMS dashboard
- Regenerate API key
- Update `SMS_API_KEY` in production env vars

### 1.4 Razorpay Keys
- Log into Razorpay dashboard → Settings → API Keys
- Generate new key pair (use LIVE keys for production, not TEST)
- Update `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`

### 1.5 Mobile Keystore
- Generate new keystore with strong passwords:
```bash
keytool -genkey -v -keystore pyconnect-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias pyconnect
```
- Update `key.properties` with new strong passwords
- Update GitHub secrets: `KEYSTORE_BASE64`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`

---

## Phase 2: Deploy Backend

### 2.1 Configure EC2 Environment

SSH into EC2 and create the production env file:
```bash
ssh ubuntu@your-ec2-ip
sudo mkdir -p /opt/pyconnect
sudo chown ubuntu:ubuntu /opt/pyconnect
cd /opt/pyconnect

# Create .env with REAL production secrets
cat > .env << 'EOF'
JWT_KEY=<your-rotated-jwt-key>
JWT_ISSUER=https://pyconnect.run.place
JWT_AUDIENCE=https://pyconnect.run.place
ConnectionStrings__DefaultConnection=Host=<rds-host>;Port=5432;Database=pondyconnect;Username=postgres;Password=<rotated-password>
SMS_API_KEY=<your-rotated-sms-key>
RAZORPAY_KEY_ID=<your-live-razorpay-key-id>
RAZORPAY_KEY_SECRET=<your-live-razorpay-key-secret>
RAZORPAY_WEBHOOK_SECRET=<your-webhook-secret>
FIREBASE_IS_ENABLED=true
EOF

chmod 600 .env  # Restrict permissions
```

### 2.2 Deploy Nginx Configuration

```bash
# Copy nginx config from repo
sudo cp deploy/nginx.conf /etc/nginx/sites-available/pyconnect
sudo ln -sf /etc/nginx/sites-available/pyconnect /etc/nginx/sites-enabled/pyconnect
sudo rm -f /etc/nginx/sites-enabled/default  # Remove default site

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### 2.3 Deploy Firebase Service Account

```bash
# Upload Firebase service account JSON
scp firebase-service-account.json ubuntu@your-ec2-ip:/opt/pyconnect/
ssh ubuntu@your-ec2-ip
sudo cp /opt/pyconnect/firebase-service-account.json /app/firebase-service-account.json
```

### 2.4 Deploy Backend via CI/CD

Push to `main` branch — the GitHub Actions workflow `deploy-backend.yml` will:
1. Build Docker image
2. Push to Docker Hub
3. SSH into EC2
4. Pull new image and restart container

Or manually deploy:
```bash
cd /opt/pyconnect
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

### 2.5 Verify Backend Health

```bash
curl https://pyconnect.run.place/health
# Should return JSON with status "Healthy"
```

---

## Phase 3: Deploy Web Admin

Push to `main` — the `deploy-web.yml` workflow will:
1. Build the web admin static files
2. SCP them to EC2
3. Reload Nginx

---

## Phase 4: Build & Release Mobile Apps

### 4.1 Configure GitHub Secrets

Ensure these secrets are set in GitHub repo settings:

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | Base64-encoded release keystore (.jks) |
| `KEY_STORE_PASSWORD` | Keystore password (strong) |
| `KEY_PASSWORD` | Key password (strong) |
| `KEY_ALIAS` | Key alias (e.g., `pyconnect`) |
| `GOOGLE_SERVICES_JSON` | Firebase config for Android |
| `RAZORPAY_KEY_ID` | Razorpay key ID for mobile |

### 4.2 Build Release APKs

Via GitHub Actions (recommended):
- Trigger `deploy-mobile.yml` workflow

Or locally:
```bash
cd mobile
flutter pub get

# Consumer app
flutter build apk --flavor consumer --target lib/main.dart --release

# Driver app
flutter build apk --flavor driver --target lib/main_driver.dart --release

# Partner app
flutter build apk --flavor partner --target lib/main_partner.dart --release
```

### 4.3 Verify Release Builds

```bash
# Check APK is signed with release key
jarsigner -verify -verbose build/app/outputs/flutter-apk/app-consumer-release.apk
```

### 4.4 Configure Native Deep Links

1. **Android App Links**: Replace the `PLACEHOLDER_SHA256_FINGERPRINT` values in `deploy/.well-known/assetlinks.json` with the real SHA-256 fingerprints of each flavor's release signing keystore:
   ```bash
   keytool -list -v -keystore pyconnect-release.jks -alias pyconnect | grep SHA256
   ```
   Upload the updated `assetlinks.json` to `https://pyconnect.run.place/.well-known/assetlinks.json`.

2. **iOS Universal Links**: Update `TEAM_ID` in `deploy/.well-known/apple-app-site-association` with the real Apple Team ID. Upload the file (no file extension) to `https://pyconnect.run.place/.well-known/apple-app-site-association` and ensure it is served with `Content-Type: application/json`.

3. Verify both files are reachable over HTTPS and match the package/bundle IDs:
   - `com.pondyconnect.app`
   - `com.pondyconnect.driver`
   - `com.pondyconnect.partner`

---

## Phase 5: Post-Deployment Smoke Tests

### 5.1 Backend Smoke Tests

```bash
# Health check
curl https://pyconnect.run.place/health

# Auth flow
curl -X POST https://pyconnect.run.place/api/auth/otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919999999999"}'

# Public venues
curl https://pyconnect.run.place/api/venues

# WebSocket connectivity (install wscat)
npm install -g wscat
wscat -c "wss://pyconnect.run.place/hubs/ride"
```

### 5.2 Mobile App Smoke Tests

For each app (Consumer, Driver, Partner):
1. Install release APK
2. Verify OTP login works
3. Verify map loads
4. Verify API connectivity (no localhost errors)
5. Verify SignalR real-time updates

### 5.3 End-to-End Flow Tests

- [ ] Consumer can request a ride
- [ ] Driver receives ride offer
- [ ] Driver accepts, arrives, verifies OTP, starts ride
- [ ] Ride completes, receipt generated
- [ ] Consumer can browse food/venues
- [ ] Partner can manage menu/orders
- [ ] Admin dashboard shows live data
- [ ] SOS triggers and admin receives alert
- [ ] Payment flow works end-to-end

---

## Phase 6: Monitoring Setup

### 6.1 Application Logging
- Backend logs: `docker compose -f docker-compose.prod.yml logs -f api`
- Set up log rotation: `docker compose -f docker-compose.prod.yml logs --rotate 7`

### 6.2 Health Monitoring
- Set up uptime monitoring on `https://pyconnect.run.place/health`
- Set up alerts for health check failures

### 6.3 Crash Reporting (Mobile)
- Enable Firebase Crashlytics in mobile apps
- Monitor crash rates in Firebase console

---

## Rollback Plan

If deployment fails or causes issues:

```bash
# Roll back to previous Docker image
cd /opt/pyconnect
docker compose -f docker-compose.prod.yml down
docker pull balabm/pyconnect-backend:<previous-tag>
# Update docker-compose.prod.yml image tag
docker compose -f docker-compose.prod.yml up -d
```

For Nginx rollback:
```bash
sudo rm /etc/nginx/sites-enabled/pyconnect
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
sudo systemctl reload nginx
```

---

## Production Environment Variables Reference

All variables must be set in `/opt/pyconnect/.env` on EC2:

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_KEY` | YES | Cryptographically random, min 32 chars |
| `JWT_ISSUER` | YES | `https://pyconnect.run.place` |
| `JWT_AUDIENCE` | YES | `https://pyconnect.run.place` |
| `ConnectionStrings__DefaultConnection` | YES | PostgreSQL RDS connection string |
| `Database__Provider` | YES | `PostgreSQL` |
| `ConnectionStrings__Redis` | YES | `redis:6379` |
| `SMS_API_KEY` | YES | Fast2SMS API key |
| `SMS_PROVIDER` | YES | `Fast2SMS` |
| `SMS_USE_MOCK` | YES | `false` |
| `RAZORPAY_KEY_ID` | YES | Razorpay LIVE key ID |
| `RAZORPAY_KEY_SECRET` | YES | Razorpay LIVE key secret |
| `RAZORPAY_WEBHOOK_SECRET` | YES | Razorpay webhook secret |
| `PAYMENTS_USE_MOCK` | YES | `false` |
| `FIREBASE_IS_ENABLED` | RECOMMENDED | `true` |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | IF ENABLED | `/app/firebase-service-account.json` |
| `OSRM_BASE_URL` | OPTIONAL | Self-hosted OSRM URL |
| `WHATSAPP_ACCESS_TOKEN` | OPTIONAL | WhatsApp Cloud API token |
| `WHATSAPP_PHONE_NUMBER_ID` | OPTIONAL | WhatsApp phone number ID |

---

## CI/CD Setup

### GitHub Repository Secrets

Configure these in GitHub repo → Settings → Secrets and variables → Actions:

| Secret | Used By | Description | Status |
|--------|---------|-------------|--------|
| `DOCKERHUB_USERNAME` | deploy-backend | Docker Hub username | ✅ |
| `DOCKERHUB_TOKEN` | deploy-backend | Docker Hub access token (not password) | ✅ |
| `EC2_HOST` | deploy-backend, deploy-web | EC2 public IP | ✅ |
| `EC2_USER` | deploy-backend, deploy-web | SSH user (`ubuntu`) | ✅ |
| `EC2_SSH_KEY` | deploy-backend, deploy-web | PEM private key content | ✅ |
| `KEYSTORE_BASE64` | deploy-mobile | Base64-encoded .jks keystore | ✅ |
| `KEY_STORE_PASSWORD` | deploy-mobile | Keystore store password | ✅ |
| `KEY_PASSWORD` | deploy-mobile | Key password | ✅ |
| `KEY_ALIAS` | deploy-mobile | Key alias | ✅ |
| `GOOGLE_SERVICES_JSON` | deploy-mobile | Firebase config content | ✅ |
| `API_BASE_URL` | deploy-web, deploy-mobile | `https://pyconnect.run.place` | ✅ |
| `RAZORPAY_KEY_ID` | deploy-mobile | Razorpay key ID for mobile | ✅ |

### CI/CD Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci-backend.yml` | PR + push to main (backend changes) | Build + architecture tests |
| `ci-mobile.yml` | PR + push to main (mobile changes) | Flutter static analysis |
| `deploy-backend.yml` | Push to main (backend changes) | Build Docker, push to Docker Hub, deploy to EC2, health check |
| `deploy-web.yml` | Push to main (mobile changes) | Build Flutter web, SCP to EC2, reload Nginx |
| `deploy-mobile.yml` | Tag push `v*` | Build signed APKs + AABs, upload as artifacts |

### Branch Protection (Recommended)

Configure in GitHub repo → Settings → Branches → Branch protection rules for `main`:

1. Require pull request before merging
2. Require status checks: `Backend CI`, `Mobile CI`
3. Require branches to be up to date before merging
4. Require linear history
5. Do NOT require signed commits (unless you set up GPG signing)

### First Push to GitHub — ✅ Completed

```bash
# Already done:
git remote add origin https://github.com/balabm/PyConnect.git
git branch -M main
git push -u origin main
# Result: 618 files pushed, zero secrets tracked
```

### Release Workflow

1. Create a tag: `git tag v1.0.0 && git push origin v1.0.0`
2. `deploy-mobile.yml` triggers automatically
3. Download APKs from GitHub Actions artifacts
4. Upload APKs to Play Store Console

---

## Web App Deployment (Manual)

If you need to deploy web apps manually (outside CI/CD), use these commands:

### Build Web Apps
```powershell
cd mobile

# Admin web app
flutter build web --target lib/main_admin.dart --dart-define=APP_FLAVOR=admin --release

# Save admin build
Copy-Item -Recurse -Force build/web build/web-admin

# Partner web app
flutter build web --target lib/main_partner.dart --dart-define=APP_FLAVOR=partner --release --base-href /partner/

# Save partner build
Copy-Item -Recurse -Force build/web build/web-partner
```

### Deploy to EC2 via SSH/SCP
```bash
PEM=~/path/to/s1bucket.pem
HOST=ubuntu@16.16.120.192

# Deploy Admin
ssh -i $PEM $HOST "sudo rm -rf /tmp/admin-web && mkdir -p /tmp/admin-web"
scp -i $PEM -r mobile/build/web-admin/* $HOST:/tmp/admin-web/
ssh -i $PEM $HOST "sudo rm -rf /var/www/admin/* && sudo cp -r /tmp/admin-web/* /var/www/admin/ && sudo chown -R www-data:www-data /var/www/admin/ && sudo chmod -R a+rX /var/www/admin/ && rm -rf /tmp/admin-web"

# Deploy Partner
ssh -i $PEM $HOST "sudo rm -rf /tmp/partner-web && mkdir -p /tmp/partner-web"
scp -i $PEM -r mobile/build/web-partner/* $HOST:/tmp/partner-web/
ssh -i $PEM $HOST "sudo rm -rf /var/www/partner/* && sudo cp -r /tmp/partner-web/* /var/www/partner/ && sudo chown -R www-data:www-data /var/www/partner/ && sudo chmod -R a+rX /var/www/partner/ && rm -rf /tmp/partner-web"

# Reload Nginx
ssh -i $PEM $HOST "sudo systemctl reload nginx"
```

### Verify
```bash
curl -sf https://pyconnect.run.place/ && echo "Admin OK"
curl -sf https://pyconnect.run.place/partner/ && echo "Partner OK"
```
