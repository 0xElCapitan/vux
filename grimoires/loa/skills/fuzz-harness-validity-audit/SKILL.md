---
name: fuzz-harness-validity-audit
description: |
  A fuzz suite's reported `runs: 10000` is produced by the fuzzer, not by the
  property — it counts invocations, never distinct explored states. When the
  project vendors no external test framework and implements its own `bound`,
  assertions, and fixtures, every fuzz number in the report is downstream of
  repo-owned primitives that nobody has tested. A degenerate input-shaping
  helper collapses 10,000 runs into one effective case while still printing
  10,000; an assertion that cannot fail turns the whole suite green. Audit the
  harness BEFORE reading any coverage claim. Apply when reviewing property or
  invariant suites built on a hand-rolled harness (no forge-std, no hypothesis,
  no fast-check), especially where the suite carries monetary arithmetic.
loa-agent: reviewing-code
extracted-from: cycle-002 / sprint-2 / /review-sprint sprint-2
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - code-review
  - property-testing
  - fuzzing
  - test-harness
  - solidity
---

## Problem

A sprint report states: property suites pass at 10,000 CI fuzz runs. The suite is
green, the run counts are real, and the reviewer has no external framework to
lean on because the project deliberately vendors none — the harness is
repository-owned source that arrived in the same series of sprints as the code
under test.

Accepting the run count as coverage is the error. `runs: 10000` means the fuzzer
called the function 10,000 times. It says nothing about whether those calls
explored 10,000 distinct states, and nothing about whether a wrong answer would
have been reported.

Two repo-owned primitives sit between the fuzzer and the claim:

- **Input shaping** (`bound`, `clamp`, `assume`) runs *inside* the test, after the
  fuzzer has done its work. If it collapses its range, the fuzzer's 10,000
  distinct words become 10,000 identical test cases — and the output is
  byte-identical to genuine coverage.
- **The assertion mechanism** decides whether a wrong answer fails the run. If it
  cannot fail, the suite is decorative at any depth.

This is the same failure shape as an over-broad prune in a source-boundary gate,
or an absence scan with no positive control: **green because it is looking at
nothing**, indistinguishable from green because everything is correct.

---

## Trigger Conditions

### Symptoms

- The repository has no test framework dependency (no `forge-std`, no
  `hypothesis`, no `fast-check`) — often a deliberate, documented provenance
  decision.
- Test files import a local `BaseTest` / `harness/` / `conftest`-equivalent.
- A report cites fuzz depth as evidence of coverage.
- Expected values in property tests are computed with repo-owned helpers.
- Assertions are custom (`assertEq(a, b, "msg")` defined in-repo).

### Context

| Context | Value |
|---------|-------|
| Stack | Foundry/Solidity, or any property-testing setup with a hand-rolled harness |
| Timing | Code review, before crediting any AC that cites fuzz depth |
| Prerequisites | Ability to read the harness source and re-run the suite |

---

## Root Cause

Test-framework code is normally trusted because it is a widely-used external
dependency with its own test suite. Vendoring none moves that trust onto
repository-owned code that has the same review status as the feature — and the
harness is usually reviewed as "test plumbing" rather than as the thing every
correctness claim depends on.

The fuzzer's contract is narrow: supply pseudo-random words, count invocations,
report reverts as failures. Everything between the word and the assertion belongs
to the repository. So does everything between a wrong answer and a red run.

---

## Solution

Audit the harness first. Five checks, in order; stop and report at the first
failure, because everything after it is unreadable.

### Step 1: Read the input-shaping helper

The canonical correct form maps a fuzzed word into an inclusive range:

```solidity
function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
    if (min > max) fail("bound: min > max");
    if (min == 0 && max == type(uint256).max) return x;  // else max-min+1 overflows to 0
    return min + (x % (max - min + 1));
}
```

Check specifically:

- **The full-range overflow case.** Without the `min == 0 && max == type(uint256).max`
  guard, `max - min + 1` wraps to `0` and the modulo panics — or, in a language
  that wraps silently, degenerates. Its presence is a strong signal the author
  reasoned about the edges.
- **Inclusivity.** `% (max - min + 1)` includes `max`; `% (max - min)` silently
  excludes it, which quietly drops the boundary the property most needs.
