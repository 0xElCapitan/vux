---
name: mutate-the-source-for-constructor-only-guards
description: |
  When a load-bearing check lives INSIDE a constructor's execution path with no
  externally-callable entry point that exercises the same logic (a one-shot
  deployer contract, an initializer-free constructor-does-everything design), a
  Solidity test double that reimplements a broken version of that path proves
  nothing about the SHIPPED code — it only proves the double itself can be made
  to fail, which nobody doubted. Prove the guard is load-bearing by mutating the
  actual production source file, running the suite, observing the specific
  expected failure, then restoring the file and verifying it's byte-identical
  (SHA-256) to before. This is the same "green -> red -> green with restore"
  pattern used for provenance/drift negative demonstrations, applied to
  application-logic guards rather than tooling gates. Apply whenever a negative
  test needs to prove a check embedded in unexported/unreachable logic (a
  constructor, a private/internal function with no public wrapper) is real and
  not vestigial.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-7 /implement (GenesisDeployer nonce-stability negative, Task 7.3)
extraction-date: 2026-08-17
version: 1.0.0
tags:
  - solidity
  - foundry
  - mutation-testing
  - negative-testing
  - test-design
  - shell
---

## Problem

A contract's constructor contains a critical guard (e.g. "if a predicted CREATE address doesn't match the actual deployment, revert the whole thing"). There is no separate function that runs this logic outside of actually constructing the contract — you cannot call `_checkPredictedAddress()` on a deployed instance, because the check only exists during construction and the constructor only runs once. Writing a negative test that PROVES this guard is load-bearing (not just plausible-looking code) seems to require either duplicating the constructor logic in a test-only contract, or giving up on proving it at all.

## Trigger Conditions

### Symptoms

- The property to be tested negatively ("a wrong nonce sequence reverts the whole deployment") only exists inside constructor logic
- There's no externally callable function that exercises the same check on an already-deployed instance
- The natural first instinct is to write a second, deliberately-broken contract in the test file that mimics the constructor's shape with the guard removed or perturbed
- That test-double approach, on reflection, only demonstrates that the DOUBLE can be made to fail — it says nothing about whether the actual shipped constructor's guard does anything

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity, Foundry, any one-shot/constructor-driven deployment pattern |
| Environment | Any contract whose critical logic runs once, in a constructor, with no post-deployment callable equivalent |
| Timing | While designing the negative-test suite for a deployer/genesis-style contract |
| Prerequisites | The project already has an established source-mutation-and-restore pattern for other kinds of gates (provenance, drift detection) — if not, this establishes one |

## Root Cause

A Solidity test double that reimplements "the constructor, but with an extra unplanned step" is a DIFFERENT contract from the one being shipped. Proving that double reverts under the mutation proves the double's logic is internally consistent — it says nothing about whether the actual `src/` contract's guard is load-bearing, present, or even correctly wired. The only way to test the SHIPPED constructor's behavior under a mutation is to mutate the shipped source itself, compile, and run.

## Solution

### Step 1: Write a script (not a Solidity test) that mutates the real source file

```bash
TARGET="src/YourDeployer.sol"
ORIGINAL_SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
cp "$TARGET" "$TARGET.bak"
trap 'cp "$TARGET.bak" "$TARGET"; rm -f "$TARGET.bak"' EXIT   # always restore

# Inject the mutation via awk (not sed -i, which can choke on the injected
# text's own special characters) before a known anchor line:
awk -v anchor="$ANCHOR_LINE" -v inject="$MUTATION_LINE" '
  !done && index($0, anchor) == 1 { print inject; done = 1 }
  { print }
' "$TARGET" > "$TARGET.mutated"
mv "$TARGET.mutated" "$TARGET"
```

### Step 2: Run the EXISTING suite (unmodified) against the mutated source and assert the SPECIFIC expected failure

```bash
OUTPUT="$(forge test --match-path "$SUITE" --match-test "$CASE" 2>&1)"
echo "$OUTPUT" | grep -q "YourExpectedError" || { echo "wrong failure mode"; exit 1; }
```

Asserting the specific error (not just "something failed") is what distinguishes "the guard caught it" from "the file no longer compiles" or "an unrelated check fired first."

### Step 3: Restore and re-verify byte-identical, then re-run to confirm green again

```bash
cp "$TARGET.bak" "$TARGET"
[[ "$(sha256sum "$TARGET" | cut -d' ' -f1)" == "$ORIGINAL_SHA" ]] || { echo "restore failed"; exit 1; }
forge test --match-path "$SUITE" --match-test "$CASE"   # must be green again
```

## Verification

### Command

```bash
bash tools/yourdir/demo-your-negative.sh
```

### Expected Output

```
-- 1/3 baseline: green --
ok baseline green
-- 2/3 mutation: inject ... --
ok the mutated launch reverted with YourExpectedError
-- 3/3 restore and re-verify --
ok source restored byte-identical
ok green again
YOUR-PROPERTY NEGATIVE DEMONSTRATED (green -> red -> green)
```

### Checklist

- [ ] The mutation is applied to the actual shipped `src/` file, not a test-only copy
- [ ] The assertion is on the SPECIFIC expected error/revert reason, not just "it failed"
- [ ] The file is restored and its SHA-256 verified identical to the pre-mutation hash
- [ ] The suite is confirmed green again after restore (proves the restore, not just the hash check, is correct)
- [ ] `trap ... EXIT` (or equivalent) guarantees restoration even if the script errors partway

## Anti-Patterns

### Don't: write a second Solidity contract that mimics the constructor with the guard perturbed

```solidity
// BAD — proves the double can fail, proves nothing about src/YourDeployer.sol
contract MutatedDeployerForTesting {
    constructor(...) {
        new UnplannedThing();  // the "mutation," but on a fork, not the original
        // ...rest of the logic, hand-copied and potentially already stale
    }
}
```

Any drift between this double and the real constructor (a field added, an order changed) makes the test's pass/fail status meaningless with respect to the actual shipped code, and that drift is invisible until someone notices the two have diverged.

## Related

This generalizes the existing `demo-drift-negative.sh` / `demo-boundary-negative.sh` provenance-gate pattern to application-logic guards, and pairs with [[verify-the-mutant-not-the-verdict]] — that skill's core rule (prove the mutant landed by asserting on the mutated content, not on the run's verdict, before trusting any conclusion) is exactly why this pattern re-hashes and asserts SHA-256 equality rather than trusting `cp`'s exit code alone.
