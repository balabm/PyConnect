import { test, expect } from '../fixtures/auth.fixture';
import { navigateToTab } from '../fixtures/helpers';

test.describe('Food flow', () => {

  test('restaurant list loads with restaurants', async ({ authenticatedPage: page }) => {
    // Navigate to Food tab
    await navigateToTab(page, 'Food');

    // Should see the Food Delivery heading
    await expect(page.getByRole('heading', { name: 'Food Delivery' })).toBeVisible({ timeout: 30_000 });

    // Should see restaurant cards with prices/info in semantic tree
    const restaurantCards = page.locator('flt-semantics[role="group"]');
    await expect(restaurantCards.first()).toBeAttached({ timeout: 30_000 });
  });

  test('restaurant menu loads and checkout works', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Food');
    await expect(page.getByRole('heading', { name: 'Food Delivery' })).toBeVisible({ timeout: 30_000 });

    // Wait for restaurant list to load and tap the first restaurant card
    const restaurantCards = page.locator('flt-semantics[role="group"]');
    await expect(restaurantCards.first()).toBeAttached({ timeout: 30_000 });
    // Find the first card that has a chevron (restaurant card with tap action)
    const tappableCard = restaurantCards.filter({ has: page.locator('[role="button"]') }).first();
    await tappableCard.click({ force: true, timeout: 10_000 });
    await page.waitForTimeout(3000);

    // Should now see menu items with prices
    const menuItems = page.locator('flt-semantics[role="group"][aria-label*="\u20B9"]');
    await expect(menuItems.first()).toBeAttached({ timeout: 30_000 });

    // Click the first add button
    const firstAddBtn = page.locator('flt-semantics[role="group"][aria-label*="\u20B9"] [role="button"]').first();
    await firstAddBtn.click({ force: true, timeout: 10_000 });
    await page.waitForTimeout(1000);

    // Should see checkout bar with "Checkout" button
    await expect(page.getByRole('button', { name: 'Checkout' })).toBeVisible({ timeout: 10_000 });

    // Click checkout
    await page.getByRole('button', { name: 'Checkout' }).click({ force: true, timeout: 10_000 });

    // Should see order confirmation
    await expect(page.getByText('Order Placed!')).toBeAttached({ timeout: 15_000 });
  });
});
