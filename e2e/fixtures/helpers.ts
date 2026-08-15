import { Page, expect, Locator } from '@playwright/test';

export const BACKEND_URL = 'http://localhost:5000';
export const WEB_URL = 'http://localhost:8090';
export const TEST_PHONE = '9000000099';

/**
 * Click a Flutter web semantics element via JS to bypass pointer interception.
 * The Flutter semantics overlay intercepts Playwright's pointer-based clicks.
 */
export async function flutterClick(page: Page, locator: Locator) {
  const elementHandle = await locator.elementHandle();
  if (elementHandle) {
    await elementHandle.click();
  } else {
    await locator.click({ force: true });
  }
}

/**
 * Wait for Flutter web to fully boot and enable the accessibility/semantics layer.
 * Flutter web does not expose the semantic tree until accessibility is enabled.
 * We click the hidden "Enable accessibility" placeholder via JS (it's outside the viewport).
 */
export async function waitForFlutterBoot(page: Page) {
  // Wait for the Flutter canvas/view to be present
  await page.waitForSelector('flutter-view, flt-glass-pane, canvas', { timeout: 90_000 });
  // Give the engine time to render the first frame
  await page.waitForTimeout(3000);
  // Enable semantics via JS — the placeholder button is outside the viewport so normal click fails
  await page.evaluate(() => {
    const el = document.querySelector('flt-semantics-placeholder');
    if (el) (el as HTMLElement).click();
  });
  // Wait for the semantics tree to populate
  await page.waitForTimeout(2000);
}

/**
 * Request OTP through the UI: fill phone field and tap "Get OTP".
 */
export async function requestOtpInUi(page: Page, phone: string) {
  // Find the phone text field by its label
  const phoneField = page.getByRole('textbox', { name: 'Phone number' });
  await phoneField.click({ force: true });
  await page.keyboard.type(phone);
  await page.waitForTimeout(500);

  // Tap the "Get OTP" button
  const getOtpBtn = page.getByRole('button', { name: 'Get OTP' });
  await getOtpBtn.click({ force: true });

  // Wait for navigation to OTP screen
  await page.waitForTimeout(2000);
}

/**
 * Peek at the OTP for a phone number via the dev-only backend endpoint.
 * This re-issues a new OTP and returns it in plaintext.
 */
export async function peekOtp(phone: string): Promise<string> {
  const resp = await fetch(`${BACKEND_URL}/api/auth/otp/peek?phone=${phone}`);
  if (!resp.ok) {
    throw new Error(`OTP peek failed: ${resp.status} ${await resp.text()}`);
  }
  const body = await resp.json() as { phone: string; code: string };
  return body.code;
}

/**
 * Enter OTP in the UI and tap "Verify & Continue".
 * The OTP text field has no label — it's the only textbox on the OTP screen.
 */
export async function verifyOtpInUi(page: Page, code: string) {
  // The OTP textbox is unlabeled — use the textbox role (only one on this screen)
  const otpField = page.getByRole('textbox');
  await otpField.click({ force: true });
  await page.keyboard.type(code);
  await page.waitForTimeout(500);

  // Tap "Verify & Continue"
  const verifyBtn = page.getByRole('button', { name: 'Verify & Continue' });
  await verifyBtn.click({ force: true });

  // Wait for navigation to home
  await page.waitForTimeout(3000);
}

/**
 * Authenticate via API and inject the token into the Flutter web app's secure storage.
 * FlutterSecureStorage on web encrypts values, so we can't just set localStorage directly.
 * Instead, we authenticate via API, get the JWT, and use a custom approach:
 * we navigate to the app, use the UI auth flow once, then reuse the browser context.
 *
 * For tests that need auth, use the `authenticatedPage` fixture which shares a single
 * browser context that has already been authenticated.
 */

/**
 * Full authentication flow: navigate to /auth → request OTP in UI → peek OTP from backend → verify in UI.
 * After this, the app should be on the home screen.
 * Uses keyboard.type() instead of fill() to properly trigger Flutter's onChanged.
 */
export async function authenticate(page: Page, phone: string = TEST_PHONE) {
  await waitForFlutterBoot(page);

  // Navigate to the auth screen (the app does not gate / by default)
  await page.goto(`${WEB_URL}/#/auth`);
  await page.waitForTimeout(2000);

  // We should be on the phone entry screen now
  await requestOtpInUi(page, phone);

  // Peek the OTP (this supersedes the one from requestOtp)
  const code = await peekOtp(phone);

  // Enter and verify
  await verifyOtpInUi(page, code);

  // Wait for home screen — look for bottom nav labels
  await expect(page.getByRole('tab', { name: 'Vibe' })).toBeVisible({ timeout: 30_000 });
}

/**
 * Navigate to a tab by tapping the bottom navigation bar.
 * Flutter web's semantics overlay intercepts pointer events, so we use JS click.
 */
export async function navigateToTab(page: Page, label: string) {
  const tab = page.getByRole('tab', { name: label });
  await tab.click({ force: true, timeout: 10_000 });
  await page.waitForTimeout(2000);
}

/**
 * Make a direct API call to the backend (for setup/assertions).
 */
export async function apiGet(path: string, token?: string): Promise<any> {
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const resp = await fetch(`${BACKEND_URL}${path}`, { headers });
  if (!resp.ok) throw new Error(`API GET ${path} failed: ${resp.status}`);
  return resp.json();
}

/**
 * Make a direct API POST to the backend.
 */
export async function apiPost(path: string, body: any, token?: string): Promise<any> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const resp = await fetch(`${BACKEND_URL}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  if (!resp.ok) throw new Error(`API POST ${path} failed: ${resp.status} ${await resp.text()}`);
  return resp.json();
}

/**
 * Authenticate via API directly and return the access token.
 * Useful for API-level setup in UI tests.
 */
export async function getAuthToken(phone: string = TEST_PHONE): Promise<string> {
  // Request OTP
  await apiPost('/api/auth/otp/request', { phone });
  // Peek OTP
  const code = await peekOtp(phone);
  // Verify
  const result = await apiPost('/api/auth/otp/verify', { phone, otp: code });
  return result.accessToken;
}

/**
 * Inject an auth token into the Flutter web app's localStorage.
 * FlutterSecureStorage on web stores encrypted values, but we can bypass
 * by writing the encrypted form. Instead, we use a simpler approach:
 * we copy the entire localStorage from an already-authenticated session.
 *
 * This function copies auth-related localStorage keys from a shared storage state.
 */
export async function injectAuthState(page: Page, storageState: Record<string, string>) {
  await page.goto(`${WEB_URL}/#/`);
  await page.waitForTimeout(1000);
  for (const [key, value] of Object.entries(storageState)) {
    await page.evaluate(({ k, v }) => localStorage.setItem(k, v), { k: key, v: value });
  }
  // Reload to pick up the token
  await page.reload();
  await waitForFlutterBoot(page);
}

/**
 * Capture the auth-related localStorage from the current page (post-authentication).
 */
export async function captureAuthState(page: Page): Promise<Record<string, string>> {
  const state = await page.evaluate(() => {
    const result: Record<string, string> = {};
    for (const k of Object.keys(localStorage)) {
      if (k.includes('FlutterSecureStorage')) {
        result[k] = localStorage.getItem(k) || '';
      }
    }
    return result;
  });
  return state;
}
