---
name: monotone-domain-bound-replaces-a-forbidden-import
description: |
  A formula you must implement depends on a helper you are not allowed to import
  — the library lives in a different compilation unit, or copying it would breach
  a provenance boundary, or porting it would silently change its arithmetic. The
  reflex is to port, vendor, or re-derive it, and all three are expensive and
  risky. Often you do not need the exact value: if the formula is MONOTONE in the
  unknown and the result only has to be safe in one direction (affordable, under
  a cap, within a committed maximum), substituting the unknown's DOMAIN bound —
  the direction that moves the result the safe way — turns "I may not import
  this" into "I do not need it". The discipline that makes it evidence rather
  than hand-waving is two-part: state the monotonicity argument per input, and
  then MEASURE the resulting slack on a realistic case instead of reasoning about
  it. Apply when a cross-compilation-unit or vendored-source boundary blocks a
  math helper (Uniswap `TickMath`/`SqrtPriceMath`, curve libraries, fixed-point
  exp/log), and when the quantity you need is a bound rather than an equality.
loa-agent: implementing-tasks
extracted-from: cycle-002 / sprint-5 task 5.1 (POL liquidity from committed amounts)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - solidity
  - provenance
  - compilation-units
  - uniswap-v3
  - numerical-bounds
  - dependency-boundary
  - implementation-technique
---

## Problem

An accepted API takes token *amounts* and the underlying protocol call takes a
*liquidity unit*, so the implementation must invert the protocol's own charge
formula:

```
amount0 = ceil(L * Q96 * (sqrtB - sqrtP) / (sqrtB * sqrtP))
amount1 = ceil(L * (sqrtP - sqrtA) / Q96)
```

Inverting needs `sqrtA` and `sqrtB` — the position's tick bounds as sqrt prices,
i.e. `sqrtRatioAtTick`. The vendored library that computes it was unavailable
three different ways at once:

- it compiles in a **different compilation unit** (`=0.7.6`) whose wrapping
  arithmetic is deliberately never ported to the `0.8.x` unit doing the work;
- copying it in would be exactly the "no copied third-party helper code" the
  provenance boundary forbids;
- re-deriving `sqrt(1.0001^tick)` from scratch means a fixed-point exp/log
  routine — a large, un-reviewed numerical surface inside a monetary contract.

The obvious escape hatches are all bad: port the library (provenance breach),
hardcode the two constants (freezes a deployment-time fact and breaks for any
other tick spacing), or add a view to a neighbouring contract (mutates already-
accepted genesis infrastructure for a convenience).

## Trigger Conditions

### Symptoms

- You need one helper function out of a vendored library, and importing it is
  blocked by a compilation-unit split, a licence/provenance census, or a pragma
  incompatibility.
- The helper computes an intermediate you only use to derive a *bound* — a
  maximum spend, an affordable size, a cap check — not a value you must report.
- You are about to write "just this one function" as a port, or to hardcode its
  output as a magic constant.

### Error messages

There is no error. That is the hazard: every escape hatch compiles. The failure
shows up later as a provenance-gate violation, a frozen-constant mismatch, or a
magic constant that is wrong on the next deployment.

### Context

| Context | Value |
|---|---|
| Technology | Solidity, multi-unit Foundry builds, vendored AMM/curve math |
| Timing | Implementing against an accepted API signature you cannot change |
| Prerequisites | The formula is monotone in the unknown, and one direction is safe |

## Root Cause

Two separate things get conflated: **the value** the helper computes, and **the
property** you actually need from it. The helper returns an exact `sqrtA`; what
the code needs is "a liquidity the caller can certainly afford". Those are not
the same requirement, and only the first one needs the library.

Once separated, the unknown's *domain* is usually already known from the
protocol's own invariants — here, every valid price lies in
`[MIN_SQRT_RATIO, MAX_SQRT_RATIO)`, and every position's bounds lie inside it.

## Solution

### Step 1: Identify the direction that is safe

Write down what happens if the estimate is wrong each way. Here, over-estimating
liquidity makes the pool demand more than the caller committed and the operation
reverts; under-estimating simply leaves a little unspent. So **under-estimate**.

### Step 2: Prove the monotonicity, per input, in the code

Not in a commit message — in the source, where the next reader is.

```
sqrtB appears as   x / (x - p)      which DECREASES in x
sqrtA appears as   1 / (p - a)      which DECREASES as a falls
```

Therefore `sqrtA -> MIN_SQRT_RATIO` and `sqrtB -> MAX_SQRT_RATIO` push both
estimates **down**, hence their minimum down, hence the result is always
affordable.

