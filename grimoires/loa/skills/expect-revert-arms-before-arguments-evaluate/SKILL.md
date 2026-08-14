---
name: expect-revert-arms-before-arguments-evaluate
description: |
  Foundry's `vm.expectRevert` applies to the NEXT call the test frame makes — but
  Solidity evaluates a call's arguments BEFORE the call itself, so an argument
  that is a view call on another contract becomes that "next call". It does not
  revert, so the expectation is consumed and satisfied-as-failed, and the test
  reports `next call did not revert as expected` about a call that demonstrably
  does revert. The message accuses the wrong statement, which sends you to read
  the contract instead of the test. Same shape applies to `vm.prank` /
  `vm.startPrank` and any other cheatcode that arms "the next call". Apply when a
  negative test fails while the behaviour it asserts is manually reproducible, or
  when a `vm.expectRevert` test starts failing after someone inlines a getter
  into an argument. Fix by hoisting every external call out of the argument list
  into a local, on the line BEFORE the cheatcode.
loa-agent: implementing-tasks
extracted-from: cycle-002 / sprint-5 task 5.2 (buyVuxForPol sqrtPriceLimitX96 negative test)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - foundry
  - solidity
  - cheatcodes
  - test-integrity
  - negative-tests
  - evaluation-order
---

## Problem

A negative test asserts that passing the pool's current price as a swap's price
limit is rejected. The pool's own `require(..., 'SPL')` makes this true, and it
reproduces by hand. The test fails anyway:

```
[FAIL: next call did not revert as expected] test_BuyVuxForPolEnforcesSqrtPriceLimit()
```

The message says the call did not revert. The call does revert. Sixteen sibling
tests in the same file pass, so the fixture, the wiring, and the treasury are all
demonstrably fine — which makes the natural next move "read the contract again",
and that is a dead end.

## Trigger Conditions

### Symptoms

- `next call did not revert as expected` for behaviour you can reproduce
  manually or in a `-vvvv` trace.
- The test's arguments include a getter: `pool.slot0()`, `token.balanceOf(...)`,
  a fixture helper that reads chain state, `vm.getBlockTimestamp()`.
- A previously green negative test breaks after a refactor that inlined a local
  into the call.
- A `vm.prank`ed call executes as the test contract rather than the pranked
  address, with an argument-position getter in between.

### Error messages

```
[FAIL: next call did not revert as expected]
```

or, for the prank variant, an authorization assertion that fails because
`msg.sender` was not who the test intended.

### Context

| Context | Value |
|---|---|
| Technology | Foundry (`forge test`), Solidity `>=0.8` |
| Timing | Negative/authorization tests whose arguments read chain state |
| Prerequisites | An argument expression that performs an external call |

## Root Cause

Two evaluation orders that are each obvious in isolation, and wrong together:

1. Solidity evaluates argument expressions **before** issuing the call.
2. `vm.expectRevert` arms an expectation against the **next call** the frame
   makes.

So in

```solidity
vm.expectRevert(...);
treasury.buyVuxForPol(1 ether, 1, _sqrtPriceX96());   // helper does pool.slot0()
```

the ordering the EVM actually sees is: arm → `staticcall pool.slot0()` →
`call treasury.buyVuxForPol`. The `slot0()` staticcall is the next call. It
returns cleanly, the expectation is checked against *it*, and it fails. The
treasury call then runs unwatched and reverts, which is invisible because the
test has already failed.

The cheatcode is not broken and Solidity is not broken. The trap is that the test
source *reads* as "expect the treasury call to revert" while the bytecode says
something else, and nothing in the error message hints at the gap.

Note the subtlety in which helpers are safe: a `pure`/`internal` helper is
inlined and performs no call, so `_limitFor(!vuxIsToken0)` in the same file is
fine. A plain storage read (`vuxIsToken0`) is fine. Only an **external** call in
argument position bites — which is why the same file can have safe and unsafe
uses of structurally identical-looking helpers.

## Solution

### Step 1: Hoist every external call out of the argument list

```solidity
// Read the price BEFORE arming the expectation: an argument that is itself an
// external call would consume the `expectRevert` instead.
uint160 limitAtCurrentPrice = _sqrtPriceX96();

vm.expectRevert(abi.encodeWithSignature("Error(string)", "SPL"));
treasury.buyVuxForPol(1 ether, 1, limitAtCurrentPrice);
```

### Step 2: Make the cheatcode the last statement before the call

Adopt it as a rule rather than a fix: between `vm.expectRevert` (or `vm.prank`)
and the call under test, allow **nothing** — no helper, no getter, no
`string.concat`, no assertion.

### Step 3: Audit the sibling tests in the same file

The bug is per-call-site, so a passing neighbour proves nothing about the one
that failed. Grep the file for cheatcodes followed by a call whose arguments
contain a `.`:

```bash
grep -n -A1 "vm.expectRevert\|vm.prank\|_expectUnauthorized" test/**/*.t.sol \
  | grep -E "\(\s*[a-zA-Z_]+\.[a-zA-Z_]+\("
```

## Verification

### Command

```bash
forge test --match-test test_BuyVuxForPolEnforcesSqrtPriceLimit -vvvv
```

### Expected output

The trace shows the treasury call issued directly after the cheatcode, with no
intervening `staticcall`, and the suite passes:

```
[PASS] test_BuyVuxForPolEnforcesSqrtPriceLimit() (gas: 488667)
```

### Checklist

- [ ] No external call appears in the argument list of a cheatcode-armed call.
- [ ] The cheatcode is the immediately preceding statement.
- [ ] The test was seen to FAIL for the right reason before the fix — flip the
      expected revert data and confirm it fails on the payload, not on "did not
      revert", so the fixed test is known to be watching the right call.

## Anti-Patterns

### Don't: read state inline "for readability"

```solidity
// BAD - reads clearly, tests the wrong call.
vm.expectRevert(Foo.BadPrice.selector);
target.doThing(pool.slot0Price(), token.balanceOf(user));
```

### Don't: conclude the contract is wrong

The message names the call that did not revert, and it is not the call you wrote
the test about. Check the test's evaluation order before re-reading the
implementation — this failure mode costs far more time in the contract than in
the test.

### Don't: fix it by deleting the assertion's specificity

```solidity
// BAD - "make it pass" by removing the expectation's payload check. Now the
// test tolerates ANY revert, including the ones that mean the fixture broke.
vm.expectRevert();
```

## Related Memory

- `grimoires/loa/a2a/sprint-5/reviewer.md` — AC-5, the `sqrtPriceLimitX96`
  enforcement test.
- [[optimizer-folds-context-reads-across-cheatcodes]] — sibling failure mode:
  there the compiler's right to fold `block.timestamp` silently defeats
  `vm.warp`; here Solidity's argument-evaluation order silently defeats
  `vm.expectRevert`. Both are cases where the surrounding language's ordering
  contract, not the cheatcode, is what breaks the test — and both fail silently
  or with a misdirected message.
- [[post-run-properties-are-not-invariants]] — same family of "the harness
  reports a problem in the wrong place", for Foundry's invariant engine.
