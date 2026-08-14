---
name: post-run-properties-are-not-invariants
description: |
  A stateful-invariant engine evaluates every `invariant_*` function against the
  post-setUp state as well as after each call sequence. Anything asserted there
  must be true of a system on which NOTHING has happened yet. This makes a
  natural and valuable check impossible to express as an invariant: "the harness
  actually did some work", whose whole point is that it is false at setup. The
  attempt fails with `failed to set up invariant testing environment`, which
  reads like a harness wiring bug and sends you looking in the wrong place.
  Apply when writing anti-vacuity or coverage checks for a Foundry invariant
  suite, or when an `invariant_*` fails at setup with zero runs and zero calls.
  Provides the distinction between state invariants and post-run properties, and
  the three places each kind actually belongs.
loa-agent: implementing-tasks
extracted-from: cycle-002 / sprint-3 (INV-1…22 monetary invariant harness)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - foundry
  - invariant-testing
  - test-integrity
  - vacuity
---

## Problem

A green invariant suite that exercised nothing is worse than a red one, because
it is mistaken for evidence. The obvious guard is a counter:

```solidity
function invariant_TheHarnessActuallyExercisedTheSystem() public view {
    assertGt(handler.effectiveCalls(), 0, "the handler performed at least one real operation");
}
```

It fails — and not in the way you expect:

```
[FAIL: failed to set up invariant testing environment:
       AssertionFailed("the handler performed at least one real operation: expected 0 > 0")]
       invariant_TheHarnessActuallyExercisedTheSystem() (runs: 0, calls: 0, reverts: 0)
```

Meanwhile the other nine invariants in the same file report
`runs: 32, calls: 1024, reverts: 0`. Only this one is broken, and the message
blames the environment.

## Trigger Conditions

### Symptoms

- One `invariant_*` reports `runs: 0, calls: 0` while its siblings run normally.
- The failure is prefixed `failed to set up invariant testing environment`.
- The assertion involves a counter, an accumulator, a "has happened" flag, or any
  quantity that starts at zero and only grows.

### When to apply

- Adding anti-vacuity / coverage checks to an invariant suite.
- Any invariant phrased as "at least one …", "eventually …", or "the suite
  reached …".

### When this does NOT apply

- Genuine state invariants — properties true of the initial state too
  (`totalSupply == genesis + minted − burned` holds at setup, where both terms
  are zero).
- Upper bounds and "at most" properties: `assertLe(handler.bootstraps(), 1)` is
  true at setup and stays true, so it is a legitimate invariant.

## Root Cause

The engine treats post-`setUp` state as the first state to check — correctly, so
that an invariant broken by construction fails immediately rather than being
masked by the first call sequence.

That makes the quantifier explicit: an invariant is a property of **every**
reachable state including the initial one. "Work has been done" is a property of
the **final** state of a run. The two are different logical shapes, and the
engine's evaluation model only expresses the first.

The confusing error text follows from *when* it fires: the assertion reverts
during the setup-time check, so the engine reports a setup failure. The harness
wiring is fine.

## Solution

### Recognize which shape you have

| Shape | Example | Where it belongs |
|---|---|---|
| True in every state, including initial | `S == genesis + minted − burned` | `invariant_*` |
| Upper bound that starts satisfied | `bootstrapSettlements <= 1` | `invariant_*` |
| Only true after work happens | `effectiveCalls > 0` | **not** an invariant |

### Prove non-vacuity by other means — three, together

**1. `fail_on_revert = true`.** The strongest and cheapest. A call that reverted
instead of doing work fails the run, so a green run means the calls landed.

```toml
[profile.ci.invariant]
runs = 256
depth = 64
fail_on_revert = true
```

This requires the handler to shape its own inputs so legitimate calls cannot
revert. That work is worth doing anyway: under `fail_on_revert = false` a handler
that reverts on most sequences still reports a green run.

**2. The engine's own report.** Foundry prints per-invariant `calls` and
`reverts`, plus a per-selector table:

```
| RigInvariantHandler | donateToReserve | 261   | 0       | 0        |
| RigInvariantHandler | passTime        | 270   | 0       | 0        |
| RigInvariantHandler | redeemSome      | 258   | 0       | 0        |
| RigInvariantHandler | takeThrone      | 235   | 0       | 0        |
```

Read it. An action stuck at 0 calls, or with reverts/discards, is the finding.

**3. A plain unit test that drives every action once.** This is the part the
counter was actually reaching for — it catches an action that silently
degenerated into a no-op, which `fail_on_revert` cannot see (an early `return` is
not a revert):

```solidity
function test_EveryHandlerActionDoesRealWork() public {
    handler.takeThrone(0, 1_000);
    assertEq(handler.settlements(), 1, "takeThrone settles");

    uint256 burnedBefore = handler.ghostBurnedByRedemption();
    handler.redeemSome(0, type(uint256).max);
    assertGt(handler.ghostBurnedByRedemption(), burnedBefore, "redeemSome actually burns");

    uint256 backingBefore = reserve.backing();
    handler.donateToReserve(1 ether);
    assertGt(reserve.backing(), backingBefore, "donateToReserve actually raises B");
}
```

Assert the **state each action claims to move**, not just a counter — a counter
increments whether or not the action did anything.

Note the guard-shaped actions this protects: handlers commonly `return` early
when preconditions are unmet (`if (balance == 0) return;`). That is correct
behaviour and invisible to every other check.

### Record the reasoning where the counter used to be

Leave a comment saying *why* this is not an invariant. Otherwise the next author
re-adds it and rediscovers the setup failure.

## Verification

1. **Confirm the shape** — ask whether the property is true of the post-`setUp`
   state. If no, it is not an invariant, regardless of how much you want it to be.
2. **Confirm siblings are healthy** — if other invariants report normal
   `runs`/`calls`, the harness is wired correctly and the problem is this
   assertion.
3. **Check the coverage table** — every handler action should show a comparable
   call count with 0 reverts and 0 discards.
4. **Prove the unit test discriminates** — make one action a no-op and confirm it
   fails.

Observed here: 9 invariants at 16,384 calls each, 0 reverts, 0 discards, calls
distributed evenly across all four actions.

## Anti-Patterns

- **Debugging harness wiring on the "failed to set up" message.** The message
  names the symptom's timing, not its cause.
- **Weakening to `assertGe(effectiveCalls, 0)` to make it pass.** Now trivially
  true in every state — a vacuous check about vacuity.
- **Relying on `fail_on_revert = false` plus a call count.** Reverted calls count
  as calls; the number stops meaning work.
- **Counting invocations instead of asserting state.** A no-op action still
  increments its counter.
- **Dropping the anti-vacuity concern because it cannot be an invariant.** It is
  a real risk; it just belongs in the three places above.

## Related Resources

- `test/rig/RigInvariants.t.sol` — the three-way non-vacuity argument and the
  comment explaining why it is not an `invariant_`.
- `test/rig/RigInvariantHandler.sol` — input shaping that makes
  `fail_on_revert = true` viable.
- `foundry.toml` — `[profile.ci.invariant]`.

## Related Memory

- [[fuzz-harness-validity-audit]] — the sibling failure in the fuzz medium:
  `runs: 10000` counts invocations, never explored states. Same "green because it
  is looking at nothing" family, different engine.

## Changelog

- 1.0.0 (2026-08-13) — extracted from cycle-002 / sprint-3.

## Metadata (Auto-Generated)

- Applications: 1
- Success rate: 1/1
- Last applied: 2026-08-13
