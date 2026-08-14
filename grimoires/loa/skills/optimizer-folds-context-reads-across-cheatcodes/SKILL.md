---
name: optimizer-folds-context-reads-across-cheatcodes
description: |
  `block.timestamp`, `block.number`, `chainid` and similar context opcodes are
  invariant within a real transaction, so an optimizing compiler is entitled to
  evaluate them once per frame and reuse the value. Test cheatcodes that mutate
  that context mid-frame — `vm.warp`, `vm.roll`, `vm.chainId` — violate the
  assumption. The result is silent: a test reading `block.timestamp` both BEFORE
  and AFTER a warp gets the same value twice, so before/after comparisons compare
  a value with itself. Crucially this appears the moment optimization is enabled
  on a suite that was written without it, turning previously-meaningful
  assertions into tautologies with no code change and no warning. Apply when
  enabling `optimizer`/`via_ir` on an existing Foundry (or Hardhat) suite, and
  when a time-dependent assertion fails with two identical numbers or starts
  passing unconditionally. Fix by reading context through a cheatcode call, which
  cannot be folded.
loa-agent: implementing-tasks
extracted-from: cycle-002 / sprint-3 (invariant handler `passTime` assertion)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - foundry
  - solidity
  - optimizer
  - via-ir
  - test-integrity
  - cheatcodes
---

## Problem

After enabling `via_ir` + `optimizer`, a test asserting that a handler action
advanced the clock failed with:

```
AssertionFailed("passTime actually advances the clock: expected 45702 > 45702")
```

Both sides were `45702`. The warp had in fact executed — the timeline arithmetic
confirmed the value was the post-warp timestamp. What failed was the *before*
read:

```solidity
uint256 tBefore = block.timestamp;   // folded…
handler.passTime(12 hours);          // …across this vm.warp…
assertGt(block.timestamp, tBefore);  // …into the same TIMESTAMP evaluation
```

The compiler evaluated `TIMESTAMP` once and reused it for both reads, so
`tBefore` held the *post*-warp value.

The failure was the lucky case. The dangerous case is the same fold in an
assertion that then passes vacuously.

## Trigger Conditions

### Symptoms

- An assertion fails comparing two **identical** numbers where one should be
  older (`expected 45702 > 45702`).
- A time-dependent test starts passing regardless of the warp amount.
- Symptoms appear immediately after enabling `optimizer` or `via_ir`, with no
  change to the test.

### When to apply proactively

- Enabling `optimizer` / `via_ir` on a suite written without it — **audit every
  before/after context comparison before trusting the green run.**
- Writing any test that reads `block.*` on both sides of `vm.warp`/`vm.roll`.
- Reviewing a diff that turns on optimization in a repo with time-based tests.

### When this does NOT apply

- A single context read per frame — unaffected; there is nothing to fold against.
- Reads separated by a real transaction boundary.
- Values read from **contract storage** that happen to hold a timestamp (e.g.
  `rig.epochStart()`): those are `SLOAD`s through an external call, not folds.

## Root Cause

`TIMESTAMP` is a pure, transaction-invariant opcode. Common-subexpression
elimination over pure opcodes is a correct and desirable optimization: within one
real transaction the value genuinely cannot change, so evaluating it once is
sound.

Cheatcodes break the premise. `vm.warp` mutates VM state that the language model
treats as constant for the frame's duration. The compiler is not wrong — the
*test* is relying on behaviour the language does not promise. That is why there
is no warning, and why the legacy pipeline's silence about it was luck rather
than safety.

The reason the bug is quiet: the fold produces `x > x`, which is `false` for
`assertGt` (loud) but `true` for `assertGe`, `assertLe`, and `assertEq`
(silent). A suite full of `assertGe(after, before)` sanity checks degrades to
tautologies without a single failure.

## Solution

### 1. Read context through a cheatcode

An external call cannot be folded with a local opcode evaluation:

```solidity
uint256 tBefore = vm.getBlockTimestamp();
handler.passTime(12 hours);
assertGt(vm.getBlockTimestamp(), tBefore, "passTime advances the clock");
```

