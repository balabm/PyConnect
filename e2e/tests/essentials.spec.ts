import { test, expect } from '../fixtures/auth.fixture';
import { navigateToTab } from '../fixtures/helpers';

test.describe('Essentials flow', () => {

  test('essentials store list loads', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Shop');

    // Should see the Essentials heading and product items with prices
    await expect(page.getByRole('heading', { name: 'Essentials' })).toBeVisible({ timeout: 30_000 });
    // Essentials screen has prices in textContent (unlike food which uses aria-label)
    const products = page.getByText(/₹\d+/);
    await expect(products.first()).toBeVisible({ timeout: 30_000 });
  });

  test('essentials search and categories visible', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Shop');

    // Should see search box and category filter chips
    await expect(page.getByRole('textbox', { name: 'Search products...' })).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('checkbox', { name: 'All' })).toBeVisible();
    await expect(page.getByRole('checkbox', { name: 'Hydration' })).toBeVisible();
  });
});
