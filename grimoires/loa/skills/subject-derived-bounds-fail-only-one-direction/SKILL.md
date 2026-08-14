---
name: subject-derived-bounds-fail-only-one-direction
description: |
  An invariant bounds a quantity by something the system under test reported —
  `owed <= feesCharged - feesCollected`, where `feesCollected` is read off the
  contract's own event. The reflex is to call it circular and discount the
  evidence: the subject is grading itself. That reflex is wrong about half the
  time, and the refinement is cheap. Circularity is not "a term came from the
  subject"; it is "contamination moves the bound in the MASKING direction". Work
  out which way a defect pushes each subject-derived term. If a misclassification
  INFLATES the subtrahend, the bound tightens toward failure — the contamination
  is the detector, not the blind spot, and an unsigned subtraction will even
  underflow-revert on it. Pair that with an invariant asserting the same
  subject-derived quantity against an INDEPENDENT bound, and both directions
  close. Apply when auditing ghost-variable invariants, accounting conservation
  checks, or any "is this evidence circular?" judgement — and confirm the
  direction by mutation rather than by argument.
loa-agent: auditing-security
extracted-from: cycle-002 / sprint-5 / /review-sprint sprint-5
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - security-audit
  - invariant-testing
  - ghost-variables
  - circular-evidence
  - accounting
  - mutation-testing
  - solidity
---

## Problem

A load-bearing invariant claims that a position's `tokensOwed` contains fees only
— never principal. It is written as:

```solidity
assertLe(vuxOwed, handler.ghostFeesChargedVux() - handler.ghostFeesCollectedVux());
```

`ghostFeesCharged` is computed independently: from the handler's own swap inputs
and the pinned fee tier, never from the pool. Good. But `ghostFeesCollected` is
accumulated from the contract's **own `VyrfHarvest` event** — a number produced
by the very code the invariant is supposed to police.

