---
name: independent-oracle-for-512-bit-arithmetic
description: |
  Property-testing `floor(a*b/c)` implemented with a 512-bit intermediate
  (OpenZeppelin `Math.mulDiv`, Uniswap `FullMath.mulDiv`) has a trap: the obvious
  oracle is the same function, which proves only that the implementation equals
  itself. Split the domain instead. Where `a*b` fits in 256 bits, compute the
  expectation natively. Where it does not, use the decomposition
  `a = A*c + rem` so `floor(a*b/c) = A*b + floor(rem*b/c)` — computable without
  ever forming the overflowing product — and ASSERT the run is in the overflow
  domain rather than assuming it, or the "overflow test" silently degrades into
  a duplicate of the easy one. Includes the companion trap for scale-invariant
  formulas: most inputs cannot distinguish a correct implementation from a wrong
  one, so unit examples must be chosen to discriminate. Apply to pro-rata
  redemption, share/asset conversion, fee splits, or any ratio math on token
  amounts.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-2 /implement (HardReserve redemption payout = floor(B*q/S), AC-3)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - solidity
  - foundry
  - fuzzing
  - property-testing
  - arithmetic
  - overflow
  - defi
  - test-design
---

## Problem

You have `payout = floor(B * q / S)` and you must property-test it across the
whole input domain, including the region where `B * q` exceeds `uint256`. Two
plausible test designs both fail to prove anything:

1. **`assertEq(payout, Math.mulDiv(b, q, s))`** — the oracle is the code under
   test. Green means the implementation is self-consistent. A wrong rounding
   direction, a swapped argument, or a bad `mulDiv` vendoring all pass.
2. **`assertEq(payout, (b * q) / s)` over the full range** — reverts with a
   panic for large inputs, so you clamp the bounds until it stops reverting, and
   the test now silently covers only the domain a naive implementation would
   have handled anyway. The very inputs that justify the 512-bit intermediate go
   untested.

The second failure is the dangerous one: the suite looks thorough and its
coverage claim is false. Reverting on large `B * q` is not a safety property in a
redemption path — it is a denial of the exit right precisely when backing is
largest.

---

## Trigger Conditions

### Symptoms

- Property-testing a formula that uses `Math.mulDiv` / `FullMath.mulDiv`.
- You cannot express the expected value without repeating the implementation.
- Bounds in a fuzz test were tightened until arithmetic panics stopped, with no
  record of what domain that removed.
- A requirement says "must not use a raw `a * b` that can overflow" and you need
  to demonstrate compliance rather than assert it.

### Error Messages

```
[FAIL: panic: arithmetic underflow or overflow (0x11)] testFuzz_Payout(uint256,uint256,uint256)
```

Appearing in the **test's own oracle**, not in the contract.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity ≥0.8 + Foundry fuzzing; OZ `Math.mulDiv` or Uniswap `FullMath` |
| Timing | Writing the property suite for pro-rata / ratio math |
| Prerequisites | Realistic token magnitudes where `a*b` can exceed `2^256` |

---

## Root Cause

`floor(a*b/c)` is well defined for every `a, b, c` with `c > 0`, but the
intermediate `a*b` is not representable in 256 bits. A 512-bit `mulDiv` exists
exactly to make the well-defined answer reachable. A test oracle written in
native `uint256` arithmetic therefore cannot cover the domain that motivates the
implementation — and the fix for the resulting panic (tighter bounds) removes
that domain from coverage without leaving a trace.

---

## Solution

### Step 1: Native oracle for the representable domain

Bound so the product provably fits, and compute the expectation with plain
arithmetic — genuinely independent of the code under test.

```solidity
function testFuzz_PayoutIsFloorOfBTimesQOverS(uint256 bSeed, uint256 supplySeed, uint256 qSeed) public {
    // b <= 1e40 and q <= ~1e30 keeps b*q <= 1e70, inside 256 bits (~1.16e77).
    uint256 b     = bound(bSeed, 0, 1e40);
    uint256 extra = bound(supplySeed, 0, 1e30);
    ...
    uint256 s = token.totalSupply();
    uint256 q = bound(qSeed, 0, s - S_MIN);

    uint256 expected = (b * q) / s;                 // <- independent oracle
    uint256 payout   = reserve.redeem(q, holder);

    assertEq(payout, expected, "payout = floor(B x q / S)");

    // Both rounding bounds, not just the value: pins floor specifically.
    assertLe(payout * s, b * q,          "never exceeds the exact pro-rata share");
    assertGt((payout + 1) * s, b * q,    "and is the greatest such value");
}
```

### Step 2: Decomposition oracle for the overflow domain

Write `b = A*s + rem` with `rem < s`. Then

```
floor(b*q/s) = floor((A*s + rem)*q / s) = A*q + floor(rem*q/s)
```

`A*q` and `rem*q` stay inside 256 bits in the chosen ranges while `b*q` does not.

```solidity
function testFuzz_PayoutIsExactWhenBTimesQOverflowsUint256(
    uint256 aSeed, uint256 remSeed, uint256 qSeed
) public {
    _mint(address(this), 1e26);              // s ~ 1e26
    uint256 s   = token.totalSupply();
    uint256 a   = bound(aSeed,   1e28, 1e29);
    uint256 rem = bound(remSeed, 0, s - 1);
    uint256 b   = a * s + rem;               // ~1e53, fits
    uint256 q   = bound(qSeed,   1e25, s - S_MIN);

    // ASSERT the domain. Without this the test can silently drift into the easy case.
    assertTrue(b != 0 && q > type(uint256).max / b, "domain check: B x q genuinely overflows uint256");

    uint256 expected = a * q + (rem * q) / s;   // never forms b*q
    assertEq(reserve.redeem(q, holder), expected, "exact floor with a 512-bit intermediate");
}
```

