import { test, expect } from '@playwright/test';
import { waitForFlutterBoot, requestOtpInUi, peekOtp, verifyOtpInUi, authenticate, TEST_PHONE, WEB_URL } from '../fixtures/helpers';

test.describe('Auth flow', () => {
  test('phone entry screen renders with title and button', async ({ page }) => {
    await page.goto(`${WEB_URL}/#/auth`);
    await waitForFlutterBoot(page);

    // Flutter semantics use aria-label, not textContent
    await expect(page.getByText('PondyConnect')).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('textbox', { name: 'Phone number' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Get OTP' })).toBeVisible();
  });

  test('full auth flow: phone → OTP → authenticated home', async ({ page }) => {
    await page.goto(`${WEB_URL}/#/auth`);
    await authenticate(page, TEST_PHONE);

    // Should be on home screen with bottom nav tabs
    await expect(page.getByRole('tab', { name: 'Vibe' })).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('tab', { name: 'Food' })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Stays' })).toBeVisible();
  });

  test('invalid OTP shows error message', async ({ page }) => {
    await page.goto(`${WEB_URL}/#/auth`);
    await waitForFlutterBoot(page);

    await requestOtpInUi(page, TEST_PHONE);

    // Enter a wrong OTP — use type() instead of fill() to trigger Flutter's onChanged
    const otpField = page.getByRole('textbox');
    await otpField.click({ force: true });
    await page.keyboard.type('000000');
    await page.waitForTimeout(500);

    const verifyBtn = page.getByRole('button', { name: 'Verify & Continue' });
    await verifyBtn.click({ force: true });

    // Flutter semantics: error text appears in textContent of a generic element
    // The backend returns 401 which DioException surfaces — the friendly error handler
    // may not catch all variants, so match on common error indicators
    await expect(page.getByText(/401|DioException|invalid|expired|Could not|bad response/i)).toBeAttached({ timeout: 20_000 });
  });
});