### Step 3: Implement against the domain bounds

```solidity
// The endpoints of the price domain, read as facts of the space the verified
// pool operates in — not as reused implementation. No library is imported, and
// none could be: the vendored TickMath compiles in the other (=0.7.6) unit.
uint160 private constant MIN_SQRT_RATIO = 4295128739;
uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

function _affordableLiquidity(uint256 amount0, uint256 amount1, uint160 sqrtPriceX96)
    private pure returns (uint256)
{
    // Guard the division by zero the domain endpoints introduce.
    if (sqrtPriceX96 <= MIN_SQRT_RATIO || sqrtPriceX96 >= MAX_SQRT_RATIO) revert OutOfRange();

    uint256 from0 = Math.mulDiv(
        amount0, Math.mulDiv(sqrtPriceX96, MAX_SQRT_RATIO, MAX_SQRT_RATIO - sqrtPriceX96), Q96
    );
    uint256 from1 = Math.mulDiv(amount1, Q96, sqrtPriceX96 - MIN_SQRT_RATIO);
    return from0 < from1 ? from0 : from1;
}
```

### Step 4: Check the degenerate regimes explicitly

The substitution must stay safe where the formula changes shape. Here, if the
price were ever outside the position's range the true charge is one-sided and
*smaller*, so the estimate is still an under-estimate — worth one sentence in the
docstring, because a reviewer will ask.

### Step 5: MEASURE the slack — do not argue it

This is the step that converts the technique into evidence. Run the real case
and read the number out of the run:

| quantity | committed | consumed | slack |
|---|---|---|---|
| VUX | `150_000e18` | `149999999999999999999981` | **19 wei** |
| WETH | `300e18` | `299999999999999999636` | **364 wei** |

A relative error bounded by `sqrtA/sqrtP + sqrtP/sqrtB` is a true statement that
tells a reviewer nothing. "19 wei on a 150,000-unit position" ends the argument.

## Verification

### Command

```bash
forge test --match-test test_QuantizationDustStaysPrincipalSideInventory -vv
forge script script/PolVyrfE2E.s.sol:PolVyrfE2E --fork-url http://127.0.0.1:8545 -vvvv
```

### Expected output

The operation never reverts on the committed maxima, and the unspent remainder is
observable and accounted:

```
polVuxPrincipal  = 149999999999999999999981   (dust 19 wei)
polWethPrincipal = 299999999999999999636      (dust 364 wei)
```

### Checklist

- [ ] The safe direction is named in the code, not just chosen.
- [ ] Monotonicity is stated per input, with the algebraic reason.
- [ ] Degenerate regimes (out-of-range, endpoint prices) are covered or guarded.
- [ ] Division-by-zero at the substituted endpoints is guarded with a typed error.
- [ ] The slack is **measured** on a realistic case and recorded as a number.
- [ ] The unspent remainder has a defined accounting treatment (here: stays
      principal-side inventory, never revenue) rather than being ignored.

## Anti-Patterns

### Don't: port "just this one function"

```solidity
// BAD - a 0.7.6 library that relies on wrapping arithmetic, pasted into a
// 0.8.x unit. It compiles. It reverts at runtime on the first overflow, and it
// is a provenance-census violation whether or not it works.
function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) { ... }
```

### Don't: hardcode the helper's output

```solidity
// BAD - correct for exactly one tickSpacing, silently wrong for any other, and
// freezes a deployment-time fact the architecture deliberately left open.
uint160 private constant SQRT_LOWER = 4306310044;
```

### Don't: claim the error bound instead of measuring it

"The relative error is of order 1e-18" is unfalsifiable in review. The measured
wei count is checkable, and it is what tells you whether the substitution is
actually acceptable — an early estimate on this same problem was off by four
orders of magnitude in the pessimistic direction.

### Don't: reach for the substitution when you need an equality

If the value is reported, stored, or compared for equality, a bound is not a
substitute. This technique applies only where one-directional safety is the
whole requirement.

## Related Memory

- NOTES.md Decision Log, 2026-08-14 `[implement sprint-5]` — the liquidity
  inversion decision and its measured slack.
- `grimoires/loa/a2a/sprint-5/reviewer.md` — "Technical highlights", the
  direction proof as delivered to review.
- [[independent-oracle-for-512-bit-arithmetic]] — the complement: when you must
  prove a ratio computation *exactly*, do not let the implementation be its own
  oracle. This skill is the other case, where an exact value was never required.
- [[inherited-build-flags-reach-frozen-units]] — the same multi-unit split is
  what makes the library unreachable here; that skill covers the build-config
  hazard the split creates.
