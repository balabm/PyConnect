import { test, expect } from '../fixtures/auth.fixture';
import { navigateToTab } from '../fixtures/helpers';

test.describe('Transit flow', () => {

  test('transit screen loads with tabs', async ({ authenticatedPage: page }) => {
    await navigateToTab(page, 'Transit');

    // Should see the transit heading and sub-tabs
    await expect(page.getByRole('heading', { name: 'Arrival to Departure' })).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('tab', { name: 'Pickups' })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Luggage' })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Mobility' })).toBeVisible();
  });
});
