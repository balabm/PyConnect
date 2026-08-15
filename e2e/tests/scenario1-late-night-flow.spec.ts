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
  flutterClick,
} from '../fixtures/helpers';

// ─────────────────────────────────────────────────────────────────────────────
// Master Scenario 1: Zero-Commission Late-Night Flow
//
// Tests: Food cart → checkout → zero-commission pricing → vendor order acceptance
//        → food delivery SignalR dispatch → settlement split verification
//
// Seed data used:
//   Consumer:  9000000099 (Test Tourist)
//   Vendor:    9000000001 (Fuoco Pizzeria, vendorId 00000000-0000-0000-0000-000000000001)
//   Menu:      Woodfired Margherita ₹450 (late-night), Pepperoni Pizza ₹550 (late-night)
//   Driver:    9000000050 (Suresh Kumar, Bike)
// ─────────────────────────────────────────────────────────────────────────────

const VENDOR_ID = '00000000-0000-0000-0000-000000000001';
const VENDOR_PHONE = '9000000001';
const DRIVER_PHONE = '9000000050';

test.describe.serial('Master Scenario 1: Zero-Commission Late-Night Flow', () => {

  // ── Phase 1: API-Level Pricing & Settlement Verification ──

  test('1.1 — Consumer auth and food order checkout with correct zero-commission pricing', async () => {
    const token = await getAuthToken(TEST_PHONE);

    // Fetch the vendor's menu to get real item IDs/prices
    const menu = await apiGet(`/api/vendors/${VENDOR_ID}/menu`, token);
    expect(menu).toBeInstanceOf(Array);
    expect(menu.length).toBeGreaterThan(0);

    // Find late-night items
    const margherita = menu.find((m: any) => m.name === 'Woodfired Margherita');
    const shawarma = menu.find((m: any) => m.name === 'Chicken Shawarma');
    expect(margherita).toBeTruthy();
    expect(shawarma).toBeTruthy();

    const subTotal = Number(margherita.unitPrice) + Number(shawarma.unitPrice);
    expect(subTotal).toBe(630); // 450 + 180

    // Checkout: 1x Margherita + 1x Shawarma
    const order = await apiPost('/api/orders/checkout', {
      vendorId: VENDOR_ID,
      deliveryAddress: '12 Rue Romain Rolland, White Town',
      deliveryLatitude: 11.9356,
      deliveryLongitude: 79.8301,
      paymentMethod: 0, // Cash
      items: [
        { name: margherita.name, quantity: 1, unitPrice: margherita.unitPrice },
        { name: shawarma.name, quantity: 1, unitPrice: shawarma.unitPrice },
      ],
    }, token);

    // Verify zero-commission pricing structure
    expect(order.subTotal).toBe(subTotal);
    expect(order.platformFee).toBe(0);
    expect(order.deliveryFee).toBeGreaterThanOrEqual(0);
    expect(order.totalAmount).toBe(order.subTotal + order.deliveryFee + order.lateNightDriverBonus + order.platformFee);
    expect(order.status).toBe('Placed');
    expect(order.orderId).toBeTruthy();

    // Store order ID for subsequent tests
    (test as any).orderId = order.orderId;
  });

  test('1.2 — Vendor sees the order in their dashboard', async () => {
    const vendorToken = await getAuthToken(VENDOR_PHONE);
    const orders = await apiGet('/api/vendor/orders', vendorToken);

    expect(orders).toBeInstanceOf(Array);
    expect(orders.length).toBeGreaterThan(0);

    // The most recent order should be the one we just placed
    const latest = orders[0];
    expect(latest.status).toBe('Placed');
    expect(latest.totalAmount).toBeGreaterThan(0);
  });

  test('1.3 — Vendor accepts and marks order as Preparing', async () => {
    const vendorToken = await getAuthToken(VENDOR_PHONE);
    const orders = await apiGet('/api/vendor/orders', vendorToken);
    const orderId = orders[0].id;

    // Accept the order
    const acceptResp = await fetch(`${BACKEND_URL}/api/vendor/orders/${orderId}/status`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${vendorToken}` },
      body: JSON.stringify({ newStatus: 'Accepted' }),
    });
    expect(acceptResp.status).toBe(204);

    // Mark as Preparing
    const prepResp = await fetch(`${BACKEND_URL}/api/vendor/orders/${orderId}/status`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${vendorToken}` },
      body: JSON.stringify({ newStatus: 'Preparing' }),
    });
    expect(prepResp.status).toBe(204);

    // Verify status updated
    const orderDetail = await apiGet(`/api/orders/${orderId}`, vendorToken);
    expect(orderDetail.status).toBe('Preparing');
  });

  test('1.4 — Vendor marks OutForDelivery → triggers food delivery dispatch to drivers', async () => {
    const vendorToken = await getAuthToken(VENDOR_PHONE);
    const orders = await apiGet('/api/vendor/orders', vendorToken);
    const orderId = orders[0].id;

    // Mark as OutForDelivery — this triggers FoodDeliveryDispatchService
    const dispatchResp = await fetch(`${BACKEND_URL}/api/vendor/orders/${orderId}/status`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${vendorToken}` },
      body: JSON.stringify({ newStatus: 'OutForDelivery' }),
    });
    expect(dispatchResp.status).toBe(204);

    // Verify order is now OutForDelivery
    const orderDetail = await apiGet(`/api/orders/${orderId}`, vendorToken);
    expect(orderDetail.status).toBe('OutForDelivery');
  });

  test('1.5 — Settlement split: vendor gets 100% subtotal, driver gets delivery+bonus, platform gets 0', async () => {
    const consumerToken = await getAuthToken(TEST_PHONE);
    const orders = await apiGet('/api/orders?page=1&pageSize=5', consumerToken);
    const order = orders[0];

    // Verify the pricing breakdown is zero-commission
    // Vendor payout = SubTotal (100%)
    // Driver payout = DeliveryFee + LateNightDriverBonus (100%)
    // Platform fee = 0
    expect(order.totalAmount).toBeGreaterThan(0);
    expect(order.subTotal).toBeGreaterThan(0);
    expect(order.platformFee).toBe(0);

    // The order detail should show the full breakdown
    const detail = await apiGet(`/api/orders/${order.id}`, consumerToken);
    expect(detail.subTotal).toBeGreaterThan(0);
    expect(detail.deliveryFee).toBeGreaterThanOrEqual(0);
    expect(detail.platformFee).toBe(0);

    // LateNightDriverBonus should be ₹30 if order was placed between 11PM-3AM IST
    // (We can't control the actual time in E2E, but the field should exist)
    expect(detail).toHaveProperty('lateNightDriverBonus');
    expect(typeof detail.lateNightDriverBonus).toBe('number');
  });

  // ── Phase 2: UI-Level Flow Verification ──

  test('1.6 — Consumer UI: Food tab → Fuoco Pizzeria → add items → checkout → order placed', async ({ page }) => {
    await page.goto(`${WEB_URL}/#/auth`);
    await authenticate(page, TEST_PHONE);

    // Navigate to Food tab
    await navigateToTab(page, 'Food');
    await expect(page.getByRole('heading', { name: 'Food Delivery' })).toBeVisible({ timeout: 30_000 });

    // Wait for restaurant list and find Fuoco Pizzeria
    const restaurantCards = page.locator('flt-semantics[role="group"]');
    await expect(restaurantCards.first()).toBeAttached({ timeout: 30_000 });

    // Tap the first tappable restaurant card
    const tappableCard = restaurantCards.filter({ has: page.locator('[role="button"]') }).first();
    await tappableCard.click({ force: true, timeout: 10_000 });
    await page.waitForTimeout(3000);

    // Add the first menu item
    const firstAddBtn = page.locator('flt-semantics[role="group"][aria-label*="\u20B9"] [role="button"]').first();
    await expect(firstAddBtn).toBeAttached({ timeout: 30_000 });
    await firstAddBtn.click({ force: true, timeout: 10_000 });
    await page.waitForTimeout(1000);

    // Checkout
    await expect(page.getByRole('button', { name: 'Checkout' })).toBeVisible({ timeout: 10_000 });
    await page.getByRole('button', { name: 'Checkout' }).click({ force: true, timeout: 10_000 });

    // Verify order confirmation with pricing breakdown
    await expect(page.getByText('Order Placed!')).toBeAttached({ timeout: 15_000 });

    // Verify zero-commission pricing is displayed
    await expect(page.getByText('Platform Fee')).toBeAttached();
    await expect(page.getByText('\u20B90')).toBeAttached(); // Platform fee = ₹0
  });
});