- **Inverted arguments** are handled loudly, not clamped silently.
- **Documented bias.** Modulo biases toward the low end. That is acceptable *only*
  if the boundary values that matter (`0`, `1`, `S_MIN`, `S - S_MIN`) are covered
  by dedicated unit tests instead of being left for the fuzzer to stumble onto.
  If the bias is undocumented and the boundaries are unit-tested nowhere, that is
  the finding.

### Step 2: Prove the assertions can fail

Establish the mechanism, then demand evidence it works.

In Foundry, a reverting test *is* a failing test, so an assertion implemented as
`if (a != b) revert AssertionFailed(msg)` is valid and needs no DSTest-style
`failed()` flag. Valid, but unproven — so look for a **meta-suite**: a test file
whose tests deliberately trip each assertion inside `expectRevert` and confirm it
reverts with the expected payload.

```
[PASS] test_FailingUintEqualityRevertsWithValues()
[PASS] test_FailingAssertTrueReverts()
[PASS] test_FailingOrderingReverts()
[PASS] test_PassingAssertionsDoNotRevert()
```

If no such meta-suite exists, that absence is itself the finding — the harness
asserts the code and nothing asserts the harness.

### Step 3: Check for tolerance assertions

On exact arithmetic — floor division, monetary rounding, conserved supply — the
presence of `assertApproxEq*` is a finding on its own: it is precisely the hole a
rounding regression fits through. Its deliberate *absence*, stated as a decision,
is a positive signal.

### Step 4: Check that each property's domain is asserted, not assumed

A test claiming to exercise a special domain must prove it is in that domain on
every run, or it silently degrades into a duplicate of the easy case.

```solidity
// The claim is "B*q overflows uint256". Assert it; do not infer it from bounds.
assertTrue(b != 0 && q > type(uint256).max / b, "domain check: B x q genuinely overflows");
```

Also confirm the bounds admit the domain at all: recompute the extremes by hand
and check the intended product genuinely exceeds (or stays within) 256 bits.

### Step 5: Only now read the run counts

Re-run under the CI profile yourself rather than trusting the reported number —
depth usually comes from a profile the default run does not select.

```bash
FOUNDRY_PROFILE=ci forge test -vv
```

---

## Verification

### Command

```bash
FOUNDRY_PROFILE=ci forge test -vv
```

### Expected Output

The property tests report the CI depth, **and** the harness meta-suite is present
and green in the same run:

```
[PASS] testFuzz_PayoutIsFloorOfBTimesQOverS(uint256,uint256,uint256) (runs: 10000, ...)
[PASS] test_FailingUintEqualityRevertsWithValues() (gas: 13780)
```

### Checklist

- [ ] Input-shaping helper handles the full-range overflow case
- [ ] Range is inclusive of `max`
- [ ] Inverted arguments fail loudly
- [ ] Modulo bias documented AND boundaries covered by dedicated unit tests
- [ ] A meta-suite proves each assertion reverts when it should
- [ ] No tolerance assertions on exact arithmetic
- [ ] Each property asserts its own domain membership
- [ ] Reviewer re-ran the suite at CI depth rather than citing the report

---

## Anti-Patterns

### Don't: read `runs: N` as N effective cases

The fuzzer counts invocations. Coverage is a property of the shaping code between
the fuzzer and the assertion, and that code is the repository's.

### Don't: treat a green custom-assert suite as proof the asserts work

A no-op assertion produces exactly the same green. Only a meta-suite distinguishes
the two.

### Don't: audit the oracle and skip the harness

Oracle independence answers "is the expected value computed independently?".
Harness validity answers "did the test run on varied inputs, and would a wrong
answer have been reported?". Both are required; neither implies the other.

### Don't: accept a domain claim from the bounds alone

Bounds that *should* produce an overflow are an argument. An in-test assertion
that the overflow occurred is evidence.

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Property-testing technique — independent oracles for wide
  arithmetic]" — the oracle-side half of the same review.
- `## Learnings`: "[Implementation technique — closing a scoping gap]" — the
  same "green because it is looking at nothing" shape, in the source-gate medium.

### Related Skills

- `independent-oracle-for-512-bit-arithmetic`: verifies the *expected value*;
  this skill verifies the *inputs and the failure channel*.
- `init-code-only-capability-proof`: carries the positive-control discipline for
  absence claims. Step 2 here is that same rule applied to the assertion
  mechanism itself.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction from `/review-sprint sprint-2` |

---

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
  session: cycle-002/sprint-2
```
