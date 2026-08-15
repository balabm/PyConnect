import { defineConfig, devices } from '@playwright/test';

const BACKEND_URL = 'http://localhost:5000';
const WEB_URL = 'http://localhost:8090';
const PROJECT_ROOT = '..';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 1,
  workers: 1,
  reporter: 'list',
  timeout: 120_000,
  expect: { timeout: 30_000 },
  use: {
    baseURL: WEB_URL,
    trace: 'on-first-retry',
    actionTimeout: 30_000,
    navigationTimeout: 60_000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: [
    {
      command: `dotnet run --project ${PROJECT_ROOT}/backend/src/PondyConnect.Api --no-build`,
      url: `${BACKEND_URL}/health`,
      timeout: 60_000,
      reuseExistingServer: true,
      stdout: 'pipe',
      stderr: 'pipe',
    },
    {
      command: `npx http-server ${PROJECT_ROOT}/mobile/build/web -p 8090 --cors -c-1`,
      url: WEB_URL,
      timeout: 30_000,
      reuseExistingServer: true,
      stdout: 'pipe',
      stderr: 'pipe',
    },
  ],
});
