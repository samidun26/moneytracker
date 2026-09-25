import { defineConfig, devices } from '@playwright/test'

/**
 * End-to-end tests run against the production build (`vite preview`), the
 * same bundle Vercel serves. Locally they run in Chromium at iPhone and
 * desktop sizes; CI adds WebKit (Safari's engine) at iPhone size.
 */
const CI = !!process.env.CI
const PORT = 4174
// WebAuthn (Face ID) needs a real hostname: IP addresses aren't valid relying-party ids.
const BASE = `http://localhost:${PORT}`

export default defineConfig({
  testDir: 'e2e',
  fullyParallel: true,
  forbidOnly: CI,
  retries: 0,
  workers: CI ? 2 : undefined,
  timeout: 30_000,
  expect: { timeout: 7_000 },
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'reports/e2e.json' }],
  ],
  use: {
    baseURL: BASE,
    locale: 'en-US',
    timezoneId: 'Asia/Jakarta',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    // The service worker would cache the app between tests; offline behaviour gets its own test.
    serviceWorkers: 'block',
  },
  projects: [
    { name: 'iphone', use: { ...devices['iPhone 13'], browserName: 'chromium' } },
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    ...(CI ? [{ name: 'iphone-webkit', use: { ...devices['iPhone 13'] } }] : []),
  ],
  webServer: {
    command: `npm run build && npx vite preview --host localhost --port ${PORT} --strictPort`,
    url: BASE,
    reuseExistingServer: !CI,
    timeout: 180_000,
  },
})
