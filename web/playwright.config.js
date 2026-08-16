import { defineConfig, devices } from '@playwright/test';

/**
 * The FR-15 copy suite runs against the BUILT STATIC EXPORT, not the dev server.
 * The requirement is about what a user is actually served, so the artifact under
 * test is the artifact that ships.
 *
 * No RPC is configured for this run, and that is deliberate: it puts every live
 * read into its failure path, which is exactly the state Task 6.8's
 * data-unavailable requirements describe. The copy requirements must hold in the
 * degraded state too — a surface that only tells the truth when the chain is
 * reachable is not a truth surface.
 */
export default defineConfig({
  testDir: './tests',
  // Only the browser copy suite. `tests/units.test.mjs` is a `node --test` suite
  // (run by `npm run test:units`) and must not be collected here — Playwright
  // would load it, `node:test` would register a second runner, and the run hangs.
  testMatch: '**/*.spec.js',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: process.env.CI ? 'list' : [['list']],
  use: {
    baseURL: `http://127.0.0.1:${process.env.PORT ?? 4321}`,
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'node scripts/serve-static.mjs',
    url: `http://127.0.0.1:${process.env.PORT ?? 4321}`,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
