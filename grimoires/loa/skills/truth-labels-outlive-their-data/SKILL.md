---
name: truth-labels-outlive-their-data
description: |
  A required label, unit, qualifier or column name gets rendered inside the same
  conditional as its value, so when the data source fails the naming requirement
  silently disappears — in exactly the state where a reader has no number and is
  most likely to guess. Apply when building any surface with mandated naming or
  disclosure plus a degraded/unavailable state. Provides the labels-are-copy
  separation and the no-RPC test configuration that exposes it.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.6 (VUX v1, truthful accounting surfaces)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - truthful-ux
  - degraded-states
  - compliance
  - react
---

## Problem

A requirement mandates that a disclosed valuation be labelled
`strategic_nav_disclosed` and never called "backing". The implementation wrapped
the whole block in a data gate:

```jsx
<Truth state={stats} what="Strategic">
  {(v) => (
    <dl>
      <dt>Strategic NAV (disclosed) <code>strategic_nav_disclosed</code></dt>
      <dd>{v.strategicNavDisclosed ?? 'Not disclosed'}</dd>
      ...
    </dl>
  )}
</Truth>
```

When the indexer was unreachable, the entire block — **including the mandated
column name and the "never backing" qualifier** — was replaced by "Data
unavailable". The naming requirement held only while the data source was up.

That is backwards. A reader who can see a number can often infer what it is. A
reader who sees nothing has only the labels, and if those are gone too, guessing
is all that is left.

## Trigger Conditions

### Symptoms

- A required label/unit/qualifier/column name lives inside a loading, error, or
  availability conditional
- A compliance test passes locally (data present) and fails with the backend down
- The degraded state renders a bare "unavailable" where a labelled unavailable
  value belongs
- Units or currency labels vanish along with the figure

### The tell

Grep the component for the mandated string. If it sits inside a `{cond && …}`,
a render-prop, a `?:` on data, or an early `return <Error/>`, it is at risk.

### Context

| Context | Value |
|---|---|
| Technology Stack | React/Vue/any conditional-render UI |
| Timing | building surfaces with mandated naming AND a failure state |
| Prerequisites | a requirement about what something is *called* |

## Root Cause

Labels and values have different provenance and are wrongly given the same
lifetime:

| | Source | Should depend on the data source? |
|---|---|---|
| value | the data source | **yes** |
| label / unit / column name | the specification | **no** |
| qualifier / disclaimer | the specification | **no** |

Wrapping them together makes a specification-derived fact contingent on a
network call.

## Solution

### Step 1: Render labels outside the gate; gate only the value

```jsx
{/* Labels are copy, not data. FR-14.4's naming requirement is a statement about
    what a figure is CALLED; it cannot be contingent on the figure being
    available, or the naming quietly disappears in exactly the degraded state
    where a reader is most likely to guess. */}
<dl className="stats">
  <div>
    <dt>Strategic contributed principal</dt>
    <dd>
      <Truth state={stats} what="Strategic contributed principal">
        {(v) => <>{format(v.contributed)} WETH</>}
      </Truth>
    </dd>
  </div>
  <div>
    <dt>Strategic NAV (disclosed) <code>strategic_nav_disclosed</code></dt>
    <dd>Not disclosed</dd>
  </div>
</dl>
```

The unavailable state now appears *inside* a labelled row: the reader learns both
that the figure is missing and what the missing figure would have been.

### Step 2: Keep constant-by-specification values out of the gate entirely

A field that is *always* "not disclosed" by design is not data at all. Rendering
it through a data gate implies a data source exists.

### Step 3: Make the unavailable component structurally incapable of holding a value

```jsx
export function Unavailable({ reason, staleSeconds, what }) { /* no `value` prop */ }
```

No prop, no accidental leak of a stale figure into the failure path.

### Step 4: Run the compliance suite with the data source deliberately absent

This is what exposes the class:

```javascript
// playwright.config.js — no RPC and no indexer configured, on purpose.
// It puts every live read into its failure path, so the copy requirements are
// asserted in the degraded state too. A surface that only tells the truth when
// the chain is reachable is not a truth surface.
```

Then assert the mandated strings are still present:

```javascript
test('naming survives an unreachable backend', async ({ page }) => {
  await page.goto('/accounting');
  const text = await page.locator('body').innerText();
  expect(text).toContain('strategic_nav_disclosed');
  expect(text).toContain(STRATEGIC_LABELS.neverBacking);
});
```

## Verification

### Command

```bash
# with NO backend configured
npx playwright test
```

### Expected Output

```
  ✓ /accounting and /treasury use the accepted strategic_nav_disclosed naming
  ✓ unreadable values render as explicitly unavailable, never as 0 or a stale number
  25 passed
```

### Checklist

- [ ] Every mandated label/unit/qualifier grepped and confirmed outside data gates
- [ ] Only values sit behind the availability gate
- [ ] The unavailable component cannot render a value (no prop for one)
- [ ] Specification-constant fields are not routed through a data gate
- [ ] The compliance suite runs with the backend absent, not only present
- [ ] Degraded-state assertions cover the naming requirements, not just the values

## Related

- `compliance-copy-asserts-predication` — the sibling finding from the same suite.
- The general rule this instance teaches: **run compliance tests in the failure
  state**, because requirements about what users are *told* bind hardest when
  there is least to tell them.
