---
name: build-time-env-inlining-hides-branches-from-review
description: |
  A static-export frontend (Next.js `output: 'export'`, or any bundler that
  inlines public env vars) reads deployment config through `NEXT_PUBLIC_*`-style
  variables. Those values are baked into the JS bundle AT BUILD TIME, not read at
  runtime. A test artifact built with that config empty/unset can NEVER render the
  "data available" branches of the UI, no matter how thoroughly the test mocks
  runtime behavior (route interception, injected wallet providers, fake timers) —
  the code path was compiled out. Apply when reviewing frontend code gated by
  build-time env in a static-export app, especially when the existing test suite
  was built once with degraded/unavailable config. Provides the two-build review
  technique and the exact defect it caught.
loa-agent: reviewing-code
extracted-from: sprint-6 (VUX v1 Truth Surfaces), M-4 discovery during remediation re-review
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - nextjs
  - static-export
  - test-coverage
  - code-review
  - frontend
---

## Problem

Sprint-6's frontend deliberately runs its entire Playwright copy suite with no
RPC configured, on purpose: it puts every live read into its failure path so the
truthfulness-under-failure requirements are asserted. That choice is correct for
its stated purpose and it is also, silently, a coverage ceiling. `web/lib/protocol.js`
reads `RPC_URL = process.env.NEXT_PUBLIC_RPC_URL ?? ''`, and `client()` returns
`null` whenever `RPC_URL` is falsy. Next's static export inlines that value when
`next build` runs — the compiled bundle shipped to the browser has the literal
empty string baked in, and `client()` returns `null` unconditionally in that
build, forever, regardless of what `page.route()` or an injected `window.ethereum`
does at test time. A component whose only defect lives in the "price is
available" branch (`TakeFlow`'s frozen `maxPrice` guard, M-4) was invisible to
every test that ran against that build, across two full review passes, because
the branch was never compiled in.

## Trigger Conditions

### Symptoms

- Reviewing a Next.js (or similar SSG/static-export) app where config comes
  through `NEXT_PUBLIC_*` / build-time-inlined environment variables
- The only compiled test artifact was built with those values empty, unset, or
  pointed at an intentionally unreachable host
- The finding, bug, or requirement under review concerns "live," "connected,"
  "available," or "success-path" UI behavior
- Existing tests mock runtime I/O (network routes, wallet providers) but the
  suite's assertions never actually observe the mocked data rendering

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Next.js `output: 'export'`, or any bundler/framework inlining public env at build time (Vite `import.meta.env`, CRA `REACT_APP_*`) |
| Environment | static export / no server-side runtime config |
| Timing | reviewing frontend transaction flows, live-data rendering, or "available" states |
| Prerequisites | the app has at least one env-gated branch distinguishing available vs. unavailable data |

## Root Cause

Build-time inlining and runtime mocking operate at different layers, and it is
easy to conflate them. `page.route()` intercepts HTTP requests the running page
actually makes; it cannot change which branch of `if (!RPC_URL) return null` the
bundler compiled into the shipped JS, because that decision was made and frozen
before the test ever launches a browser. A reviewer (or implementer) who confirms
"the mock returns the right JSON" has verified the wrong layer — the question that
matters is whether the compiled bundle's env-gated branch even reaches the code
that would consume that JSON.

## Solution

### Step 1: Identify every build-time-inlined config value the component depends on

Grep for the framework's public-env prefix and trace what each gates:

```bash
grep -rn "NEXT_PUBLIC_" web/lib web/app web/components
```

### Step 2: Confirm what the existing test build actually compiled in

```bash
grep -rlo "<the unavailable host / empty value>" web/out/_next/static/chunks/ 2>/dev/null
```

If the degraded value is present in the shipped bundle, every test run against
that `out/` directory is structurally incapable of exercising the "available"
branch — regardless of assertion count or pass rate.

### Step 3: Produce a second build with placeholder-but-truthy values

Point the config at a host that is reachable in shape (a URL, not empty) but
either deliberately unroutable (so degraded-state tests still get instant,
deterministic failure) or interceptable by the test framework:

```js
// scripts/build-with-test-env.mjs — spawns `next build` with a scoped child env;
// NEVER writes to process.env or disk, so an ordinary `npm run build` is unaffected
const TEST_ENV = {
  NEXT_PUBLIC_RPC_URL: 'http://127.0.0.1:1/rpc',   // browser refuses instantly if unmocked
  NEXT_PUBLIC_LENS_ADDRESS: '0x…f0001',              // obviously synthetic placeholder
};
spawn(nextBin, ['build'], { env: { ...process.env, ...TEST_ENV } });
```

### Step 4: Drive the SAME assertions against both builds, for both purposes

Keep the original degraded build's suite for the failure-path requirements it
was designed for. Add a suite against the new build for the available-path
requirements, intercepting the now-reachable-in-shape endpoint:

```js
await page.route('**/rpc', (route) => route.fulfill({ /* live-looking response */ }));
```

Do not disable polling or suppress re-renders to force the test through — a real
interval landing a real state update is what proves the UI tracks live data
rather than a mock artifact of the test itself. In this session that discipline
is what surfaced M-4: with polling left on, a second poll delivering a different
price exposed that the displayed guard was frozen from the first render.

### Step 5: Re-examine the ORIGINAL degraded-path tests under the new build too

Standing up a build with real config can retroactively reveal that
degraded-state assertions were passing for the wrong reason — in this session,
two FB-17 tests had never actually attempted a read (client() returned null
before any fetch), so their "unavailable" assertion was vacuously true. Confirm
those tests still pass when a read genuinely IS attempted and fails.

## Verification

### Command

```bash
node scripts/build-with-test-env.mjs && npx playwright test <available-path-suite>
```

### Expected Output

The available-path suite renders a live value from the mocked route and the
degraded-path suite still shows the unavailable state when the route is aborted
rather than fulfilled — both against builds where a real read is genuinely
attempted, not compiled out.

### Checklist

- [ ] Every `NEXT_PUBLIC_*` (or equivalent) dependency identified
- [ ] Confirmed the existing test build's shipped bundle contains the degraded value
- [ ] A second build compiled with placeholder-but-truthy config
- [ ] Test-only build script never mutates `process.env` or disk — production `build` unaffected
- [ ] Available-path assertions run against the second build with mocked I/O
- [ ] Polling/re-render is NOT disabled to force a pass — a real update must drive the transition
- [ ] Degraded-path tests re-verified under the new build to confirm they attempt (and fail) a real read

## Anti-Patterns

### Don't: treat "the mock returns the right data" as proof the UI renders it

The mock answering correctly says nothing if the compiled branch that would
consume the answer was never included in the artifact under test.

### Don't: approve a wallet/live-data flow as reviewed when only the degraded build was ever exercised

If the entire suite structurally cannot reach the "available" branch, "review
passed" and "the available branch was never observed" are the same fact stated
two different ways.

### Don't: disable polling to make a price-update or live-refresh test deterministic

Suppressing the mechanism under test to make the test pass proves the assertion
can be satisfied without the behavior it claims to verify.

## Related Memory

### Related Skills

- `a-passing-regression-test-proves-nothing-alone` — the mutation-testing
  technique used to confirm the second build's suite genuinely discriminates the
  defect it was built to catch
- `truth-labels-outlive-their-data` — a sibling truthfulness-under-degraded-data
  finding from the same sprint's implementation pass

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-14 | Initial extraction |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: reviewing-code
  phase: /review-sprint
  session: sprint-6 remediation re-review (pass 2, M-4 finding)
```