A reviewer applying the standard circularity screen ("evidence derived from the
subject proves nothing about the subject") discounts the invariant and reports a
weak-evidence finding. That would be wrong here, and the argument that shows why
takes about a minute — but only if you ask the right question.

## Trigger Conditions

### Symptoms

- A ghost-variable invariant whose bound mixes an independently-derived term with
  one read from the subject's events, return values, or storage.
- An implementation report claiming the bound is "independent" or "non-circular"
  without saying in which direction.
- Accounting conservation checks of the shape
  `observed <= issued - consumed`, where `consumed` is self-reported.

### When to apply

- Auditing invariant/property suites that use ghost accumulators.
- Grading an evidence-quality finding: "is this circular?"
- Reviewing fee/principal separation, supply attribution, reserve backing
  attribution, or any conservation identity.

### When this does NOT apply

- Bounds where **every** term is subject-derived — there is no independent anchor
  at all, and the direction argument cannot rescue it.
- Cases where the subject can choose its report *adversarially* rather than as a
  consequence of the defect (a malicious contract under-reporting on purpose).
  The direction argument assumes the report follows from the bug, which holds for
  an accidental-defect threat model, not a malicious-implementation one. Say
  which model you are in.

## Root Cause

"Circular" is shorthand for a directional property that the shorthand hides. A
bound `X <= f(independent, subjectDerived)` is only useless if a defect in the
subject moves `f` in the direction that **admits** the wrong `X`. If the defect
moves `f` the other way, the subject-derived term is doing the opposite of hiding
the bug: it is amplifying it.

Concretely, with `bound = charged - collected`:

- A `decreasePol` that misfiles principal as fee yield emits a **larger**
  `VyrfHarvest`.
- That inflates `ghostFeesCollected`.
- Which **shrinks** the right-hand side — the bound tightens.
- And because both are `uint256`, once `collected > charged` the subtraction
  **reverts on underflow** before the comparison is even reached.

So the contaminated term converts a misclassification into a loud failure. The
independent half (`charged`, from the fee tier and the harness's own inputs)
supplies the anchor; the subject-derived half supplies the sensitivity.

## Solution

### 1. Classify every term as independent or subject-derived

Read the ghost's write sites, not its name. `ghostFeesCharged` is credible only
if it is genuinely computed outside the subject:

```solidity
function _feeBound(uint256 amountIn) private view returns (uint256) {
    return Math.mulDiv(amountIn, feeTier, 1_000_000 - feeTier, Math.Rounding.Ceil) + 1;
}
```

— derived from the pinned fee tier and the handler's own input. Never from
`collect`'s return, never from `tokensOwed`.

### 2. For each subject-derived term, push a defect through it

Ask: *if the bug I am worried about occurred, would this number go up or down,
and does that loosen or tighten the bound?* Write the chain out. Tightening ⇒ the
term is a detector. Loosening ⇒ genuine circularity, and now you have a real
finding with a mechanism attached.

### 3. Check the rounding direction of the independent term too

An independent bound is only non-vacuous if it errs on the correct side. Here it
over-approximates by ≤1 wei per swap and is always used on the large side of a
`<=`. Over-approximation loosens — acceptable and tiny. **Under**-approximation
would have made the assertion fail on honest runs, which is a different bug. Say
which one you checked.

### 4. Require the paired invariant that closes the other direction

One inequality bounds what may sit *owed*; the complement bounds what may be
*classified*:

```solidity
assertLe(handler.ghostVyrfVuxBurned(), handler.ghostFeesChargedVux());
```

Together: principal cannot sit owed as if it were a fee, and cannot be paid out
as one. A single inequality usually leaves one of those open — look for the pair
before accepting the property as closed.

### 5. Confirm the direction by mutation, not by argument

The direction argument is a prediction. Test it: break the ordering the invariant
polices and check that the predicted failure mode is what actually appears.

## Verification

Confirmed live on cycle-002 sprint-5. Mutation M1 reordered `decreasePol` to burn
liquidity **before** the fee poke/collect, so the fee collect sweeps principal and
classifies all of it as VYRF fee yield:

| predicted | observed |
|---|---|
| `ghostFeesCollected` inflates past `ghostFeesCharged` | ✅ |
| the `charged - collected` subtraction underflows | ✅ `[FAIL: panic: arithmetic underflow or overflow]` |
| the paired classified-amount invariant also trips | ✅ |
| named ordering tests fail | ✅ `test_DecreasePolCollectsFeesFirstThenSweepsPrincipalAtomically`, `test_ReturnedPrincipalIsNeverRevenue`, `test_FB7_FullyUnwindingPolLeavesTheReserveUntouched` |

4 failures total, and the underflow — the mechanism this skill is about — was
predicted before the run. Baseline for contrast: 9 invariants green at
`runs: 256, calls: 16384, reverts: 0`.

## Anti-Patterns

- **Discounting the invariant on the word "circular".** Name the direction or do
  not make the claim. "A term came from the subject" is not a finding.
- **Accepting "the bound is independent" from the report.** Read the ghost's
  write sites. Half-independent is common and is fine — but only after you say
  which half and which way it moves.
- **Checking independence and skipping rounding.** An independent bound that
  under-approximates fails honest runs; one that wildly over-approximates is
  vacuous. Both are real defects the independence check does not catch.
- **Accepting one inequality as closing a two-sided property.** Fee-vs-principal
  needs both "cannot sit owed as a fee" and "cannot be paid as one".
- **Reasoning about the direction without testing it.** The prediction is cheap
  to falsify with one mutation; an untested direction argument is exactly the
  kind of plausible-but-wrong claim an audit is supposed to catch.

## Related Resources

- Uniswap v3-core `Position.update` — `tokensOwed` is credited by both `burn`
  (principal) and the fee poke, which is why the separation is ordering rather
  than accounting.

## Related Memory

- [[invariant-derivation-over-fuzz-depth]] — companion: explain WHY a numeric
  property holds instead of re-running at higher depth. This skill is the
  evidence-quality screen applied to the bound that derivation produces.
- [[independent-constant-reproduction]] — the same circularity concern for
  published constants; there the remedy is full independence, here it is
  directional.
- [[intra-call-ordering-needs-an-interleaved-observer]] — extracted from the same
  mutation battery; the ordering this invariant polices is the one that DOES have
  a post-state witness, which is why it is caught and consume-before-pay is not.
- [[fuzz-harness-validity-audit]] — audit repo-owned harness primitives before
  reading any coverage number off them.

## Changelog

- 1.0.0 (2026-08-14) — extracted from cycle-002 / sprint-5 `/review-sprint`.

## Metadata (Auto-Generated)

- Applications: 1
- Success rate: 1/1
- Last applied: 2026-08-14
