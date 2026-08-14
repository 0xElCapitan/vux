---
name: reentrancy-lives-between-your-calls-not-inside-them
description: |
  When one of your functions calls a stateful external protocol several times —
  `poke; collect; …; burn; collect` — reentrancy analysis reflexively goes to the
  callbacks. That is usually the wrong place: mature protocols (Uniswap v3-core,
  Aave, Compound) carry their OWN reentrancy lock, so a callback re-entering them
  reverts on their guard, not yours. The unprotected surface is the GAP between
  two of your calls to them, where their lock is released and yours (if any) does
  not extend to third parties. Any external call you make in that gap — a token
  transfer, a burn, a notification — is a door, and an invariant that is
  "mid-flight" across the gap can be broken through it. The trap that makes this
  a false negative: your first PoC reverts with the protocol's lock error and you
  read that as "protected", when it only means you aimed at the wrong instant.
  Re-aim at the gap using a self-re-arming, invocation-counting re-entry, and
  prove the result with a conservation differential rather than a revert. Then
  grade by whether a re-entrant counterparty actually exists — read the token's
  source for a transfer hook, never its reputation. Apply when auditing any
  multi-step interaction with an external protocol where classification, pricing,
  or accounting depends on the order of your own calls.
loa-agent: auditing-security
extracted-from: cycle-002 / sprint-5 / /audit-sprint sprint-5
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - security-audit
  - reentrancy
  - checks-effects-interactions
  - uniswap-v3
  - defi-accounting
  - proof-of-concept
  - solidity
---

## Problem

A treasury withdraws liquidity in one function, and the fee/principal separation
is *ordering*, not accounting:

```
poke (burn 0)  ->  collect fees  ->  classify fees  ->  burn(liquidity)  ->  collect principal  ->  book
```

The design document justifies the whole separation with one sentence:

> Because the whole sequence executes in one transaction, no swap can interleave,
> so **zero new fees can accrue** between the fee-collect and the principal-credit.

That is stated unconditionally. It is not. "Classify fees" is two **external token
calls** — burn the token-denominated leg, transfer the other leg to a reserve —
and they sit between `collect` and `burn(liquidity)`, where the pool's own lock
has been released. A re-entrant token that swaps the pool there moves
`feeGrowthInside` after the poke and before the principal burn, so the principal
collect sweeps the new fees and books them as principal.

The reason this survives review is that the callbacks — the place everyone looks
— are genuinely safe, and safe for a reason that *masks the real window*.

## Trigger Conditions

### Symptoms

- A function makes two or more calls into the same stateful external protocol,
  and makes its own external calls in between.
- A design doc justifies an ordering with "atomic", "single transaction", "nothing
  can interleave", or "no callback exists on this function".
- The protocol's callbacks are well-defended (context gates, caller checks) and the
  audit narrative concentrates there.
- Your first re-entrancy PoC reverts with the *external protocol's* guard string
  (`LOK`, `ReentrancyGuard`, `1` in Aave) rather than yours.

### When to apply

- LP position management (mint/increase/decrease/collect against a v3-style pool).
- Any harvest/compound/settle routine that reads, then disposes, then re-reads an
  external protocol's accounting.
- Lending-protocol interactions that deposit, then transfer, then withdraw.
- Any place where "the order of my own calls" carries a classification or pricing
  meaning.

### When this does NOT apply

- Single-call interactions — there is no gap.
- Sequences with no external call of your own between the protocol calls: with
  nothing to re-enter through, the gap has no door.
- Systems where every counterparty is a fixed, audited, hook-free contract AND that
  is a permanent property rather than an upgradeable external dependency. (Say
  which, explicitly — this is the whole severity argument.)

## Root Cause

Two different locks are in play and they cover different spans:

| span | protected by |
|---|---|
| inside `pool.mint` / `collect` / `burn` / `swap`, including their callbacks | **the pool's** `lock` modifier |
| inside your `nonReentrant` function, against re-entry *into you* | your guard |
| **between two of your calls to the pool** | **nothing** |

Your `nonReentrant` stops a re-entrant token from calling *you* back. It does
nothing to stop it calling the *pool* directly. And the pool's lock is released
the moment `collect` returns. So the gap is covered by neither guard, and any
invariant that is mid-flight across it — here "`tokensOwed` holds only fees" — is
exposed for exactly that window.

## Solution

### 1. Read the external protocol's lock coverage from the pinned source

Do not assume it is uniform. In vendored v3-core:

```bash
grep -n "modifier lock\|function mint(\|function collect(\|function burn(\|function swap(" \
  vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3Pool.sol
```

`mint`, `collect`, `burn` carry `lock`; `swap` self-locks inline
(`slot0.unlocked = false` … `= true`). Note which functions have *no* callback —
those are the ones that lull you, because "no callback" is read as "no reentrancy
surface" when it only means "no reentrancy surface *inside this call*".

### 2. Partition your function into locked spans and unlocked gaps

Write the sequence out and mark each external call of your own. The gaps with a
call in them are the candidate windows. Then name the invariant that is in flight
across each gap. If no invariant spans a gap, the gap is harmless.

### 3. Aim the re-entry at the gap, not at the first opportunity

A one-shot hook fires on the **first** matching call, which is almost always
inside the protocol's locked span — producing a `LOK`-style revert and a false
sense of safety. Make the re-entry target re-arm itself and count:

```solidity
function tick() external {
    calls++;
    if (calls == 1) {                    // this is the locked span — re-arm, do nothing
        weth.setReentryCall(address(this), abi.encodeCall(this.tick, ()));
        return;
    }
    try swapper.swap(zeroForOne, amountIn, limit) { swapSucceeded = true; }
    catch (bytes memory err) { swapError = err; }
}
```

Capture the inner result in storage (`swapSucceeded`, `swapError`) instead of
letting it bubble — otherwise a failed attempt and a successful one both surface
as "the outer call reverted" and you cannot tell them apart.

### 4. Prove it with a conservation differential, not with a revert

Run the identical operation twice: once with the interfering action OUTSIDE the
window, once INSIDE. The finding is credible only when the same quantity moves
between two buckets by the same amount:

| observable | outside | inside |
|---|---|---|
| classified as fee yield (burned) | 7,325,346,449,782,639,753 | **0** |
| booked as returned principal | 59,996,337,326,775,108,680,101 | **60,003,662,673,224,891,319,854** |

Equal and opposite, to the wei — so the value was reclassified, not lost, and no
second explanation is available. Keep a third column stable (here the other
token's leg, unchanged because the price at burn time is identical in both arms)
to show the differential isolates the reclassification.

### 5. Grade by whether a re-entrant counterparty actually exists

Read the source, not the reputation:

```bash
grep -nE "function _update|_beforeTokenTransfer|_afterTokenTransfer" src/Token.sol
```

A token that is `contract T is ERC20, ERC20Permit` with no `_update` override
makes no external call on transfer. If every counterparty in the window is
hook-free AND fixed at construction, the window is unreachable and the finding is
LOW with a named hardening — not a live vulnerability. If any counterparty is
upgradeable, say so and say who controls the upgrade; that is the severity.

### 6. Name the hardening in terms the accepted design already allows

Usually: keep the *reads* in the mandated order and move the *disposal* past all
protocol interaction.

```
(feesA, feesB) = pokeAndCollectFees();   // order the spec mandates, no disposal
pool.burn(liquidity); pool.collect(...); bookPrincipal();
classifyFees(feesA, feesB);              // every external call now after the last pool call
```

This satisfies a spec that constrains *collection* order without inheriting a
constraint on *disposal* order it never stated.

## Verification

Confirmed on cycle-002 sprint-5:

| step | result |
|---|---|
| re-entry from inside `pool.collect` | **reverts `LOK`** — the pool's lock; the false negative |
| re-entry from the post-`collect` gap | **`swapSucceeded=TRUE`, `swapErr=0x`** — the pool is unlocked there |
| fee leg classified as fee yield, swap outside window | 7,325,346,449,782,639,753 |
| fee leg classified as fee yield, swap inside window | **0** |
| difference appearing in booked principal | **+7,325,346,449,782,639,753** (exact) |
| subsequent harvest recovering the fees | 0 — they were swept, not deferred |
| counterparty hook audit | `VUX` has no `_update` override; canonical WETH9 has no hook ⇒ unreachable today ⇒ LOW |

The design document's own premise ("no swap can interleave") was recorded in the
project's decision log as an established architectural fact. The PoC is what
converted it from an assumption into a *conditional* one.

## Anti-Patterns

- **Reading a `LOK`-style revert as proof of safety.** It proves the protocol
  guards its own calls. It says nothing about the gaps between them. Re-aim.
- **Auditing only the callbacks.** They are where the design put its defences and
  therefore where they are strongest. Ask what is unguarded instead.
- **Trusting `nonReentrant` to cover the window.** It stops re-entry into *you*;
  it cannot stop a token calling the external protocol directly.
- **Letting the inner call's revert bubble.** Success and failure then look
  identical from outside. Catch and record it.
- **Grading on token reputation.** "WETH has no hooks" is true and is not an
  argument. Grep for the override; then state who can upgrade it.
- **Reporting the window without the differential.** A described window is a
  hypothesis; equal-and-opposite movement of a conserved quantity is a finding.

## Related Resources

- Uniswap v3-core `UniswapV3Pool.sol` — `modifier lock` (L104), applied to `mint`
  (L463), `collect` (L496), `burn` (L521); `swap` self-locks (L615/L787).
- Checks-Effects-Interactions — the general principle this is a multi-call
  instance of.

## Related Memory

- [[intra-call-ordering-needs-an-interleaved-observer]] — the sibling and natural
  predecessor: that one says an intra-call ordering needs an interleaved observer
  to be testable at all; this one says the external protocol's lock determines
  *where such an observer can exist*, and that the gaps between your calls are the
  only place it can.
- [[verify-the-mutant-not-the-verdict]] — same discipline applied to the PoC: prove
  the interference actually landed (`swapSucceeded`) before reading the outcome.
- [[post-run-properties-are-not-invariants]] — an invariant checked only between
  operations cannot see a violation that exists only mid-operation, which is
  precisely the window described here.
- [[escalate-against-the-accepted-invariant]] — the grading step: does the window
  breach the invariant the operator accepted, or only a sentence the design
  document overstated?

## Changelog

- 1.0.0 (2026-08-14) — extracted from cycle-002 / sprint-5 `/audit-sprint`.

## Metadata (Auto-Generated)

- Applications: 1
- Success rate: 1/1
- Last applied: 2026-08-14