The `assertTrue` domain check is the load-bearing line. Ranges get edited; a
test that only *intends* to be in the overflow region will quietly stop being
there, and nothing will fail.

### Step 3: Show the naive implementation failing on the same inputs

Turns "we used mulDiv" into a demonstration. The wrapper is needed because a
bare `b * q` in the test body aborts the test instead of being observed.

```solidity
contract NaiveMath {
    function product(uint256 a, uint256 b) external pure returns (uint256) { return a * b; }
}

function test_NaiveProductRevertsWhereRedeemSucceeds() public {
    ...
    NaiveMath naive = new NaiveMath();
    vm.expectRevert();          // panic 0x11
    naive.product(b, q);

    assertEq(reserve.redeem(q, holder), 1e28 * q, "exact payout at a scale a naive product cannot express");
}
```

### Step 4: Choose DISCRIMINATING unit examples

Pro-rata is scale-invariant, so a pre-state vs post-state error is invisible for
most inputs. With `B=100, S=10, q=4` both a correct implementation and one that
recomputes after the burn return 40 — the test passes while asserting nothing
about ordering. Pick the input where the two disagree, and assert both the right
answer and the absence of the wrong one.

```solidity
// B=10, S=4, q=2:  pre-state -> floor(10*2/4) = 5
//                  post-burn -> floor(10*2/2) = 10
function test_PayoutUsesPreRedemptionStateNotPostBurnState() public {
    _shrinkSupplyTo(4);
    weth.mint(address(reserve), 10);

    uint256 payout = reserve.redeem(2, address(this));

    assertEq(payout, 5,      "floor(B x q / S) on PRE-redemption B and S");
    assertNotEq(payout, 10,  "post-burn state would have paid double");
}
```

Same technique for the rounding direction: `B=10, S=3, q=1` gives 3 under floor
and 4 under ceil — a case where the remainder is observable.

### Step 5: Run the property suite at real fuzz depth in CI

```toml
[profile.ci]        # inherits [profile.default]; differs only in depth
fuzz = { runs = 10_000 }
```

Keep the default low so the local cycle stays fast — a suite developers avoid
running costs more correctness than the extra depth buys.

---

## Verification

### Command

```bash
forge test --match-path 'test/**/*Redemption*'
FOUNDRY_PROFILE=ci forge test --match-path 'test/**/*Redemption*'
```

### Expected Output

```
[PASS] testFuzz_PayoutIsFloorOfBTimesQOverS(uint256,uint256,uint256) (runs: 10000)
[PASS] testFuzz_PayoutIsExactWhenBTimesQOverflowsUint256(uint256,uint256,uint256) (runs: 10000)
[PASS] test_NaiveProductRevertsWhereRedeemSucceeds()
[PASS] test_PayoutUsesPreRedemptionStateNotPostBurnState()
```

### Checklist

- [ ] No test uses `mulDiv` (or the contract's own view) as its oracle
- [ ] The native-domain bounds are justified in a comment, with the product ceiling shown
- [ ] The overflow-domain test asserts `q > type(uint256).max / b`
- [ ] Both rounding bounds asserted, not just the value
- [ ] Unit examples chosen so a wrong implementation returns a *different* number
- [ ] Conservation asserted too: recipient gain == source loss, token total supply unchanged
- [ ] CI runs the properties at ≥10,000 runs

---

## Anti-Patterns

### Don't: use the implementation as its own oracle

```solidity
// BAD — proves self-consistency and nothing else.
assertEq(reserve.redeem(q, to), Math.mulDiv(b, q, s), "payout");
assertEq(reserve.redeem(q, to), reserve.previewRedeem(q), "payout");  // same function twice
```

`previewRedeem == redeem` is still worth asserting — as a *consistency* property,
labelled as such. It is not evidence of correctness.

### Don't: shrink bounds until the panic stops

```solidity
// BAD — the oracle overflowed, so the domain was cut. The suite now covers
// exactly the range a naive implementation would have handled, with no record.
uint256 b = bound(bSeed, 0, 1e18);   // "fixes" the panic
```

If you must narrow, say what was removed and cover it another way.

### Don't: rely on `vm.assume` for a wide restriction

Discarding most runs turns a nominal 10,000 into a handful of effective cases.
Bound (or construct) into the domain instead.

### Don't: trust a passing example on scale-invariant math

If the correct and the incorrect implementation return the same number for your
input, the test is decoration. Derive the discriminating case before writing the
assertion.

---

## Related Resources

- OpenZeppelin `utils/math/Math.sol` — `mulDiv` (512-bit intermediate, floor)
- Uniswap v3-core `libraries/FullMath.sol` — the same algorithm under a different name
- Remco Bloemen, "Math — Full Multiply" — the derivation behind both

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Property-testing technique — independent oracles for wide arithmetic]" and "[Test-design technique — discriminating examples over passing ones]"
- `## Decision Log`: 2026-08-11 `[implement sprint-2]` — `Math.mulDiv` selected; reverting on large `B*q` classified as a denial of the exit right, not a safety property

### Related Skills

- [`init-code-only-capability-proof`](../init-code-only-capability-proof/SKILL.md): sibling from the same sprint — both are about tests whose green must not be producible by the test being weak

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction (absorbs the discriminating-example principle for scale-invariant formulas) |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: implementing-tasks
  phase: /implement sprint-2
  session: cycle-002-sprint-2
```
