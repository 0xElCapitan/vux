---
name: intra-call-ordering-needs-an-interleaved-observer
description: |
  A spec says "consume the authorization BEFORE paying", "burn before transfer",
  "zero the balance before the external call" — an ordering between two steps
  that both happen inside ONE call. Such an ordering leaves **no post-call state
  difference**: after the call returns, both orders produced the identical
  storage, the identical balances, and the identical events. So no post-state
  assertion can cover it, and the suite can be exhaustively green on every
  neighbouring property while being completely blind to this one. Worse, there is
  usually an adjacent test that *appears* to cover it — one that names the same
  lifecycle — and whose mechanism happens to be insensitive to the order. The
  audit move: stop asking "is there a test for this?" and ask "what observer
  could even distinguish the two orders?" The answer is always an actor that runs
  BETWEEN the two steps — a reentrant token hook, a callback, a cross-contract
  call. If no test creates one, the ordering is unverified no matter how many
  tests pass. Confirm with a mutation, then grade by whether an interleaved
  observer is reachable in the deployed system. Apply when auditing CEI ordering,
  one-shot/nonce consumption, burn-before-pay, or any accepted "A before B"
  inside a single function.
loa-agent: auditing-security
extracted-from: cycle-002 / sprint-5 / /review-sprint sprint-5
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - security-audit
  - mutation-testing
  - reentrancy
  - checks-effects-interactions
  - test-coverage
  - solidity
  - callback-authentication
---

## Problem

The accepted design states an ordering as a security property:

> the callback **consumes it (resets it to `NONE`) after validation and before
> making any token payment**

The implementation is correct — `delete _ctx;` sits three lines above the
transfers. The suite has 349 passing tests, including a whole file dedicated to
the callback lifecycle with nine named rejection classes and a positive control.
A reviewer asked to "independently verify that authorization is consumed before
payment" reads those three lines, sees the ordering, sees the green suite, and
concludes it is verified.

It is not. **Zero tests exercise it.** Moving the consume to *after* both
transfers leaves all 349 tests passing.

The trap is that a test which looks exactly like the coverage exists. The
duplicate-callback test — the one that proves the authorization is single-use —
cannot detect the change, because under *both* orders the first callback has
finished consuming by the time it returns, so the second callback finds `NONE`
either way. The test that names the one-shot lifecycle is insensitive to half of
it.

## Trigger Conditions

### Symptoms

- An accepted requirement of the form "do A before B", where A and B are both
  inside one function body.
- The property is cited in review/audit scope, and the natural evidence offered
  is *the source lines* ("consume is above pay") plus a green suite.
- A nearby test names the same mechanism (the same lifecycle, guard, or nonce)
  and is offered as covering it.

### When to apply

- CEI ordering audits: state update before external call.
- One-shot authorization / nonce / flag consumption before a payment or transfer.
- Burn-before-pay, debit-before-credit, zero-before-send.
- Any "the order is the security property, not a stylistic choice" claim.

### When this does NOT apply

- Orderings whose steps span *different transactions* — those do leave a
  distinguishable intermediate state, and ordinary tests can observe it.
- Orderings where step B is itself observable and order-dependent (B reads what A
  wrote), so a post-state assertion genuinely differs between the two orders.

## Root Cause

Test suites assert on **post-call state**: storage reads, balance deltas, emitted
logs, revert selectors. An intra-call ordering is precisely the class of property
that post-call state cannot express, because both orders converge to the same
final state. The information distinguishing them exists only *during* the call,
in the window between A and B.

So the coverage question is not "did someone write a test?" — it is "does any
test place an observer inside that window?" For an ordering guarding reentrancy,
the observer is a hostile token hook or callback firing during step B and looking
at the state step A was supposed to have already changed.

If nothing re-enters, the two orders are observationally equivalent, and green
means nothing.

## Solution

### 1. Ask what could distinguish the orders, before looking for a test

Write down the observer explicitly: *"only an actor that executes between the
consume and the transfer can tell these apart — i.e. a reentrant callback during
`safeTransfer`."* This immediately converts a vague coverage question into a
searchable one: does any test cause re-entry during the payment?

### 2. Confirm with a mutation, on a copy

Swap the order and run the FULL suite. Guard the mutation the way
[[verify-the-mutant-not-the-verdict]] requires — assert the anchor matched
exactly once before believing any result:

```js
const occurrences = src.split(from).length - 1;
if (occurrences !== 1) { console.error(`ANCHOR MISS: ${occurrences}`); process.exit(3); }
```

