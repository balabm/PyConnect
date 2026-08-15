import { test as base, expect, Page } from '@playwright/test';
import { authenticate, captureAuthState, injectAuthState, WEB_URL, TEST_PHONE } from './helpers';

type AuthFixtures = {
  authenticatedPage: Page;
};

/**
 * Extended test fixture that provides an `authenticatedPage` fixture.
 * The first test to use it authenticates via the UI; subsequent tests
 * reuse the captured localStorage state to skip the OTP flow.
 */
let sharedAuthState: Record<string, string> | null = null;

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    if (sharedAuthState) {
      // Reuse cached auth state
      await page.goto(`${WEB_URL}/#/`);
      await injectAuthState(page, sharedAuthState);
    } else {
      // First time: authenticate via UI
      await page.goto(`${WEB_URL}/#/auth`);
      await authenticate(page, TEST_PHONE);
      sharedAuthState = await captureAuthState(page);
    }
    await use(page);
  },
});

export { expect };
