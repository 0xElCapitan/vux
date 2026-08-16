---
name: a-passing-regression-test-proves-nothing-alone
description: |
  A fix ships with a "regression test" and the suite is green. Green proves the
  code compiles and the assertions hold against the FIXED tree — it does not prove
  the test would have caught the ORIGINAL defect. A test can pass for reasons
  unrelated to the fix (wrong scope, a mock too permissive, an assertion that
  happens to be satisfied by both the buggy and correct value). Apply when
  reviewing any bugfix + its accompanying regression test, especially under an
  adversarial-review mandate. Provides the mutation-kill technique: reintroduce
  the exact original defect, re-run the SAME test, and require the SPECIFIC
  predicted failure signature — then restore and verify byte-identity.
loa-agent: reviewing-code
extracted-from: sprint-6 (VUX v1 Truth Surfaces), remediation re-review passes
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - code-review
  - regression-testing
  - mutation-testing
  - adversarial-review
---

## Problem

Two remediation passes in one review cycle each shipped a fix plus a test that
"proved" it: an indexer identity fix with 11 passing unit tests, and a React
component fix with a Playwright suite reporting 41/41. Both suites were real,
both ran against real code, and both were insufficient evidence on their own — a
test can be green because it exercises the fixed path correctly, or because it
never actually exercises the failure mode it claims to guard, or because its
assertion is loose enough that either the buggy or the fixed value satisfies it.
The review brief explicitly anticipated this: *"Do not accept the regression test
merely because it passes; confirm it fails against the old identity rule or
otherwise mechanically discriminate the original defect."* That instruction says
WHAT must be true; it does not say how to prove it without trusting the claim.

## Trigger Conditions

### Symptoms

- A fix + its own regression test are presented together, and the suite is green
- The review brief (or the adversarial-review protocol) requires the test to
  "discriminate," "genuinely detect," or "not merely pass"
- The defect was subtle enough that a shallow test could accidentally satisfy the
  same assertion under both the buggy and fixed code

### Context

| Context | Value |
|---|---|
| Technology Stack | any — demonstrated on a TypeScript/Node event handler and a React/Next.js client component |
| Timing | code review, specifically re-review of a remediation pass |
| Prerequisites | the fixed file and the pre-fix behavior are both reconstructible (git history, or a documented before/after) |

## Root Cause

A passing test is evidence of "the assertions hold against this tree," not
evidence of "this test would fail against the tree it claims to guard against."
Those are different claims, and the gap between them is exactly where a
rubber-stamped regression test hides — the test author already knows what they
fixed and unconsciously writes an assertion shaped by the fix, not by the defect.
Closing that gap requires an experiment: hold the test fixed, vary only the
subject code between "buggy" and "fixed," and observe that the *outcome* differs
in the way the defect's mechanism predicts.

## Solution

### Step 1: Isolate a reversible mutant of the fix — pick the technique by how the code is exercised

Two shapes recur, and they need different isolation:

**A. Unit-level code invoked directly by the test harness** (e.g., a Node module
imported by `node --test`): copy the fixed file to a scratch location OUTSIDE the
repository, patch in only the specific reverted expression, and import the mutant
by absolute path from a throwaway script that reuses the SAME stub/mock
infrastructure the real test uses. The reviewed tree is never touched.

```js
// scratch/mutation-check.mjs — imports the mutant, not the reviewed file
import { handlers, makeStore, evt } from 'file:///…/test/ponder-virtual.mjs';
await import('./mutant-index.ts');   // scratch copy with ONLY the old key restored
```

**B. Code that must be compiled/bundled before it can be observed** (e.g., a
React component whose defect only renders in the built static export): there is
no isolated-copy option — the artifact under test IS the build output. Revert the
fix IN PLACE in the working tree, rebuild the exact artifact the test consumes,
run the SAME test file against it, and then restore.

```bash
# capture the fixed file's hash before mutating
sha256sum web/components/WalletFlows.jsx     # 572fc1ce…

# revert ONLY the guard-freezing change, rebuild, test
patch web/components/WalletFlows.jsx < revert.diff
npm run build:test && npx playwright test take-guard

# restore, then PROVE the restore is exact — do not trust "git checkout" silently
git checkout -- web/components/WalletFlows.jsx
sha256sum web/components/WalletFlows.jsx     # must equal 572fc1ce… again
```

### Step 2: Reintroduce the SPECIFIC defect, not a generic bug