A suite that stays fully green has told you the property is unverified. Run the
mutation against a scratchpad copy whose subject fingerprint you verified first,
so a no-mutation mandate on the real tree is preserved:

```bash
cp -r src test script vendor foundry.toml remappings.txt "$SCRATCH/probe/"
(cd "$SCRATCH/probe" && xargs -a A.txt sha256sum | LC_ALL=C sort -k2 | sha256sum)
# must equal the subject fingerprint before you mutate anything
```

### 3. Grade by reachability of the observer, not by the coverage gap

The gap is only as severe as the interleaving it fails to exclude. Establish
whether an observer can exist **in the deployed system**:

- Are the counterparties fixed? (constructor immutables vs. caller-supplied)
- Do the tokens have transfer hooks? Check for `_update` / `_beforeTokenTransfer`
  overrides, ERC-777/1363 hooks, or a callback interface — not just the token's
  reputation.

If every counterparty is an immutable, hook-free token, the ordering is
defence-in-depth against an unreachable case: report it as a **LOW evidence gap
with a named remediation**, not as a callback-authentication flaw. If any
counterparty is caller-supplied or hook-bearing, the same missing test is a real
finding.

### 4. Name the cheapest remediation

Look for an interleaving facility the repo already owns. Test doubles often carry
an unused re-entry hook from an earlier sprint:

```solidity
if (reentryCallTarget != address(0)) {
    (address t, bytes memory d) = (reentryCallTarget, reentryCallData);
    reentryCallTarget = address(0);      // one-shot
    (bool ok, bytes memory err) = t.call(d);
    if (!ok) { /* bubble, so a missing guard cannot look like a pass */ }
}
```

One negative test driving re-entry from inside the payment closes the gap.

## Verification

Confirmed live on cycle-002 sprint-5:

| step | result |
|---|---|
| Mutation M2 — move `delete _ctx` after both `safeTransfer` calls | **349 passed / 0 failed** — property unverified |
| Same battery, 7 other mutations (caller check, amount cap, require-consumed, fee ordering, fee routing, slippage bound, liquidity conservativeness) | all **caught**, 1–20 failures each |
| Observer reachability: `grep "_update\|_beforeTokenTransfer" src/VUX.sol` | none — `contract VUX is ERC20, ERC20Permit`, no hook |
| Counterparty fixity | both payment tokens are constructor immutables |

The 7-of-8 result is what makes the finding credible: the suite is demonstrably
discriminating everywhere else, so the single blind spot is a property of the
*ordering*, not of a weak suite.

## Anti-Patterns

- **Reading the three lines and calling it verified.** Source inspection proves
  the code is correct today; it proves nothing about whether a regression would
  be caught. Both facts belong in the report, stated separately.
- **Accepting the adjacent test as coverage because it names the mechanism.** The
  duplicate-callback test names the one-shot lifecycle and cannot see the
  ordering half. Check the test's *mechanism*, not its title.
- **Grading it as a callback-authentication flaw.** The implementation satisfies
  the requirement. The gap is in evidence. Severity follows observer
  reachability.
- **Mutating the tree under review.** Copy first, verify the copy reproduces the
  subject fingerprint, mutate there, and re-derive the fingerprint at exit.
- **Concluding "no test needed" from token reputation.** "WETH has no hooks" is
  right; "the tokens are fine" is not an argument. Check the override list.

## Related Resources

- Checks-Effects-Interactions — the general family this ordering belongs to.
- Uniswap v3-core callback contract: pool → one callback → payment verified
  before the pool's call returns.

## Related Memory

- [[verify-the-mutant-not-the-verdict]] — prerequisite: prove the mutant landed
  before reading any conclusion from the run. This skill says *what* to mutate;
  that one says how to trust the mutation.
- [[fuzz-harness-validity-audit]] — sibling "green because it is looking at
  nothing" failure, in the fuzz medium rather than the ordering medium.
- [[post-run-properties-are-not-invariants]] — same family: a property observed
  only at the wrong moment is not the property.
- [[absence-scans-need-a-negative-control]] — the control discipline this applies
  to a suite rather than to a scan.

## Changelog

- 1.0.0 (2026-08-14) — extracted from cycle-002 / sprint-5 `/review-sprint`.

## Metadata (Auto-Generated)

- Applications: 1
- Success rate: 1/1
- Last applied: 2026-08-14
