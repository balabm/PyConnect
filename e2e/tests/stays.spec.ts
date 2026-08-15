import { test, expect } from '../fixtures/auth.fixture';
import { navigateToTab } from '../fixtures/helpers';

test.describe('Stays flow', () => {

  test('homestay list loads', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Stays');

    // Should see the Boutique Stays heading and search UI
    await expect(page.getByRole('heading', { name: 'Boutique Stays' })).toBeVisible({ timeout: 30_000 });
    await expect(page.getByText('Check In')).toBeVisible();
    await expect(page.getByText('Check Out')).toBeVisible();
  });

  test('homestay search form visible', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Stays');

    // Should see date pickers and search button
    await expect(page.getByRole('button', { name: /Check In/i })).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('button', { name: /Check Out/i })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Search' })).toBeVisible();
  });
});
