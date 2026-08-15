import { test, expect } from '../fixtures/auth.fixture';
import { navigateToTab } from '../fixtures/helpers';

test.describe('Rides flow', () => {

  test('ride hailing screen loads', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Ride');

    // Should see the Ride heading, Pickup/Dropoff fields, and Request Ride button
    await expect(page.getByRole('heading', { name: 'Ride' })).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('textbox', { name: 'Pickup' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Dropoff' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Request Ride' })).toBeVisible();
  });

  test('ride vehicle selection visible', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Ride');

    // Should see vehicle options (Bike, Auto, Car) with prices
    // Flutter semantics: text is in textContent with newlines between label and price
    await expect(page.getByText('Select Vehicle')).toBeVisible({ timeout: 30_000 });
    await expect(page.getByText(/Bike[\s\S]*₹/)).toBeVisible();
    await expect(page.getByText(/Auto[\s\S]*₹/)).toBeVisible();
    await expect(page.getByText(/Car[\s\S]*₹/)).toBeVisible();
  });
});
