---
name: v3-mint-principal-is-bounded-not-exact
description: |
  A Uniswap-v3-style `mint(recipient, tickLower, tickUpper, liquidity, data)`
  call does not consume exactly the token amounts you offered — the pool
  converts your `liquidity` argument into token amounts via its own tick-range
  math, and integer liquidity-unit rounding means the amounts actually pulled
  are equal to or slightly LESS than what you computed as "affordable." A test
  or accounting invariant that asserts `principalBooked == amountOffered` will
  fail by a small, deterministic-but-not-hand-computable remainder (a few
  hundred wei on realistic amounts). Assert the correct property instead:
  `principalBooked <= amountOffered` (never more was pulled than offered) AND
  the shortfall is bounded by a small dust tolerance, not a specific value.
  Apply whenever writing tests or invariants around any code that provisions a
  v3 LP position and tracks cost basis / principal from the caller side.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-7 /implement (GenesisAdversarial.t.sol, POL provisioning)
extraction-date: 2026-08-17
version: 1.0.0
tags:
  - solidity
  - uniswap-v3
  - defi
  - test-design
  - liquidity
---

## Problem

Code offers two token amounts to fund a v3 position (e.g. "transfer 150,000 VUX and 300 WETH into the treasury, then mint"). A test asserts the treasury's booked principal cost-basis equals those exact offered amounts. The assertion fails, off by a few hundred wei, even though nothing is obviously wrong — no revert, no missing transfer, no bug in the code under test.

## Trigger Conditions

### Symptoms

- An `assertEq(bookedPrincipal, offeredAmount, ...)` fails by a small amount (parts-per-quintillion scale on 18-decimal tokens)
- The failure only appears after a real `mint()` against a genuine v3-shaped pool (mocks that just echo inputs back never surface it)
- The delta is consistent across runs with the same inputs, but not obviously derivable without doing the tick/liquidity math by hand

### Error Messages

```
[FAIL: AssertionFailed("... : got 299999999999999999636, expected 300000000000000000000")]
```
(the delta shown, 364 wei in this example, is v3's rounding remainder)

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Uniswap v3 core (or any fork), Foundry |
| Environment | Any test that mints against the real pinned pool bytecode, not a stub |
| Timing | Immediately, on the first assertion after a genuine mint |
| Prerequisites | Position sizing computed by converting "affordable token amounts" into a `liquidity` value before calling `mint` |

## Root Cause

v3's `mint` interface takes `liquidity` (an integer unit of concentrated-liquidity), not token amounts. The caller-side helper that turns "I have X token0 and Y token1" into a `liquidity` value necessarily floors to the largest whole-liquidity-unit that fits, because liquidity is quantized. The pool then computes actual `amount0`/`amount1` owed FROM that floored liquidity — which is always `<=` what continuous math would have required for the exact offered amounts. The gap is real, not a bug, and it varies with tick spacing, current price, and the specific amounts, so it cannot be predicted as a clean constant.

## Solution

### Step 1: Replace an exact-equality assertion with a bound plus a dust check

```solidity
// WRONG — fails nondeterministically-looking on any tick spacing / price combo
assertEq(treasury.polWethPrincipal(), W_POL, "POL principal is founder capital only");

// RIGHT — states the actually-true property, and bounds the known rounding gap
function _assertPolPrincipalIsFounderCapitalOnly() private view {
    assertLe(treasury.polWethPrincipal(), W_POL, "principal never exceeds the offered amount");
    assertLt(W_POL - treasury.polWethPrincipal(), 1e12, "the shortfall is v3 quantization dust");
}
```

The `<=` half is the load-bearing claim for security/accounting properties ("nothing extra was ever booked as principal" — a donation showing up as booked principal would be exactly what *exceeding* the offered amount would look like). The dust bound is a generous, round-number tolerance, not a precisely-derived figure — it exists to catch a real bug (a wildly wrong amount) without being sensitive to the exact rounding remainder.

### Step 2: If the exact remainder matters for other invariants, treat it as retained inventory, not a discrepancy

The token amount the pool did NOT pull stays in the caller's own balance (in this project's case, "treasury-held POL inventory, evented, principal-classified, never revenue") — assert that balance directly rather than trying to reverse-engineer the exact dust from tick math.

## Verification

### Command

```bash
forge test --match-test test_YourPolProvisioningTest -vv
```

### Expected Output

Green, with the dust bound comfortably slack (e.g. observed 364 wei against a 1e12 wei tolerance — four orders of magnitude of margin, confirming the bound isn't accidentally tight).

### Checklist

- [ ] No `assertEq` between an offered token amount and a v3-derived booked principal
- [ ] The `<=` direction is asserted explicitly (catches over-crediting, the security-relevant direction)
- [ ] The dust tolerance is a round, generous constant — not reverse-engineered to match one observed run
- [ ] Retained/un-pulled token amount is separately accounted for, not silently dropped

## Anti-Patterns

### Don't: loosen the assertion to `assertApproxEqAbs` with a tolerance chosen to make THIS run pass

```solidity
// BAD — the tolerance was picked by running the test and copying the observed delta
assertApproxEqAbs(booked, offered, 364, "close enough");
```

This just re-encodes "whatever v3 happened to round to this time" as the spec, and will break again the moment inputs, tick spacing, or price change. Use a bound wide enough to be obviously about "dust," and assert the direction (`<=`) that actually matters.