Foundry provides `getBlockTimestamp()`, `getBlockNumber()`, and equivalents. In a
`forge-std`-free repo, declare only what is needed on the local `Vm` interface
and document why at the declaration, so the next author does not "simplify" it
back to `block.timestamp`:

```solidity
/// @dev Reads the timestamp through a call the optimizer cannot fold. Since
///      `via_ir` + `optimizer` were enabled, `block.timestamp` may be evaluated
///      once per frame — correct for a real transaction, wrong across `vm.warp`.
///      Use this in any before/after shape; a single read per frame is fine.
function getBlockTimestamp() external view returns (uint256);
```

### 2. Or restructure so only one read exists per frame

Often cheaper: derive the expected value instead of measuring both ends.

```solidity
// Anchor to contract state (an external SLOAD, unaffected by the fold)
vm.warp(rig.epochStart() + 3_000);
assertEq(rig.currentPrice(), DECAY_FLOOR, "fully decayed");
```

This is why most of the suite was unaffected: warps anchored to
`rig.epochStart() + delta` and asserted on contract views, never on two local
`block.timestamp` reads.

### 3. Audit the existing suite when you flip the flag

Enabling optimization is the trigger to sweep for the pattern:

```bash
# Frames containing both a warp and a context read are the candidate set.
grep -rn 'vm.warp\|vm.roll' --include='*.t.sol' -l test/ \
  | xargs grep -ln 'block.timestamp\|block.number'
```

Then check each hit for a **before/after** shape specifically. Suspect any
surviving `assertGe`/`assertLe`/`assertEq` between two context reads — those fail
silently.

## Verification

1. **Prove the fold, don't assume it** — the arithmetic must show the reported
   value is the post-mutation one. Here `2501 + 43201 = 45702` confirmed the warp
   ran and the *before* read was the corrupted side.
2. **Fix and confirm the assertion now discriminates** — it should pass with a
   real warp and fail with a zero warp. An assertion that passes either way is
   still folded.
3. **Re-run the whole suite** and treat any test that changed behaviour as a
   second instance of the same bug.
4. **Check the silent directions** — search for `assertGe`/`assertEq` between two
   context reads; those would not have announced themselves.

Observed here: one instance, fixed via `vm.getBlockTimestamp()`, 144/144 green.
The rest of the suite was structurally immune because it anchored warps to
contract state.

## Anti-Patterns

- **Concluding the cheatcode is broken.** `vm.warp` worked; the compiler folded
  the read. Chasing the cheatcode wastes the session.
- **Disabling the optimizer to make the test pass.** It fixes one symptom and
  gives up the reason optimization was enabled.
- **Fixing only the failing test.** The failure surfaced because the direction
  happened to be strict; the same fold in `assertGe` is already silent elsewhere.
- **Caching `block.timestamp` in a local "for readability" in test helpers.** It
  is the exact shape that folds.
- **Assuming green-after-enabling means unaffected.** Vacuous assertions are
  green.

## Related Resources

- `test/harness/Vm.sol` — the `getBlockTimestamp` declaration and its rationale.
- `test/rig/RigInvariants.t.sol` — `test_EveryHandlerActionDoesRealWork`, the
  test that exposed it.
- `foundry.toml` — the `via_ir` enablement that made it reachable.

## Related Memory

- [[stack-too-deep-when-the-schema-is-fixed]] — why the optimizer was enabled at
  all; this is one of its two downstream consequences.
- [[inherited-build-flags-reach-frozen-units]] — the other consequence, on the
  build side.
- [[fuzz-harness-validity-audit]] — same family: an assertion that cannot fail is
  green at any depth. That entry covers `bound`/assert primitives; this one is a
  compiler-level source of the same vacuity.

## Changelog

- 1.0.0 (2026-08-13) — extracted from cycle-002 / sprint-3.

## Metadata (Auto-Generated)

- Applications: 1
- Success rate: 1/1
- Last applied: 2026-08-13
