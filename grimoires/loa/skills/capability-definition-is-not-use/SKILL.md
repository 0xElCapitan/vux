---
name: capability-definition-is-not-use
description: |
  A security check greps a build artifact for a dangerous API name and fires. The
  hit is the library's own *definition* of that API — dead code the bundler ships
  unconditionally — not a call site. The two look identical to a substring match,
  and only one is a finding. Apply when a bytecode/bundle/artifact scan fires on
  an identifier, before either deleting the check or accepting the failure.
  Provides the triage question and the sharpened predicate.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.8 (VUX v1, static-export security gate)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - security-testing
  - static-analysis
  - false-positives
  - bundlers
---

## Problem

A gate asserting "this build contains no Server Function endpoint" failed,
flagging `createServerReference` in a shared client chunk. The application defines
no server functions and has no server at all.

The hit was:

```javascript
t.createServerReference = function(e, t) { ... }
```

— the RSC client runtime's own export, bundled by the framework into its shared
chunk regardless of whether the app uses it. Zero call sites. Zero
`react.server.reference` type markers.

Two wrong moves are immediately available:

- **Delete the check.** It was the only mechanical enforcement of the property.
- **Accept "identifier absent" as the bar.** Unsatisfiable — the bundler always
  ships the definition — so the check gets deleted next week anyway.

## Trigger Conditions

### Symptoms

- A grep-based security assertion over built output fires on a dangerous API name
- The application source contains no use of that API
- The hit lands in a vendored/shared/runtime chunk rather than app code
- The matched text reads like `X = function`, `X: function`, `exports.X =`,
  `declare function X`, or a class member declaration
- Someone proposes relaxing the assertion to make the build pass

### Context

| Context | Value |
|---|---|
| Technology Stack | any bundler that ships a runtime (webpack/turbopack/rollup/esbuild), shaded JARs, static Solidity/bytecode scans |
| Timing | when a security gate fails on a build that is believed correct |
| Prerequisites | the check's claim is about *capability use*, not code presence |

## Root Cause

A substring match cannot distinguish three different facts that share a token:

| Fact | Shape | Finding? |
|---|---|---|
| the capability is **defined** | `X = function(...)` | no — library surface |
| the capability is **invoked** | `X(...)` | **yes** |
| the capability's **product exists** | a materialised object with a type marker | **yes** |

Bundlers ship the whole runtime surface because tree-shaking cannot prove an
export unreachable across dynamic boundaries. So the definition is always present,
and the strongest satisfiable claim is about invocation, not presence.

## Solution

### Step 1: Triage before touching the check

Ask exactly one question: **was the capability found, or its invocation?**

```bash
# what did we actually match?
grep -oE ".{90}<identifier>.{90}" path/to/chunk.js | head -3

# is the *product* of the capability present? (the stronger signal)
grep -c '<type-marker>' path/to/chunk.js
```

If the context is an assignment/export and the type-marker count is zero, it is
dead library code.

### Step 2: Sharpen the predicate — count definitions separately from uses

```javascript
const definitionRe = /createServerReference\s*[:=]\s*function/g;   // library surface
const anyRe        = /createServerReference/g;
const markerRe     = /react\.server\.reference/g;                  // materialised product

const markers     = (src.match(markerRe) ?? []).length;
const total       = (src.match(anyRe) ?? []).length;
const definitions = (src.match(definitionRe) ?? []).length;
const uses        = total - definitions;

if (markers > 0 || uses > 0) fail(`usage found (markers: ${markers}, uses: ${uses})`);
```

Two independent signals, both required to be zero. The type marker is the better
one — it indicates the capability actually produced something — so keep it even
when the call-site count is the headline.

### Step 3: Report the distinction in the tool's own output

```
  RSC client runtime    : bundled by next (dead code — no server to call)
  Server Function usage : none (0 markers, 0 call sites)
```

A reviewer reading a bare PASS cannot tell whether the check is meaningful. A
reviewer reading this can.

### Step 4: Record why the check was changed

Loosening a security assertion is exactly the change that should carry its reason
in the source, so the next person does not repeat the triage or, worse, assume it
was weakened for convenience:

```javascript
// Loosening this to "the identifier is absent" would make the check
// unsatisfiable; loosening it to "don't look" would make it useless.
```

## Verification

### Command

```bash
node scripts/verify-static-export.mjs
```

### Expected Output

```
  Server Function usage : none (0 markers, 0 call sites)
VERDICT: PASS — static export, no server runtime, no Server Function endpoint.
```

### Negative control

Confirm the sharpened check still fires on a real use. Add a temporary call site
(or a fixture containing the type marker), re-run, and require a FAIL — then
remove it. A check that no longer fires on anything is not a check.

### Checklist

- [ ] The failing match was inspected in context before any edit to the check
- [ ] The distinction is definition-vs-use, confirmed by a zero type-marker count
- [ ] The predicate now counts definitions separately, rather than dropping the term
- [ ] A second, stronger signal (materialised-product marker) is also asserted
- [ ] The tool prints the distinction, not just PASS
- [ ] The reason for the change is in the source
- [ ] A negative control proves the sharpened check still fails on real use

## Related

- `verifying-vendored-dependency-patches` — the same bundling behaviour that puts
  the definition in your artifact also severs the dependency edge you would
  otherwise verify.
- `[Implementation technique — proving a capability is absent]` (NOTES.md) —
  positive controls for absence claims; this is the complementary hazard, where
  the control passes and the *predicate* is wrong.
- `[Implementation technique — a call-site's selector is not the four bytes you
  think it is]` (NOTES.md) — same family: a naive substring search over compiled
  output answering a different question than the one asked.
