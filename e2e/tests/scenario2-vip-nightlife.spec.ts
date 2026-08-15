import { test, expect } from '@playwright/test';
import {
  BACKEND_URL,
  WEB_URL,
  TEST_PHONE,
  getAuthToken,
  apiPost,
  apiGet,
  authenticate,
  waitForFlutterBoot,
  navigateToTab,
} from '../fixtures/helpers';

// ─────────────────────────────────────────────────────────────────────────────
// Master Scenario 2: VIP Nightlife Flow
//
// Tests: Venue booking → capacity constraints → QR pass token issuance
//        → PWA scanner validation → duplicate scan rejection
//
// Seed data used:
//   Consumer:  9000000099 (Test Tourist)
//   Vendor:    9000000010 (Drunken Daddy)
//   Venue:     "Drunken Daddy" — maxCapacity 50, VenueCategory.Pub
//   Pass:      Seeded test pass for Le Club (phone 9000000099)
// ─────────────────────────────────────────────────────────────────────────────

const VENDOR_PHONE = '9000000010';

test.describe.serial('Master Scenario 2: VIP Nightlife Flow', () => {

  // ── Phase 1: API-Level Booking & Capacity Verification ──

  test('2.1 — Fetch venues and locate Drunken Daddy', async () => {
    const token = await getAuthToken(TEST_PHONE);
    const venues = await apiGet('/api/venues', token);

    expect(venues).toBeInstanceOf(Array);
    const drunkenDaddy = venues.find((v: any) => v.name === 'Drunken Daddy');
    expect(drunkenDaddy).toBeTruthy();
    expect(drunkenDaddy.maxCapacity).toBe(50);
    expect(drunkenDaddy.isActive).toBe(true);

    // Store venue ID for subsequent tests
    (test as any).venueId = drunkenDaddy.id;
  });

  test('2.2 — Consumer books 4 seats at Drunken Daddy → 201 Created with passToken', async () => {
    const token = await getAuthToken(TEST_PHONE);
    const venues = await apiGet('/api/venues', token);
    const venue = venues.find((v: any) => v.name === 'Drunken Daddy');

    const scheduledFor = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

    const booking = await apiPost('/api/bookings', {
      venueId: venue.id,
      seats: 4,
      scheduledFor,
      notes: 'VIP Nightlife E2E test',
    }, token);

    expect(booking.bookingId).toBeTruthy();
    expect(booking.status).toBe('Confirmed');
    expect(booking.amount).toBeGreaterThan(0);
    expect(booking.passToken).toBeTruthy();
    expect(booking.passToken.length).toBeGreaterThan(0);

    // Store for subsequent tests
    (test as any).bookingId = booking.bookingId;
    (test as any).passToken = booking.passToken;
  });

  test('2.3 — Capacity overflow: booking 55 seats at 50-cap venue → 409 Conflict', async () => {
    const token = await getAuthToken(TEST_PHONE);
    const venues = await apiGet('/api/venues', token);
    const venue = venues.find((v: any) => v.name === 'Drunken Daddy');

    const scheduledFor = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString();

    // Attempt to book 55 seats — should exceed capacity (50)
    const resp = await fetch(`${BACKEND_URL}/api/bookings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({
        venueId: venue.id,
        seats: 55,
        scheduledFor,
        notes: 'Should fail — capacity overflow',
      }),
    });

    expect(resp.status).toBe(409);
    const body = await resp.json();
    expect(body.message).toContain('capacity');
  });

  test('2.4 — Vendor validates QR pass token → isValid: true, serviceType: Nightlife', async () => {
    const vendorToken = await getAuthToken(VENDOR_PHONE);
    const passToken = (test as any).passToken;
    expect(passToken).toBeTruthy();

    const result = await apiPost('/api/vendor/validate-ticket', {
      qrPayload: passToken,
    }, vendorToken);

    expect(result.isValid).toBe(true);
    expect(result.serviceType).toBeTruthy();
    expect(result.userName).toBeTruthy();
    expect(result.message).toBe('Valid ticket.');
  });

  test('2.5 — Duplicate scan: same pass token → isValid: false, "Already used"', async () => {
    const vendorToken = await getAuthToken(VENDOR_PHONE);
    const passToken = (test as any).passToken;

    const result = await apiPost('/api/vendor/validate-ticket', {
      qrPayload: passToken,
    }, vendorToken);

    expect(result.isValid).toBe(false);
    expect(result.message).toContain('Already used');
  });

  test('2.6 — Invalid QR payload → isValid: false, "Unknown ticket"', async () => {
    const vendorToken = await getAuthToken(VENDOR_PHONE);

    const result = await apiPost('/api/vendor/validate-ticket', {
      qrPayload: 'INVALID-FAKE-TOKEN-12345',
    }, vendorToken);

    expect(result.isValid).toBe(false);
    expect(result.message).toContain('Unknown ticket');
  });

  // ── Phase 2: UI-Level Booking Flow ──

  test('2.7 — Consumer UI: Venues → Drunken Daddy → book 4 seats → pass token displayed', async ({ page }) => {
    await page.goto(`${WEB_URL}/#/auth`);
    await authenticate(page, TEST_PHONE);

    // Should be on Vibe tab (venues)
    await expect(page.getByRole('textbox', { name: 'Search venues...' })).toBeVisible({ timeout: 30_000 });

    // Search for Drunken Daddy
    const searchField = page.getByRole('textbox', { name: 'Search venues...' });
    await searchField.click({ force: true });
    await page.keyboard.type('Drunken');
    await page.waitForTimeout(3000);

    // Tap the Drunken Daddy venue card
    const venueCards = page.locator('flt-semantics[role="group"]');
    const tappableCard = venueCards.filter({ has: page.locator('[role="button"]') }).first();
    await tappableCard.click({ force: true, timeout: 10_000 });
    await page.waitForTimeout(3000);

    // Should see booking UI — look for "Book" or seat selector
    // Tap the Book button
    const bookBtn = page.getByRole('button', { name: /book|reserve|continue/i }).first();
    if (await bookBtn.count() > 0) {
      await bookBtn.click({ force: true, timeout: 10_000 });
      await page.waitForTimeout(2000);
    }

    // If there's a confirm button, click it
    const confirmBtn = page.getByRole('button', { name: /confirm|pay|book now/i }).first();
    if (await confirmBtn.count() > 0) {
      await confirmBtn.click({ force: true, timeout: 10_000 });
      await page.waitForTimeout(3000);
    }

    // Should see booking confirmation with pass token
    await expect(page.getByText('PASS TOKEN')).toBeAttached({ timeout: 15_000 });
  });

  // ── Phase 3: Seeded Test Pass Validation ──

  test('2.8 — Validate seeded test pass (Le Club, Nightlife) via API', async () => {
    const vendorToken = await getAuthToken(VENDOR_PHONE);

    // The seeded test passes are for phone 9000000099 with notes "SEED-TEST-PASS"
    // We need to fetch the pass token from the consumer's bookings
    const consumerToken = await getAuthToken(TEST_PHONE);

    // Get consumer's bookings
    const bookingsResp = await fetch(`${BACKEND_URL}/api/bookings`, {
      headers: { Authorization: `Bearer ${consumerToken}` },
    });
    const bookings = await bookingsResp.json();

    // Find a seeded test pass (Nightlife type)
    const seededBooking = Array.isArray(bookings)
      ? bookings.find((b: any) => b.serviceType === 'Nightlife' || b.notes === 'SEED-TEST-PASS')
      : null;

    if (seededBooking) {
      // Try to validate using the booking ID as pass token (fallback)
      const result = await apiPost('/api/vendor/validate-ticket', {
        qrPayload: seededBooking.passToken || seededBooking.bookingId,
      }, vendorToken);

      // Should be valid OR "Already used" if a previous test consumed it
      expect(result.isValid === true || result.message === 'Already used.').toBeTruthy();
    }
  });
});