Copy the reviewer's or implementer's own description of the mechanism and patch
in exactly that, nothing more. A one-line surgical revert (the old identity key;
the persistent `confirmed` state) isolates the causal claim — if you patch in more
than the described defect, a failure could come from the extra change instead.

### Step 3: Predict the failure signature BEFORE running

Write down what should go wrong, from the defect's own mechanism, before
observing the actual output:

- Old content-derived key on two identical burns → 1 row recorded instead of 2,
  summed delta short by one burn's worth
- Frozen `confirmed` price → the displayed maximum stays at the FIRST price after
  a real poll delivers a second, different price

### Step 4: Run and require the PREDICTED failure, not just "a" failure

```
rows recorded : 1   (remediated expects 2)
summed delta  : -5000000000000000000   (remediated expects -10000000000000000000)
>>> MUTANT KILLED — the regression genuinely detects the old identity rule
```

```
Expected string: "18.000000"
Received string: "Maximum price you will pay: 25.000000 WETH"
```

Both outputs match the mechanism exactly — not a crash, not an unrelated
assertion failure, but the precise wrong value the defect predicts. A failure
that doesn't match the predicted shape means the mutant kill is coincidental and
the test still needs scrutiny.

### Step 5: Restore, and prove the restore rather than assume it

For technique B especially — where the fix was reverted in the live working
tree — hash the file before mutating and after restoring, and require equality.
`git checkout --` is usually reliable, but review is exactly the context where
"usually" is not the bar; the byte-identity check is cheap and closes the loop.

### The gate-probe variant

The same principle applies to verification GATES, not only regression tests for
application code. A codegen/build gate that reports "config, schema and API
modules all load" can be probed the same way: feed it a deliberately invalid
required input (`VUX_RIG_ADDRESS=''`) and check whether the verdict changes. If
it doesn't, the gate proves less than its wording claims — grade that as a
wording/evidence-precision finding, not necessarily a blocker, but record it.

## Verification

### Command

```bash
# technique A — isolated mutant, no repo mutation
node --experimental-strip-types scratch/mutation-check.mjs

# technique B — in-place revert/rebuild/restore
sha256sum <file> && <revert> && <rebuild> && <test> && <restore> && sha256sum <file>
```

### Expected Output

The predicted failure signature on the mutant, and hash equality after restore.

### Checklist

- [ ] The defect's exact mechanism is written down as a prediction BEFORE mutating
- [ ] Isolation technique matches how the code is exercised (import vs. rebuild)
- [ ] Mutation is surgical — only the described defect, nothing else changed
- [ ] Same test file/harness runs against both the fixed and mutated code
- [ ] Failure signature matches the prediction, not merely "any" failure
- [ ] File restored and verified byte-identical (hash before == hash after)
- [ ] For gate scripts: probed with a deliberately invalid input, not only observed passing on valid input

## Anti-Patterns

### Don't: accept "the suite is green" as proof of discrimination

Green is necessary, never sufficient. It proves the fixed code satisfies the
test; it says nothing about whether the pre-fix code would have failed it.

### Don't: revert more than the documented defect

A broader revert conflates "did this specific defect get caught" with "does this
file work at all," and a failure could come from the extra unrelated change.

### Don't: restore via `git checkout` and move on without verifying

The whole point of the exercise is confidence; skipping the post-restore hash
check reintroduces exactly the kind of unverified trust the mutation test exists
to eliminate.

## Related Resources

- Reviewing-code adversarial protocol (this repository): "You are not a rubber
  stamp. You are a rival."

## Related Memory

### Related Skills

- `streaming-attribution-by-exclusion-then-refine` — the H-1 identity fix this
  technique verified in this session
- `build-time-env-inlining-hides-branches-from-review` — the M-4 defect this
  technique verified; that defect only rendered under a build the mutation test
  in turn had to rebuild (technique B)
- `verify-the-mutant-not-the-verdict` — the companion half of the same overall
  discipline, from the implementer's side of the same fix: that skill proves the
  MUTATION ITSELF landed (assert on mutated content, not the run's verdict, since
  a no-op `sed`/patch exits 0 and looks identical to a real regression) before any
  conclusion is drawn from re-running the test. This skill assumes the mutation
  landed and addresses the next question — whether the resulting failure matches
  the SPECIFIC predicted signature, not merely "a" failure. Read together: prove
  the mutant landed, then prove it was killed for the right reason.

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
  session: sprint-6 remediation re-review (passes 2 and 3)
```
