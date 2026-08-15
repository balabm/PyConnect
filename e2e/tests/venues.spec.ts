import { test, expect } from '../fixtures/auth.fixture';
import { navigateToTab } from '../fixtures/helpers';

test.describe('Venues flow', () => {

  test('venue list loads with search and filter chips', async ({ authenticatedPage: page }) => {
    // Should see search box and category filter chips
    await expect(page.getByRole('textbox', { name: 'Search venues...' })).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('checkbox', { name: 'All' })).toBeVisible();
    await expect(page.getByRole('checkbox', { name: 'Bar' })).toBeVisible();
  });

  test('venue search filters results', async ({ authenticatedPage: page }) => {
    const searchField = page.getByRole('textbox', { name: 'Search venues...' });
    await expect(searchField).toBeVisible({ timeout: 30_000 });

    // Type a non-existent venue name — use keyboard.type to trigger Flutter onChanged
    await searchField.click({ force: true });
    await page.keyboard.type('zzzznonexistent');
    await page.waitForTimeout(3000);

    // Should see empty state text or no venue cards
    // Flutter semantics: text elements without role have text in textContent
    const emptyState = page.getByText('No venues found');
    const openBadges = page.getByText(/^Open$/);
    const closedBadges = page.getByText(/^Closed$/);
    // Either the empty state is shown, or no venue badges are visible
    const isEmpty = await emptyState.count().catch(() => 0);
    const openCount = await openBadges.count().catch(() => 0);
    const closedCount = await closedBadges.count().catch(() => 0);
    expect(isEmpty > 0 || (openCount === 0 && closedCount === 0)).toBeTruthy();
  });

  test('venue category filter works', async ({ authenticatedPage: page }) => {
    await expect(page.getByRole('textbox', { name: 'Search venues...' })).toBeVisible({ timeout: 30_000 });

    // Click the "Bar" filter chip via JS (Flutter intercepts pointer events)
    await page.evaluate(() => {
      const chips = document.querySelectorAll('[role="checkbox"]');
      for (const c of chips) {
        if (c.getAttribute('aria-label') === 'Bar') { (c as HTMLElement).click(); return; }
      }
    });
    await page.waitForTimeout(2000);

    // The "All" chip should no longer be checked
    await expect(page.getByRole('checkbox', { name: 'All' })).not.toBeChecked();
  });
});
